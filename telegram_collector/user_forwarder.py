from __future__ import annotations

import asyncio
import logging
import os
import sqlite3
import threading
from dataclasses import dataclass
from pathlib import Path
from typing import Any


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


@dataclass(frozen=True)
class UserForwarderConfig:
    api_id: int
    api_hash: str
    session: str
    source_chat_ids: frozenset[int]
    target_chat_id: int
    data_dir: Path
    forward_delay_seconds: float = 1.0

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
        source_chat_ids = _parse_chat_ids(
            required["USERBOT_SOURCE_CHAT_IDS"], "USERBOT_SOURCE_CHAT_IDS"
        )
        if target_chat_id in source_chat_ids:
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
        return cls(
            api_id=api_id,
            api_hash=required["USERBOT_API_HASH"],
            session=required["USERBOT_SESSION"],
            source_chat_ids=source_chat_ids,
            target_chat_id=target_chat_id,
            data_dir=data_dir,
            forward_delay_seconds=delay,
        )


class ForwardedMessageStore:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(path)
        self._connection.execute(
            """
            CREATE TABLE IF NOT EXISTS forwarded_messages (
                source_chat_id INTEGER NOT NULL,
                source_message_id INTEGER NOT NULL,
                forwarded_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (source_chat_id, source_message_id)
            )
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

    def close(self) -> None:
        self._connection.close()


class TelegramUserForwarder:
    """Runs a Telethon user client in a background thread.

    Only new incoming messages from an explicit source allowlist are forwarded.
    Telegram content-protection restrictions are respected and never bypassed.
    """

    def __init__(self, config: UserForwarderConfig) -> None:
        self._config = config
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
            from telethon import TelegramClient, events
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
        forward_lock = asyncio.Lock()
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
            await client.get_dialogs(limit=None)
            target = await client.get_input_entity(self._config.target_chat_id)

            @client.on(events.NewMessage(incoming=True))
            async def forward_new_message(event: Any) -> None:
                if event.chat_id is None:
                    return
                source_chat_id = int(event.chat_id)
                if source_chat_id not in self._config.source_chat_ids:
                    return
                source_message_id = int(event.message.id)
                if source_chat_id == self._config.target_chat_id:
                    return
                if store.contains(source_chat_id, source_message_id):
                    return
                if not str(event.raw_text or "").strip():
                    return
                async with forward_lock:
                    if store.contains(source_chat_id, source_message_id):
                        return
                    try:
                        await client.forward_messages(target, event.message)
                    except ChatForwardsRestrictedError:
                        LOGGER.warning(
                            "Skipped protected message chat=%s message=%s",
                            source_chat_id,
                            source_message_id,
                        )
                        return
                    except RPCError:
                        LOGGER.exception(
                            "Telegram rejected forward chat=%s message=%s",
                            source_chat_id,
                            source_message_id,
                        )
                        return
                    store.mark(source_chat_id, source_message_id)
                    LOGGER.info(
                        "Forwarded chat=%s message=%s to chat=%s",
                        source_chat_id,
                        source_message_id,
                        self._config.target_chat_id,
                    )
                    if self._config.forward_delay_seconds:
                        await asyncio.sleep(self._config.forward_delay_seconds)

            self._loop = asyncio.get_running_loop()
            self._stop_event = asyncio.Event()
            LOGGER.info(
                "User forwarder connected as user_id=%s; sources=%s target=%s",
                getattr(me, "id", "unknown"),
                sorted(self._config.source_chat_ids),
                self._config.target_chat_id,
            )
            self._ready.set()
            await self._stop_event.wait()
        finally:
            await client.disconnect()
            store.close()
