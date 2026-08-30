from __future__ import annotations

import asyncio
import logging
import os
import re
import sqlite3
import threading
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Sequence
from zoneinfo import ZoneInfo

from telegram_publisher import TelegramBatchMessage, TelegramLeadPipeline


LOGGER = logging.getLogger("hamsafar.telegram_user_forwarder")


def _parse_chat_ids(raw: str, variable_name: str) -> frozenset[int]:
    values = [item.strip() for item in raw.split(",") if item.strip()]
    if not values:
        raise RuntimeError(f"{variable_name} must contain at least one chat ID")
    try:
        return frozenset(int(value) for value in values)
    except ValueError as error:
        raise RuntimeError(
            f"{variable_name} must contain comma-separated integer chat IDs"
        ) from error


def _parse_source_chats(raw: str, variable_name: str) -> tuple[int | str, ...]:
    values = [item.strip() for item in raw.split(",") if item.strip()]
    if not values:
        raise RuntimeError(
            f"{variable_name} must contain at least one chat ID or public username"
        )
    parsed: list[int | str] = []
    seen: set[int | str] = set()
    for value in values:
        try:
            reference: int | str = int(value)
        except ValueError:
            username = re.sub(
                r"^(?:https?://)?t\.me/", "", value, flags=re.IGNORECASE
            ).strip("/@")
            if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]{3,31}", username):
                raise RuntimeError(
                    f"{variable_name} must contain comma-separated integer chat "
                    "IDs or public Telegram usernames"
                )
            reference = f"@{username.lower()}"
        if reference not in seen:
            seen.add(reference)
            parsed.append(reference)
    return tuple(parsed)


def _message_topic_id(message: Any) -> int | None:
    direct = getattr(message, "reply_to_top_id", None)
    if direct is not None:
        return int(direct)
    reply = getattr(message, "reply_to", None)
    top_id = getattr(reply, "reply_to_top_id", None)
    if top_id is not None:
        return int(top_id)
    if bool(getattr(reply, "forum_topic", False)):
        reply_to_msg_id = getattr(reply, "reply_to_msg_id", None)
        if reply_to_msg_id is not None:
            return int(reply_to_msg_id)
    return None


