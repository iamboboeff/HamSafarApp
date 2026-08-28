from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from classifier import ParsedMessage  # noqa: E402
from storage import MessageStorage  # noqa: E402


class MessageStorageTest(unittest.TestCase):
    def test_upsert_deduplicates_by_chat_and_message(self) -> None:
        parsed = ParsedMessage(
            kind="offer",
            cargo=False,
            from_city="Худжанд",
            to_city="Душанбе",
            depart_date="2026-08-29",
            depart_time="10:00",
            date_precision="exact",
            seats=4,
            phone="552421001",
            confidence=0.95,
        )
        message = {
            "message_id": 10,
            "date": 1_777_000_000,
            "chat": {"id": -100123, "title": "HamSafar Test"},
            "from": {"id": 42, "first_name": "Test"},
        }
        with tempfile.TemporaryDirectory() as directory:
            storage = MessageStorage(Path(directory) / "collector.sqlite3")
            self.assertTrue(
                storage.save_message(
                    update_id=1,
                    message=message,
                    parsed=parsed,
                    raw_text="Худжанд → Душанбе",
                    is_edited=False,
                )
            )
            self.assertFalse(
                storage.save_message(
                    update_id=2,
                    message=message,
                    parsed=parsed,
                    raw_text="Худжанд → Душанбе, 4 места",
                    is_edited=True,
                )
            )
            self.assertEqual(storage.stats(-100123)["total"], 1)

    def test_update_offset_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            storage = MessageStorage(Path(directory) / "collector.sqlite3")
            self.assertIsNone(storage.get_last_update_id())
            storage.set_last_update_id(12345)
            self.assertEqual(storage.get_last_update_id(), 12345)


if __name__ == "__main__":
    unittest.main()

