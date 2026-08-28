from __future__ import annotations

import json
import logging
import os
import signal
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

from classifier import ParsedMessage, classify_message
from gemini_parser import GeminiRideParser
from storage import MessageStorage


LOGGER = logging.getLogger("hamsafar.telegram_collector")


def _bool_env(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _int_set_env(name: str) -> frozenset[int]:
    raw = os.getenv(name, "").strip()
    if not raw:
        return frozenset()
    try:
        return frozenset(int(item.strip()) for item in raw.split(",") if item.strip())
    except ValueError as error:
        raise RuntimeError(f"{name} must contain comma-separated integer IDs") from error


@dataclass(frozen=True)
class Config:
    token: str
    data_dir: Path
    allowed_chat_ids: frozenset[int]
    admin_user_ids: frozenset[int]
    test_reply_mode: bool
    timezone_name: str
    gemini_api_key: str | None
    gemini_model: str
    llm_mode: str

    @classmethod
    def from_environment(cls) -> "Config":
        token = (
            os.getenv("BOT_TOKEN")
            or os.getenv("TELEGRAM_BOT_TOKEN")
            or os.getenv("API_TOKEN")
        )
        if not token:
            raise RuntimeError(
                "BOT_TOKEN is missing. Add it as a hidden environment variable."
            )
        local_data = Path(__file__).resolve().parent / "data"
        default_data = Path("/app/data") if Path("/app/data").is_dir() else local_data
        gemini_api_key = os.getenv("GEMINI_API_KEY", "").strip() or None
        llm_mode = os.getenv(
            "LLM_MODE", "always" if gemini_api_key else "off"
        ).strip().lower()
        if llm_mode not in {"off", "always", "fallback"}:
            raise RuntimeError("LLM_MODE must be off, always, or fallback")
        if llm_mode != "off" and not gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY is required when LLM_MODE is enabled")
        return cls(
            token=token,
            data_dir=Path(os.getenv("DATA_DIR", str(default_data))),
            allowed_chat_ids=_int_set_env("ALLOWED_CHAT_IDS"),
            admin_user_ids=_int_set_env("ADMIN_USER_IDS"),
            test_reply_mode=_bool_env("TEST_REPLY_MODE", True),
            timezone_name=os.getenv("SOURCE_TIMEZONE", "Asia/Dushanbe"),
            gemini_api_key=gemini_api_key,
            gemini_model=os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite"),
            llm_mode=llm_mode,
        )


class TelegramAPI:
    def __init__(self, token: str) -> None:
        self._base_url = f"https://api.telegram.org/bot{token}/"

    def call(self, method: str, payload: dict[str, Any]) -> Any:
        request = urllib.request.Request(
            self._base_url + method,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                body = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            body_text = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Telegram API {method} failed: HTTP {error.code}: {body_text}") from error
        if not body.get("ok"):
            raise RuntimeError(
                f"Telegram API {method} failed: {body.get('description', 'unknown error')}"
            )
        return body.get("result")

    def get_updates(self, offset: int | None) -> list[dict[str, Any]]:
        payload: dict[str, Any] = {
            "timeout": 30,
            "allowed_updates": [
                "message",
                "edited_message",
                "channel_post",
                "edited_channel_post",
            ],
        }
        if offset is not None:
            payload["offset"] = offset
        result = self.call("getUpdates", payload)
        return list(result or [])

    def send_message(self, chat_id: int, text: str, reply_to: int | None = None) -> None:
        payload: dict[str, Any] = {"chat_id": chat_id, "text": text}
        if reply_to is not None:
            payload["reply_parameters"] = {
                "message_id": reply_to,
                "allow_sending_without_reply": True,
            }
        self.call("sendMessage", payload)


def _format_result(parsed: ParsedMessage, parser_name: str) -> str:
    heading = "🤖 ИИ-разбор Gemini" if parser_name == "gemini" else "🧪 Локальный разбор"
    if parsed.kind == "not_a_ride":
        return (
            f"{heading}: не похоже на объявление о поездке.\n"
            f"Уверенность: {round(parsed.confidence * 100)}%\n"
            "Пока ничего не публикуется в HamSafar."
        )
    labels = {"offer": "водитель предлагает поездку", "request": "ищут поездку"}
    route = f"{parsed.from_city or 'неизвестно'} → {parsed.to_city or 'неизвестно'}"
    details = [
        heading,
        f"Тип: {labels[parsed.kind]}",
        f"Маршрут: {route}",
        f"Дата: {parsed.depart_date or 'не указана'}",
        f"Время: {parsed.depart_time or 'не указано'}",
        f"Места: {parsed.seats if parsed.seats is not None else 'не указаны'}",
        f"Посылка/груз: {'да' if parsed.cargo else 'нет'}",
        f"Телефон: {parsed.phone or 'не найден'}",
        f"Уверенность: {round(parsed.confidence * 100)}%",
        "Пока ничего не публикуется в HamSafar.",
    ]
    return "\n".join(details)


class Collector:
    def __init__(self, config: Config) -> None:
        self._config = config
        self._api = TelegramAPI(config.token)
        self._storage = MessageStorage(config.data_dir / "telegram_collector.sqlite3")
        self._timezone = ZoneInfo(config.timezone_name)
        self._gemini = (
            GeminiRideParser(
                api_key=config.gemini_api_key,
                model=config.gemini_model,
            )
            if config.gemini_api_key and config.llm_mode != "off"
            else None
        )
        self._running = True

    def stop(self, *_: object) -> None:
        self._running = False

    def _chat_is_allowed(self, chat_id: int) -> bool:
        allowed = self._config.allowed_chat_ids
        return not allowed or chat_id in allowed

    def _user_is_admin(self, user_id: int | None) -> bool:
        admins = self._config.admin_user_ids
        return not admins or (user_id is not None and user_id in admins)

    def _handle_command(self, message: dict[str, Any], text: str) -> bool:
        command = text.split(maxsplit=1)[0].split("@", maxsplit=1)[0].lower()
        if command not in {"/start", "/help", "/chatid", "/status"}:
            return False
        chat = message.get("chat") or {}
        chat_id = int(chat["id"])
        sender_id = (message.get("from") or {}).get("id")
        if command in {"/status", "/chatid"} and not self._user_is_admin(sender_id):
            return True
        if command == "/chatid":
            reply = f"Chat ID: {chat_id}\nДобавь его в ALLOWED_CHAT_IDS после теста."
        elif command == "/status":
            stats = self._storage.stats(chat_id)
            reply = (
                "HamSafar Collector работает.\n"
                f"Chat ID: {chat_id}\n"
                f"Всего сообщений: {stats['total']}\n"
                f"Предложения водителей: {stats['offer']}\n"
                f"Запросы пассажиров: {stats['request']}\n"
                f"Не объявления: {stats['not_a_ride']}\n"
                f"Тестовые ответы: {'включены' if self._config.test_reply_mode else 'выключены'}\n"
                f"Парсер: {self._gemini.model if self._gemini else 'локальные правила'}"
            )
        else:
            reply = (
                "Я тестовый сборщик HamSafar.\n"
                "Отправь объявление о поездке, запрос пассажира, сообщение о посылке "
                "или обычный текст. Я покажу предварительный разбор.\n\n"
                "Команды: /status, /chatid"
            )
        self._api.send_message(chat_id, reply, message.get("message_id"))
        return True

    def _classify(self, text: str, message_date: datetime) -> tuple[ParsedMessage, str]:
        local = classify_message(text, message_date)
        if self._gemini is None:
            return local, "local"
        if (
            self._config.llm_mode == "fallback"
            and local.kind != "not_a_ride"
            and local.confidence >= 0.85
        ):
            return local, "local"
        try:
            return self._gemini.classify(text, message_date, local), "gemini"
        except Exception as error:
            LOGGER.warning("Gemini parsing failed; using local fallback: %s", error)
            return local, "local"

    def handle_update(self, update: dict[str, Any]) -> None:
        update_id = int(update["update_id"])
        is_edited = "edited_message" in update or "edited_channel_post" in update
        message = (
            update.get("message")
            or update.get("edited_message")
            or update.get("channel_post")
            or update.get("edited_channel_post")
        )
        if not message:
            return
        chat = message.get("chat") or {}
        if "id" not in chat:
            return
        chat_id = int(chat["id"])
        if not self._chat_is_allowed(chat_id):
            LOGGER.warning("Ignored message from unapproved chat %s", chat_id)
            return
        sender = message.get("from") or {}
        if sender.get("is_bot"):
            return
        text = str(message.get("text") or message.get("caption") or "").strip()
        if not text:
            return
        if text.startswith("/") and self._handle_command(message, text):
            return

        unix_date = int(message.get("date") or 0)
        message_date = datetime.fromtimestamp(unix_date, tz=timezone.utc).astimezone(
            self._timezone
        )
        parsed, parser_name = self._classify(text, message_date)
        is_new = self._storage.save_message(
            update_id=update_id,
            message=message,
            parsed=parsed,
            raw_text=text,
            is_edited=is_edited,
        )
        LOGGER.info(
            "Stored chat=%s message=%s parser=%s kind=%s confidence=%.2f",
            chat_id,
            message.get("message_id"),
            parser_name,
            parsed.kind,
            parsed.confidence,
        )
        if self._config.test_reply_mode and (is_new or is_edited):
            self._api.send_message(
                chat_id,
                _format_result(parsed, parser_name),
                message.get("message_id"),
            )

    def run(self) -> None:
        me = self._api.call("getMe", {})
        LOGGER.info("Collector started as @%s", me.get("username"))
        last_update_id = self._storage.get_last_update_id()
        offset = last_update_id + 1 if last_update_id is not None else None
        failure_delay = 1
        while self._running:
            try:
                for update in self._api.get_updates(offset):
                    update_id = int(update["update_id"])
                    self.handle_update(update)
                    self._storage.set_last_update_id(update_id)
                    offset = update_id + 1
                failure_delay = 1
            except Exception:
                LOGGER.exception("Polling failed; retrying in %s seconds", failure_delay)
                time.sleep(failure_delay)
                failure_delay = min(failure_delay * 2, 30)


def main() -> int:
    logging.basicConfig(
        level=os.getenv("LOG_LEVEL", "INFO").upper(),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    try:
        config = Config.from_environment()
        collector = Collector(config)
    except Exception as error:
        LOGGER.error("Configuration failed: %s", error)
        return 2
    signal.signal(signal.SIGTERM, collector.stop)
    signal.signal(signal.SIGINT, collector.stop)
    collector.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