@dataclass(frozen=True)
class UserForwarderConfig:
    api_id: int
    api_hash: str
    session: str
    source_chats: tuple[int | str, ...]
    target_chat_id: int
    data_dir: Path
    forward_delay_seconds: float = 1.0
    batch_window_seconds: float = 120.0
    backfill_today: bool = False
    backfill_limit_per_chat: int = 100
    timezone_name: str = "Asia/Dushanbe"

    @classmethod
    def from_environment(cls, data_dir: Path) -> "UserForwarderConfig":
        required = {
            "USERBOT_API_ID": os.getenv("USERBOT_API_ID", "").strip(),
            "USERBOT_API_HASH": os.getenv("USERBOT_API_HASH", "").strip(),
            "USERBOT_SESSION": os.getenv("USERBOT_SESSION", "").strip(),
            "USERBOT_SOURCE_CHAT_IDS": os.getenv(
                "USERBOT_SOURCE_CHAT_IDS", ""
            ).strip(),
            "USERBOT_TARGET_CHAT_ID": os.getenv(
                "USERBOT_TARGET_CHAT_ID", ""
            ).strip(),
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            raise RuntimeError(
                "Missing user forwarder variables: " + ", ".join(sorted(missing))
            )
        try:
            api_id = int(required["USERBOT_API_ID"])
        except ValueError as error:
            raise RuntimeError("USERBOT_API_ID must be an integer") from error
        try:
            target_chat_id = int(required["USERBOT_TARGET_CHAT_ID"])
        except ValueError as error:
            raise RuntimeError("USERBOT_TARGET_CHAT_ID must be an integer") from error
        source_chats = _parse_source_chats(
            required["USERBOT_SOURCE_CHAT_IDS"], "USERBOT_SOURCE_CHAT_IDS"
        )
        if target_chat_id in source_chats:
            raise RuntimeError(
                "USERBOT_TARGET_CHAT_ID cannot also be a source chat; this prevents loops"
            )
        try:
            delay = float(os.getenv("USERBOT_FORWARD_DELAY_SECONDS", "1.0"))
        except ValueError as error:
            raise RuntimeError(
                "USERBOT_FORWARD_DELAY_SECONDS must be a number"
            ) from error
        if not 0 <= delay <= 60:
            raise RuntimeError(
                "USERBOT_FORWARD_DELAY_SECONDS must be between 0 and 60"
            )
        try:
            batch_window = float(
                os.getenv("USERBOT_BATCH_WINDOW_SECONDS", "120")
            )
        except ValueError as error:
            raise RuntimeError(
                "USERBOT_BATCH_WINDOW_SECONDS must be a number"
            ) from error
        if not 1 <= batch_window <= 900:
            raise RuntimeError(
                "USERBOT_BATCH_WINDOW_SECONDS must be between 1 and 900"
            )
        try:
            backfill_limit = int(
                os.getenv("USERBOT_BACKFILL_LIMIT_PER_CHAT", "100")
            )
        except ValueError as error:
            raise RuntimeError(
                "USERBOT_BACKFILL_LIMIT_PER_CHAT must be an integer"
            ) from error
        if not 1 <= backfill_limit <= 500:
            raise RuntimeError(
                "USERBOT_BACKFILL_LIMIT_PER_CHAT must be between 1 and 500"
            )
        return cls(
            api_id=api_id,
            api_hash=required["USERBOT_API_HASH"],
            session=required["USERBOT_SESSION"],
            source_chats=source_chats,
            target_chat_id=target_chat_id,
            data_dir=data_dir,
            forward_delay_seconds=delay,
            batch_window_seconds=batch_window,
            backfill_today=os.getenv("USERBOT_BACKFILL_TODAY", "false")
            .strip()
            .lower()
            in {"1", "true", "yes", "on"},
            backfill_limit_per_chat=backfill_limit,
            timezone_name=os.getenv("SOURCE_TIMEZONE", "Asia/Dushanbe"),
        )


class ForwardedMessageStore:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(path)
        self._connection.row_factory = sqlite3.Row
        self._connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS forwarded_messages (
                source_chat_id INTEGER NOT NULL,
                source_message_id INTEGER NOT NULL,
                forwarded_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (source_chat_id, source_message_id)
            );

            CREATE TABLE IF NOT EXISTS pending_source_messages (
                batch_key TEXT NOT NULL,
                source_chat_id INTEGER NOT NULL,
                source_chat_title TEXT,
                source_chat_username TEXT,
                source_message_id INTEGER NOT NULL,
                sender_id INTEGER,
                sender_name TEXT,
                sender_username TEXT,
                telegram_date TEXT NOT NULL,
                raw_text TEXT NOT NULL,
                forwarded INTEGER NOT NULL DEFAULT 0,
                queued_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (source_chat_id, source_message_id)
            );

            CREATE INDEX IF NOT EXISTS pending_source_messages_batch_idx
            ON pending_source_messages(batch_key, telegram_date, source_message_id);
            """
        )
        self._connection.commit()

    def contains(self, source_chat_id: int, source_message_id: int) -> bool:
        row = self._connection.execute(
            """
            SELECT 1 FROM forwarded_messages
            WHERE source_chat_id = ? AND source_message_id = ?
            """,
            (source_chat_id, source_message_id),
        ).fetchone()
        return row is not None

    def mark(self, source_chat_id: int, source_message_id: int) -> None:
        self._connection.execute(
            """
            INSERT OR IGNORE INTO forwarded_messages (
                source_chat_id, source_message_id
            ) VALUES (?, ?)
            """,
            (source_chat_id, source_message_id),
        )
        self._connection.commit()

    def enqueue(self, batch_key: str, message: TelegramBatchMessage) -> bool:
        if self.contains(message.source_chat_id, message.source_message_id):
            return False
        cursor = self._connection.execute(
            """
            INSERT OR IGNORE INTO pending_source_messages (
                batch_key, source_chat_id, source_chat_title,
                source_chat_username, source_message_id, sender_id,
                sender_name, sender_username, telegram_date, raw_text
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                batch_key,
                message.source_chat_id,
                message.source_chat_title,
                message.source_chat_username,
                message.source_message_id,
                message.sender_id,
                message.sender_name,
                message.sender_username,
                message.sent_at.astimezone(timezone.utc).isoformat(),
                message.text,
            ),
        )
        self._connection.commit()
        return cursor.rowcount > 0

    def load_batch(self, batch_key: str) -> list[TelegramBatchMessage]:
        rows = self._connection.execute(
            """
            SELECT * FROM pending_source_messages
            WHERE batch_key = ?
            ORDER BY telegram_date, source_message_id
            """,
            (batch_key,),
        ).fetchall()
        return [
            TelegramBatchMessage(
                source_chat_id=int(row["source_chat_id"]),
                source_chat_title=row["source_chat_title"],
                source_chat_username=row["source_chat_username"],
                source_message_id=int(row["source_message_id"]),
                sender_id=int(row["sender_id"])
                if row["sender_id"] is not None
                else None,
                sender_name=row["sender_name"],
                sender_username=row["sender_username"],
                sent_at=datetime.fromisoformat(str(row["telegram_date"])),
                text=str(row["raw_text"]),
            )
            for row in rows
        ]

    def batch_was_forwarded(self, batch_key: str) -> bool:
        row = self._connection.execute(
            """
            SELECT min(forwarded) AS forwarded
            FROM pending_source_messages WHERE batch_key = ?
            """,
            (batch_key,),
        ).fetchone()
        return bool(row and row["forwarded"])

    def mark_batch_forwarded(self, batch_key: str) -> None:
        self._connection.execute(
            "UPDATE pending_source_messages SET forwarded = 1 WHERE batch_key = ?",
            (batch_key,),
        )
        self._connection.commit()

    def complete_batch(self, batch_key: str, messages: Sequence[TelegramBatchMessage]) -> None:
        self._connection.executemany(
            """
            INSERT OR IGNORE INTO forwarded_messages (
                source_chat_id, source_message_id
            ) VALUES (?, ?)
            """,
            [
                (message.source_chat_id, message.source_message_id)
                for message in messages
            ],
        )
        self._connection.execute(
            "DELETE FROM pending_source_messages WHERE batch_key = ?",
            (batch_key,),
        )
        self._connection.commit()

    def pending_batch_keys(self) -> list[str]:
        rows = self._connection.execute(
            "SELECT DISTINCT batch_key FROM pending_source_messages"
        ).fetchall()
        return [str(row["batch_key"]) for row in rows]

    def close(self) -> None:
        self._connection.close()


