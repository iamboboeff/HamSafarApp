from __future__ import annotations

import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from user_forwarder import (
    ForwardedMessageStore,
    UserForwarderConfig,
    _parse_chat_ids,
)


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


if __name__ == "__main__":
    unittest.main()
