from __future__ import annotations

import logging
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from telegram_publisher import TelegramBatchMessage, TelegramLeadPipeline
from user_forwarder import ForwardedMessageStore


LOGGER = logging.getLogger("hamsafar.telegram_manual_forwarder")


def _display_name(entity: dict[str, Any]) -> str | None:
    name = " ".join(
        str(entity.get(key) or "").strip()
        for key in ("first_name", "last_name")
        if str(entity.get(key) or "").strip()
    )
    return name or str(entity.get("title") or "").strip() or None


def _utc_datetime(value: object, fallback: object) -> datetime:
    raw = value if isinstance(value, (int, float)) else fallback
    if isinstance(raw, (int, float)):
        return datetime.fromtimestamp(int(raw), tz=timezone.utc)
    return datetime.now(tz=timezone.utc)


@dataclass(frozen=True)
class ManualForwardEnvelope:
    group_key: tuple[int, object]
    message: TelegramBatchMessage
    target_chat_id: int
    target_message_id: int


def manual_forward_from_bot_message(
    message: dict[str, Any],
    text: str,
) -> ManualForwardEnvelope | None:
    """Convert Telegram Bot API forward metadata into a publishable message."""
    origin = message.get("forward_origin")
    has_legacy_origin = any(
        key in message
        for key in (
            "forward_from",
            "forward_sender_name",
            "forward_from_chat",
            "forward_date",
        )
    )
    if not isinstance(origin, dict) and not has_legacy_origin:
        return None

    chat = message.get("chat") or {}
    if "id" not in chat or "message_id" not in message:
        return None
    target_chat_id = int(chat["id"])
    target_message_id = int(message["message_id"])

    source_chat_id = target_chat_id
    source_chat_title = str(chat.get("title") or "Ручная пересылка").strip()
    source_chat_username = str(chat.get("username") or "").strip() or None
    source_message_id = target_message_id
    author_id: int | None = None
    author_name: str | None = None
    author_username: str | None = None
    original_date: object = message.get("forward_date")

    if isinstance(origin, dict):
        origin_type = str(origin.get("type") or "")
        original_date = origin.get("date", original_date)
        if origin_type == "user":
            user = origin.get("sender_user") or {}
            if user.get("id") is not None:
                author_id = int(user["id"])
            author_name = _display_name(user)
            author_username = str(user.get("username") or "").strip() or None
        elif origin_type == "hidden_user":
            author_name = str(origin.get("sender_user_name") or "").strip() or None
        elif origin_type in {"chat", "channel"}:
            origin_chat = origin.get("sender_chat") or origin.get("chat") or {}
            if origin_chat.get("id") is not None:
                author_id = int(origin_chat["id"])
            author_name = (
                str(origin.get("author_signature") or "").strip()
                or _display_name(origin_chat)
            )
            author_username = (
                str(origin_chat.get("username") or "").strip() or None
            )
            if (
                origin_type == "channel"
                and origin_chat.get("id") is not None
                and origin.get("message_id") is not None
            ):
                source_chat_id = int(origin_chat["id"])
                source_chat_title = _display_name(origin_chat) or source_chat_title
                source_chat_username = author_username
                source_message_id = int(origin["message_id"])
    else:
        user = message.get("forward_from") or {}
        origin_chat = message.get("forward_from_chat") or {}
        if user.get("id") is not None:
            author_id = int(user["id"])
        author_name = (
            _display_name(user)
            or str(message.get("forward_sender_name") or "").strip()
            or None
        )
        author_username = str(user.get("username") or "").strip() or None
        if origin_chat.get("id") is not None and message.get(
            "forward_from_message_id"
        ) is not None:
            source_chat_id = int(origin_chat["id"])
            source_chat_title = _display_name(origin_chat) or source_chat_title
            source_chat_username = (
                str(origin_chat.get("username") or "").strip() or None
            )
            source_message_id = int(message["forward_from_message_id"])

    sender_key: object = (
        author_id
        if author_id is not None
        else (author_name or "anonymous").casefold()
    )
    sent_at = _utc_datetime(original_date, message.get("date"))
    return ManualForwardEnvelope(
        group_key=(source_chat_id, sender_key),
        message=TelegramBatchMessage(
            source_chat_id=source_chat_id,
            source_chat_title=source_chat_title or None,
            source_chat_username=source_chat_username,
            source_message_id=source_message_id,
            sender_id=author_id,
            sender_name=author_name,
            sender_username=author_username,
            sent_at=sent_at,
            text=text,
        ),
        target_chat_id=target_chat_id,
        target_message_id=target_message_id,
    )


