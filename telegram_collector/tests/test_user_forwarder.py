from __future__ import annotations

import os
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from user_forwarder import (
    ForwardedMessageStore,
    UserForwarderConfig,
    _parse_chat_ids,
)
from telegram_publisher import TelegramBatchMessage


class ParseChatIdsTest(unittest.TestCase):
    def test_parses_and_deduplicates_ids(self) -> None:
        self.assertEqual(
            _parse_chat_ids("-1001, -1002,-1001", "CHATS"),
            frozenset({-1001, -1002}),
        )

    def test_rejects_empty_or_non_numeric_values(self) -> None:
        with self.assertRaises(RuntimeError):
            _parse_chat_ids("", "CHATS")
        with self.assertRaises(RuntimeError):
            _parse_chat_ids("-1001,group", "CHATS")


class UserForwarderConfigTest(unittest.TestCase):
    def test_loads_safe_configuration(self) -> None:
        environment = {
            "USERBOT_API_ID": "123",
            "USERBOT_API_HASH": "secret",
            "USERBOT_SESSION": "session",
            "USERBOT_SOURCE_CHAT_IDS": "-1001,-1002",
            "USERBOT_TARGET_CHAT_ID": "-1003",
            "USERBOT_FORWARD_DELAY_SECONDS": "2.5",
        }
        with patch.dict(os.environ, environment, clear=True):
            config = UserForwarderConfig.from_environment(Path("/tmp/data"))
        self.assertEqual(config.api_id, 123)
        self.assertEqual(config.target_chat_id, -1003)
        self.assertEqual(config.forward_delay_seconds, 2.5)

    def test_rejects_target_in_source_list(self) -> None:
        environment = {
            "USERBOT_API_ID": "123",
            "USERBOT_API_HASH": "secret",
            "USERBOT_SESSION": "session",
            "USERBOT_SOURCE_CHAT_IDS": "-1001,-1002",
            "USERBOT_TARGET_CHAT_ID": "-1002",
        }
        with patch.dict(os.environ, environment, clear=True):
            with self.assertRaises(RuntimeError):
                UserForwarderConfig.from_environment(Path("/tmp/data"))


class ForwardedMessageStoreTest(unittest.TestCase):
    def test_persists_deduplication_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "forwarder.sqlite3"
            store = ForwardedMessageStore(path)
            self.assertFalse(store.contains(-1001, 42))
            store.mark(-1001, 42)
            self.assertTrue(store.contains(-1001, 42))
            store.close()

            reopened = ForwardedMessageStore(path)
            self.assertTrue(reopened.contains(-1001, 42))
            reopened.close()

    def test_persists_pending_author_batch(self) -> None:
        message = TelegramBatchMessage(
            source_chat_id=-1001,
            source_chat_title="Taxi",
            source_chat_username="taxi_group",
            source_message_id=50,
            sender_id=42,
            sender_name="Driver",
            sender_username="driver42",
            sent_at=datetime(2026, 8, 28, 10, tzinfo=timezone.utc),
            text="Худжанд Душанбе",
        )
        with tempfile.TemporaryDirectory() as directory:
            store = ForwardedMessageStore(Path(directory) / "forwarder.sqlite3")
            self.assertTrue(store.enqueue("live:-1001:42", message))
            self.assertFalse(store.enqueue("live:-1001:42", message))
            loaded = store.load_batch("live:-1001:42")
            self.assertEqual(loaded, [message])
            self.assertFalse(store.batch_was_forwarded("live:-1001:42"))
            store.mark_batch_forwarded("live:-1001:42")
            self.assertTrue(store.batch_was_forwarded("live:-1001:42"))
            store.complete_batch("live:-1001:42", loaded)
            self.assertTrue(store.contains(-1001, 50))
            self.assertEqual(store.load_batch("live:-1001:42"), [])
            store.close()


if __name__ == "__main__":
    unittest.main()