def _entity_name(entity: Any) -> str | None:
    values = [
        str(getattr(entity, name, "") or "").strip()
        for name in ("first_name", "last_name")
    ]
    name = " ".join(value for value in values if value)
    if name:
        return name
    title = str(getattr(entity, "title", "") or "").strip()
    return title or None


class TelegramUserForwarder:
    """Runs a Telethon user client in a background thread.

    Only new incoming messages from an explicit source allowlist are forwarded.
    Telegram content-protection restrictions are respected and never bypassed.
    """

    def __init__(
        self,
        config: UserForwarderConfig,
        pipeline: TelegramLeadPipeline | None = None,
    ) -> None:
        self._config = config
        self._pipeline = pipeline
        self._thread: threading.Thread | None = None
        self._loop: asyncio.AbstractEventLoop | None = None
        self._stop_event: asyncio.Event | None = None
        self._ready = threading.Event()
        self._start_error: BaseException | None = None

    def start(self, timeout: float = 45.0) -> None:
        if self._thread is not None:
            return
        self._thread = threading.Thread(
            target=self._thread_entry,
            name="telegram-user-forwarder",
            daemon=True,
        )
        self._thread.start()
        if not self._ready.wait(timeout):
            raise RuntimeError("Telegram user forwarder startup timed out")
        if self._start_error is not None:
            raise RuntimeError(
                f"Telegram user forwarder failed to start: {self._start_error}"
            ) from self._start_error

    def stop(self) -> None:
        if self._loop is not None and self._stop_event is not None:
            self._loop.call_soon_threadsafe(self._stop_event.set)

    def join(self, timeout: float = 10.0) -> None:
        if self._thread is not None:
            self._thread.join(timeout)

    def _thread_entry(self) -> None:
        try:
            asyncio.run(self._run())
        except BaseException as error:
            if not self._ready.is_set():
                self._start_error = error
                self._ready.set()
            LOGGER.exception("Telegram user forwarder stopped unexpectedly")

    async def _run(self) -> None:
        try:
            from telethon import TelegramClient, events, utils
            from telethon.errors import ChatForwardsRestrictedError, RPCError
            from telethon.sessions import StringSession
        except ImportError as error:
            raise RuntimeError(
                "Telethon is not installed; install telegram_collector/requirements.txt"
            ) from error

        store = ForwardedMessageStore(
            self._config.data_dir / "telegram_user_forwarder.sqlite3"
        )
        client = TelegramClient(
            StringSession(self._config.session),
            self._config.api_id,
            self._config.api_hash,
            flood_sleep_threshold=30,
        )
        flush_lock = asyncio.Lock()
        batch_tasks: dict[str, asyncio.Task[None]] = {}
        active_live_batches: dict[tuple[int, int | str, object], str] = {}
        try:
            await client.connect()
            if not await client.is_user_authorized():
                raise RuntimeError(
                    "USERBOT_SESSION is not authorized or was revoked"
                )
            me = await client.get_me()
            # StringSession stores authorization, not a persistent entity cache.
            # Loading dialogs once makes the numeric target ID resolvable after
            # every fresh container deployment.
            dialogs = await client.get_dialogs(limit=None)
            dialog_chat_ids = {
                int(utils.get_peer_id(dialog.entity)) for dialog in dialogs
            }
            target = await client.get_input_entity(self._config.target_chat_id)
            source_entities: dict[int, Any] = {}
            for source_reference in self._config.source_chats:
                source = await client.get_entity(source_reference)
                source_chat_id = int(utils.get_peer_id(source))
                if source_chat_id == self._config.target_chat_id:
                    raise RuntimeError(
                        "USERBOT_TARGET_CHAT_ID cannot also be a source chat; "
                        "this prevents loops"
                    )
                if source_chat_id not in dialog_chat_ids:
                    raise RuntimeError(
                        "The Telegram userbot account must join source chat "
                        f"{source_reference} before it can receive live messages"
                    )
                source_entities[source_chat_id] = source
            source_chat_ids = frozenset(source_entities)

            async def schedule_batch(batch_key: str, delay: float) -> None:
                existing = batch_tasks.get(batch_key)
                if existing is not None and not existing.done():
                    existing.cancel()

                async def wait_then_flush() -> None:
                    try:
                        if delay > 0:
                            await asyncio.sleep(delay)
                        await flush_batch(batch_key)
                    except asyncio.CancelledError:
                        return
                    finally:
                        current = asyncio.current_task()
                        if batch_tasks.get(batch_key) is current:
                            batch_tasks.pop(batch_key, None)

                batch_tasks[batch_key] = asyncio.create_task(wait_then_flush())

            async def flush_batch(batch_key: str) -> None:
                for live_key, active_batch_key in list(active_live_batches.items()):
                    if active_batch_key == batch_key:
                        active_live_batches.pop(live_key, None)
                async with flush_lock:
                    messages = store.load_batch(batch_key)
                    if not messages:
                        return
                    prepared = None
                    if self._pipeline is not None:
                        try:
                            prepared = await asyncio.to_thread(
                                self._pipeline.prepare,
                                messages,
                            )
                        except Exception:
                            LOGGER.exception(
                                "Telegram lead preparation failed batch=%s; "
                                "retrying later",
                                batch_key,
                            )
                            batch_tasks.pop(batch_key, None)
                            await schedule_batch(batch_key, 60)
                            return
                        if prepared is None:
                            store.complete_batch(batch_key, messages)
                            LOGGER.info(
                                "Skipped non-ride batch=%s messages=%s",
                                batch_key,
                                len(messages),
                            )
                            return

                    if not store.batch_was_forwarded(batch_key):
                        try:
                            source = await client.get_input_entity(
                                messages[0].source_chat_id
                            )
                            source_messages = await client.get_messages(
                                source,
                                ids=[message.source_message_id for message in messages],
                            )
                            originals = [message for message in source_messages if message]
                            if not originals:
                                store.complete_batch(batch_key, messages)
                                return
                            await client.forward_messages(target, originals)
                        except ChatForwardsRestrictedError:
                            LOGGER.warning("Skipped protected batch=%s", batch_key)
                            store.complete_batch(batch_key, messages)
                            return
                        except RPCError:
                            LOGGER.exception(
                                "Telegram rejected batch=%s; retrying later",
                                batch_key,
                            )
                            batch_tasks.pop(batch_key, None)
                            await schedule_batch(batch_key, 60)
                            return
                        store.mark_batch_forwarded(batch_key)

                    if self._pipeline is not None and prepared is not None:
                        try:
                            await asyncio.to_thread(self._pipeline.publish, prepared)
                        except Exception:
                            LOGGER.exception(
                                "Telegram lead publish failed batch=%s; retrying later",
                                batch_key,
                            )
                            batch_tasks.pop(batch_key, None)
                            await schedule_batch(batch_key, 60)
                            return
                    store.complete_batch(batch_key, messages)
                    LOGGER.info(
                        "Published Telegram ride batch=%s messages=%s target=%s",
                        batch_key,
                        len(messages),
                        self._config.target_chat_id,
                    )
                    if self._config.forward_delay_seconds:
                        await asyncio.sleep(self._config.forward_delay_seconds)

            async def queue_message(
                message: Any,
                *,
                chat: Any,
                batch_key: str | None = None,
                schedule_delay: float | None = None,
            ) -> str | None:
                source_chat_id = int(getattr(message, "chat_id", 0) or 0)
                if source_chat_id not in source_chat_ids:
                    return None
                if bool(getattr(chat, "noforwards", False)):
                    LOGGER.warning(
                        "Skipped protected source chat=%s",
                        source_chat_id,
                    )
                    return None
                source_message_id = int(message.id)
                if store.contains(source_chat_id, source_message_id):
                    return None
                text = str(getattr(message, "raw_text", "") or "").strip()
                if not text:
                    return None
                sender = await message.get_sender()
                sender_id_raw = getattr(message, "sender_id", None)
                sender_id = int(sender_id_raw) if sender_id_raw is not None else None
                sender_key = sender_id if sender_id is not None else "anonymous"
                topic_key = _message_topic_id(message) or "general"
                if batch_key is None:
                    live_key = (source_chat_id, topic_key, sender_key)
                    effective_batch_key = active_live_batches.get(live_key)
                    if effective_batch_key is None:
                        effective_batch_key = (
                            f"live:{source_chat_id}:{topic_key}:{sender_key}:"
                            f"{source_message_id}"
                        )
                        active_live_batches[live_key] = effective_batch_key
                else:
                    effective_batch_key = batch_key
                sent_at = getattr(message, "date", None) or datetime.now(timezone.utc)
                if sent_at.tzinfo is None:
                    sent_at = sent_at.replace(tzinfo=timezone.utc)
                queued = store.enqueue(
                    effective_batch_key,
                    TelegramBatchMessage(
                        source_chat_id=source_chat_id,
                        source_chat_title=_entity_name(chat),
                        source_chat_username=str(
                            getattr(chat, "username", "") or ""
                        ).strip()
                        or None,
                        source_message_id=source_message_id,
                        sender_id=sender_id,
                        sender_name=_entity_name(sender),
                        sender_username=str(
                            getattr(sender, "username", "") or ""
                        ).strip()
                        or None,
                        sent_at=sent_at,
                        text=text,
                    ),
                )
                if queued:
                    await schedule_batch(
                        effective_batch_key,
                        self._config.batch_window_seconds
                        if schedule_delay is None
                        else schedule_delay,
                    )
                return effective_batch_key

            @client.on(events.NewMessage(incoming=True))
            async def forward_new_message(event: Any) -> None:
                if event.chat_id is None:
                    return
                source_chat_id = int(event.chat_id)
                if source_chat_id not in source_chat_ids:
                    return
                if source_chat_id == self._config.target_chat_id:
                    return
                chat = await event.get_chat()
                await queue_message(event.message, chat=chat)

            async def backfill_today() -> None:
                local_tz = ZoneInfo(self._config.timezone_name)
                local_now = datetime.now(local_tz)
                midnight_utc = local_now.replace(
                    hour=0,
                    minute=0,
                    second=0,
                    microsecond=0,
                ).astimezone(timezone.utc)
                queued_batches: list[str] = []
                for source_chat_id in sorted(source_chat_ids):
                    try:
                        source = source_entities[source_chat_id]
                        history: list[Any] = []
                        async for message in client.iter_messages(
                            source,
                            limit=self._config.backfill_limit_per_chat,
                        ):
                            sent_at = getattr(message, "date", None)
                            if sent_at is None:
                                continue
                            if sent_at.tzinfo is None:
                                sent_at = sent_at.replace(tzinfo=timezone.utc)
                            if sent_at < midnight_utc:
                                break
                            if getattr(message, "out", False):
                                continue
                            if str(getattr(message, "raw_text", "") or "").strip():
                                history.append(message)
                        history.reverse()
                        active_bursts: dict[
                            tuple[int | str, object], tuple[datetime, str]
                        ] = {}
                        for message in history:
                            sender_raw = getattr(message, "sender_id", None)
                            sender_key: object = (
                                int(sender_raw)
                                if sender_raw is not None
                                else "anonymous"
                            )
                            sent_at = message.date
                            topic_key = _message_topic_id(message) or "general"
                            burst_source_key = (topic_key, sender_key)
                            previous = active_bursts.get(burst_source_key)
                            if (
                                previous is None
                                or sent_at - previous[0]
                                > timedelta(seconds=self._config.batch_window_seconds)
                            ):
                                burst_key = (
                                    f"backfill:{source_chat_id}:{topic_key}:"
                                    f"{sender_key}:{message.id}"
                                )
                            else:
                                burst_key = previous[1]
                            active_bursts[burst_source_key] = (sent_at, burst_key)
                            queued = await queue_message(
                                message,
                                chat=source,
                                batch_key=burst_key,
                                schedule_delay=3600,
                            )
                            if queued and queued not in queued_batches:
                                queued_batches.append(queued)
                    except Exception:
                        LOGGER.exception(
                            "Today's backfill failed for source chat=%s",
                            source_chat_id,
                        )
                for batch_key in queued_batches:
                    await schedule_batch(batch_key, 0)
                LOGGER.info(
                    "Today's Telegram backfill queued batches=%s",
                    len(queued_batches),
                )

            self._loop = asyncio.get_running_loop()
            self._stop_event = asyncio.Event()
            LOGGER.info(
                "User forwarder connected as user_id=%s; sources=%s target=%s",
                getattr(me, "id", "unknown"),
                sorted(source_chat_ids),
                self._config.target_chat_id,
            )
            self._ready.set()
            for batch_key in store.pending_batch_keys():
                await schedule_batch(batch_key, 0)
            if self._config.backfill_today:
                asyncio.create_task(backfill_today())
            await self._stop_event.wait()
        finally:
            for task in batch_tasks.values():
                task.cancel()
            if batch_tasks:
                await asyncio.gather(*batch_tasks.values(), return_exceptions=True)
            await client.disconnect()
            store.close()