class ManualForwardBatcher:
    def __init__(
        self,
        *,
        data_dir: Path,
        pipeline: TelegramLeadPipeline,
        batch_window_seconds: float = 120.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._pipeline = pipeline
        self._batch_window_seconds = batch_window_seconds
        self._clock = clock
        self._store = ForwardedMessageStore(
            data_dir / "telegram_manual_forwarder.sqlite3"
        )
        self._due: dict[str, float] = {
            batch_key: self._clock()
            for batch_key in self._store.pending_batch_keys()
        }
        self._active: dict[
            tuple[int, object], tuple[str, datetime]
        ] = {}

    def enqueue(self, message: dict[str, Any], text: str) -> bool:
        envelope = manual_forward_from_bot_message(message, text)
        if envelope is None:
            return False
        self.flush_due()
        active = self._active.get(envelope.group_key)
        if active is not None and abs(
            (envelope.message.sent_at - active[1]).total_seconds()
        ) <= self._batch_window_seconds:
            batch_key = active[0]
        else:
            author_key = envelope.group_key[1]
            batch_key = (
                f"manual:{envelope.message.source_chat_id}:"
                f"{author_key}:{envelope.message.source_message_id}"
            )
        queued = self._store.enqueue(batch_key, envelope.message)
        if not queued:
            return False
        self._active[envelope.group_key] = (
            batch_key,
            envelope.message.sent_at,
        )
        self._due[batch_key] = self._clock() + self._batch_window_seconds
        LOGGER.info(
            "Queued manual Telegram forward batch=%s target_message=%s",
            batch_key,
            envelope.target_message_id,
        )
        return True

    def flush_due(self) -> None:
        now = self._clock()
        for batch_key, due_at in list(self._due.items()):
            if due_at <= now:
                self._flush_batch(batch_key)

    def _flush_batch(self, batch_key: str) -> None:
        messages = self._store.load_batch(batch_key)
        if not messages:
            self._forget_batch(batch_key)
            return
        try:
            prepared = self._pipeline.prepare(messages)
            if prepared is None:
                self._store.complete_batch(batch_key, messages)
                self._forget_batch(batch_key)
                LOGGER.info(
                    "Skipped manual non-ride batch=%s messages=%s",
                    batch_key,
                    len(messages),
                )
                return
            # Automatic source forwarding normally publishes first. Ignoring a
            # conflict keeps its richer source-chat metadata when both paths
            # observe the same original listing.
            self._pipeline.publish(prepared, merge_duplicates=False)
        except Exception:
            LOGGER.exception(
                "Manual Telegram lead failed batch=%s; retrying later",
                batch_key,
            )
            self._due[batch_key] = self._clock() + 60
            return
        self._store.complete_batch(batch_key, messages)
        self._forget_batch(batch_key)
        LOGGER.info(
            "Published manual Telegram ride batch=%s messages=%s",
            batch_key,
            len(messages),
        )

    def _forget_batch(self, batch_key: str) -> None:
        self._due.pop(batch_key, None)
        for group_key, active in list(self._active.items()):
            if active[0] == batch_key:
                self._active.pop(group_key, None)

    def close(self) -> None:
        self._store.close()
