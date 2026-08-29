from __future__ import annotations

import hashlib
import json
import logging
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
from typing import Any, Callable, Sequence
from zoneinfo import ZoneInfo

from classifier import ParsedMessage, classify_message
from openrouter_parser import OpenRouterRideParser


LOGGER = logging.getLogger("hamsafar.telegram_publisher")


def _bool_env(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class TelegramBatchMessage:
    source_chat_id: int
    source_chat_title: str | None
    source_chat_username: str | None
    source_message_id: int
    sender_id: int | None
    sender_name: str | None
    sender_username: str | None
    sent_at: datetime
    text: str


@dataclass(frozen=True)
class PreparedTelegramLead:
    payload: dict[str, Any]
    parsed: ParsedMessage


def telegram_message_url(message: TelegramBatchMessage) -> str | None:
    username = (message.source_chat_username or "").strip().lstrip("@")
    if username:
        return f"https://t.me/{username}/{message.source_message_id}"
    raw = str(abs(message.source_chat_id))
    if raw.startswith("100") and len(raw) > 3:
        return f"https://t.me/c/{raw[3:]}/{message.source_message_id}"
    return None


class SupabaseTelegramLeadWriter:
    def __init__(
        self,
        *,
        url: str,
        service_role_key: str,
        timeout_seconds: int = 30,
        opener: Callable[..., Any] = urllib.request.urlopen,
    ) -> None:
        self._url = url.rstrip("/")
        self._service_role_key = service_role_key.strip()
        self._timeout_seconds = timeout_seconds
        self._opener = opener

    def upsert(
        self,
        payload: dict[str, Any],
        *,
        merge_duplicates: bool = True,
    ) -> None:
        request = urllib.request.Request(
            self._url
            + "/rest/v1/telegram_ride_leads?on_conflict=source_batch_key",
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={
                "apikey": self._service_role_key,
                "Authorization": f"Bearer {self._service_role_key}",
                "Content-Type": "application/json",
                "Prefer": (
                    "resolution=merge-duplicates,return=minimal"
                    if merge_duplicates
                    else "resolution=ignore-duplicates,return=minimal"
                ),
            },
            method="POST",
        )
        try:
            with self._opener(request, timeout=self._timeout_seconds):
                return
        except urllib.error.HTTPError as error:
            reason = error.read(2048).decode("utf-8", errors="replace")
            error.close()
            raise RuntimeError(
                f"Supabase telegram lead upsert failed: HTTP {error.code}: {reason[:500]}"
            ) from error


class TelegramLeadPipeline:
    def __init__(
        self,
        *,
        writer: SupabaseTelegramLeadWriter,
        timezone_name: str,
        ai: OpenRouterRideParser | None,
        minimum_confidence: float = 0.55,
    ) -> None:
        self._writer = writer
        self._timezone = ZoneInfo(timezone_name)
        self._ai = ai
        self._minimum_confidence = minimum_confidence

    @classmethod
    def from_environment(
        cls,
        *,
        timezone_name: str,
        openrouter_api_key: str | None,
        openrouter_models: Sequence[str],
    ) -> "TelegramLeadPipeline | None":
        if not _bool_env("TELEGRAM_PUBLISH_ENABLED", False):
            return None
        supabase_url = os.getenv("SUPABASE_URL", "").strip()
        service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        missing = []
        if not supabase_url:
            missing.append("SUPABASE_URL")
        if not service_role_key:
            missing.append("SUPABASE_SERVICE_ROLE_KEY")
        if missing:
            raise RuntimeError(
                "Missing Telegram publishing variables: " + ", ".join(missing)
            )
        try:
            minimum_confidence = float(
                os.getenv("TELEGRAM_MIN_CONFIDENCE", "0.55")
            )
        except ValueError as error:
            raise RuntimeError("TELEGRAM_MIN_CONFIDENCE must be a number") from error
        if not 0 <= minimum_confidence <= 1:
            raise RuntimeError("TELEGRAM_MIN_CONFIDENCE must be between 0 and 1")
        ai = (
            OpenRouterRideParser(
                api_key=openrouter_api_key,
                models=openrouter_models,
            )
            if openrouter_api_key
            else None
        )
        return cls(
            writer=SupabaseTelegramLeadWriter(
                url=supabase_url,
                service_role_key=service_role_key,
            ),
            timezone_name=timezone_name,
            ai=ai,
            minimum_confidence=minimum_confidence,
        )

    def prepare(self, messages: Sequence[TelegramBatchMessage]) -> PreparedTelegramLead | None:
        if not messages:
            return None
        ordered = sorted(messages, key=lambda item: (item.sent_at, item.source_message_id))
        combined_text = "\n".join(message.text.strip() for message in ordered if message.text.strip())
        if not combined_text:
            return None
        local_time = ordered[-1].sent_at.astimezone(self._timezone)
        local = classify_message(combined_text, local_time)
        parsed = local
        # Skip obvious chatter before spending free-model quota. Multi-message
        # routes still reach the LLM because combining them gives the local
        # classifier a route or ride cue.
        should_ask_ai = not (
            local.kind == "not_a_ride" and local.confidence >= 0.90
        )
        if self._ai is not None and should_ask_ai:
            try:
                parsed = self._ai.classify(combined_text, local_time, local)
            except Exception as error:
                LOGGER.warning("Telegram lead AI parsing failed; using local result: %s", error)
        if (
            parsed.kind == "not_a_ride"
            or not parsed.from_city
            or not parsed.to_city
            or parsed.confidence < self._minimum_confidence
        ):
            return None

        first = ordered[0]
        last = ordered[-1]
        # A content fingerprint deduplicates the same original listing when it
        # reaches us through both the automatic user forwarder and a manual
        # forward into the collector group. Bot API forwards from users do not
        # expose the original chat/message ID, but preserve author and date.
        fingerprint_input = {
            "author": first.sender_id
            if first.sender_id is not None
            else (first.sender_name or "anonymous").casefold(),
            "messages": [
                {
                    "sent_at": message.sent_at.astimezone(timezone.utc).isoformat(),
                    "text": " ".join(message.text.split()).casefold(),
                }
                for message in ordered
            ],
        }
        digest = hashlib.sha256(
            json.dumps(
                fingerprint_input,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        batch_key = f"v2:{digest}"
        original_url = telegram_message_url(first)
        expires_at = self._expires_at(parsed, last.sent_at)
        payload: dict[str, Any] = {
            "source_batch_key": batch_key,
            "source_chat_id": first.source_chat_id,
            "source_chat_title": first.source_chat_title,
            "source_chat_username": first.source_chat_username,
            "source_message_ids": [message.source_message_id for message in ordered],
            "source_message_url": original_url,
            "author_id": first.sender_id,
            "author_name": first.sender_name,
            "author_username": first.sender_username,
            "kind": parsed.kind,
            "from_city": parsed.from_city,
            "to_city": parsed.to_city,
            "departure_date": parsed.depart_date,
            "departure_time": parsed.depart_time,
            "date_precision": parsed.date_precision,
            "seats": parsed.seats,
            "cargo": parsed.cargo,
            "price": parsed.price,
            "currency": parsed.currency,
            "phone": parsed.phone,
            "contact_methods": list(parsed.contact_methods),
            "raw_text": combined_text[:12000],
            "source_sent_at": last.sent_at.astimezone(timezone.utc).isoformat(),
            "confidence": parsed.confidence,
            "expires_at": expires_at.astimezone(timezone.utc).isoformat(),
            "status": "active",
        }
        return PreparedTelegramLead(payload=payload, parsed=parsed)

    def publish(
        self,
        prepared: PreparedTelegramLead,
        *,
        merge_duplicates: bool = True,
    ) -> None:
        self._writer.upsert(
            prepared.payload,
            merge_duplicates=merge_duplicates,
        )

    def _expires_at(self, parsed: ParsedMessage, source_sent_at: datetime) -> datetime:
        if parsed.depart_date:
            try:
                date_value = datetime.fromisoformat(parsed.depart_date).date()
                time_value = (
                    time.fromisoformat(parsed.depart_time)
                    if parsed.depart_time
                    else time(23, 59)
                )
                departure = datetime.combine(date_value, time_value, self._timezone)
                return max(departure + timedelta(hours=8), source_sent_at + timedelta(hours=12))
            except ValueError:
                pass
        return source_sent_at + timedelta(days=2)
