from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

from classifier import ParsedMessage


class MessageStorage:
    def __init__(self, database_path: Path) -> None:
        database_path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(database_path)
        self._connection.row_factory = sqlite3.Row
        self._create_schema()

    def _create_schema(self) -> None:
        self._connection.executescript(
            """
            pragma journal_mode = wal;

            create table if not exists incoming_messages (
              id integer primary key autoincrement,
              update_id integer not null,
              chat_id integer not null,
              chat_title text,
              message_id integer not null,
              sender_id integer,
              sender_name text,
              sender_username text,
              telegram_date text not null,
              raw_text text not null,
              parsed_json text not null,
              kind text not null,
              confidence real not null,
              is_edited integer not null default 0,
              received_at text not null default (datetime('now')),
              unique(chat_id, message_id)
            );

            create table if not exists collector_state (
              key text primary key,
              value text not null
            );
            """
        )
        self._connection.commit()

    def save_message(
        self,
        *,
        update_id: int,
        message: dict[str, Any],
        parsed: ParsedMessage,
        raw_text: str,
        is_edited: bool,
    ) -> bool:
        chat = message.get("chat") or {}
        sender = message.get("from") or {}
        sender_name = " ".join(
            value
            for value in (sender.get("first_name"), sender.get("last_name"))
            if value
        )
        payload = (
            update_id,
            int(chat["id"]),
            chat.get("title") or chat.get("username"),
            int(message["message_id"]),
            sender.get("id"),
            sender_name or None,
            sender.get("username"),
            str(message.get("date", "")),
            raw_text,
            json.dumps(parsed.to_dict(), ensure_ascii=False),
            parsed.kind,
            parsed.confidence,
            int(is_edited),
        )
        existing = self._connection.execute(
            "select 1 from incoming_messages where chat_id = ? and message_id = ?",
            (int(chat["id"]), int(message["message_id"])),
        ).fetchone()
        self._connection.execute(
            """
            insert into incoming_messages (
              update_id, chat_id, chat_title, message_id, sender_id,
              sender_name, sender_username, telegram_date, raw_text,
              parsed_json, kind, confidence, is_edited
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            on conflict(chat_id, message_id) do update set
              update_id = excluded.update_id,
              raw_text = excluded.raw_text,
              parsed_json = excluded.parsed_json,
              kind = excluded.kind,
              confidence = excluded.confidence,
              is_edited = excluded.is_edited,
              received_at = datetime('now')
            """,
            payload,
        )
        self._connection.commit()
        return existing is None

    def get_last_update_id(self) -> int | None:
        row = self._connection.execute(
            "select value from collector_state where key = 'last_update_id'"
        ).fetchone()
        return int(row["value"]) if row else None

    def set_last_update_id(self, update_id: int) -> None:
        self._connection.execute(
            """
            insert into collector_state(key, value) values('last_update_id', ?)
            on conflict(key) do update set value = excluded.value
            """,
            (str(update_id),),
        )
        self._connection.commit()

    def stats(self, chat_id: int) -> dict[str, int]:
        rows = self._connection.execute(
            """
            select kind, count(*) as count
            from incoming_messages
            where chat_id = ?
            group by kind
            """,
            (chat_id,),
        ).fetchall()
        result = {"offer": 0, "request": 0, "not_a_ride": 0}
        for row in rows:
            result[str(row["kind"])] = int(row["count"])
        result["total"] = sum(result.values())
        return result

