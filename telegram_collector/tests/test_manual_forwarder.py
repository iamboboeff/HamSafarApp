from __future__ import annotations

import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from manual_forwarder import (  # noqa: E402
    ManualForwardBatcher,
    manual_forward_from_bot_message,
)


class _Clock:
    def __init__(self) -> None:
        self.value = 1000.0

    def __call__(self) -> float:
        return self.value


class _FakePipeline:
    def __init__(self) -> None:
        self.prepared_messages: list[list[object]] = []
        self.published: list[tuple[object, bool]] = []

    def prepare(self, messages: list[object]) -> object:
        copied = list(messages)
        self.prepared_messages.append(copied)
        return {"message_count": len(copied)}

    def publish(self, prepared: object, *, merge_duplicates: bool = True) -> None:
        self.published.append((prepared, merge_duplicates))


def _forwarded_user_message(
    *,
    message_id: int,
    original_timestamp: int,
    text: str,
) -> dict[str, object]:
    return {
        "message_id": message_id,
        "date": original_timestamp + 300,
        "chat": {"id": -5496071500, "title": "Такси HamSafar"},
        "from": {"id": 1350559985, "first_name": "Admin"},
        "text": text,
        "forward_origin": {
            "type": "user",
            "date": original_timestamp,
            "sender_user": {
                "id": 42,
                "first_name": "Абдуллаев",
                "username": "driver42",
            },
        },
    }


class ManualForwardMetadataTest(unittest.TestCase):
    def test_extracts_original_user_and_date(self) -> None:
        timestamp = int(
            datetime(2026, 8, 28, 21, 35, tzinfo=timezone.utc).timestamp()
        )
        message = _forwarded_user_message(
            message_id=63,
            original_timestamp=timestamp,
            text="Душанбе Худжанд мерам",
        )

        envelope = manual_forward_from_bot_message(
            message,
            str(message["text"]),
        )

        self.assertIsNotNone(envelope)
        assert envelope is not None
        self.assertEqual(envelope.message.source_chat_id, -5496071500)
        self.assertEqual(envelope.message.source_message_id, 63)
        self.assertEqual(envelope.message.sender_id, 42)
        self.assertEqual(envelope.message.sender_name, "Абдуллаев")
        self.assertEqual(envelope.message.sender_username, "driver42")
        self.assertEqual(envelope.message.sent_at.timestamp(), timestamp)

    def test_extracts_original_channel_link_metadata(self) -> None:
        message = {
            "message_id": 70,
            "date": 1_777_000_300,
            "chat": {"id": -5496071500, "title": "Такси HamSafar"},
            "caption": "Ташкент Душанбе едем",
            "forward_origin": {
                "type": "channel",
                "date": 1_777_000_000,
                "chat": {
                    "id": -1001234567890,
                    "title": "Taxi source",
                    "username": "taxi_source",
                },
                "message_id": 88,
                "author_signature": "Dispatcher",
            },
        }

        envelope = manual_forward_from_bot_message(
            message,
            str(message["caption"]),
        )

        self.assertIsNotNone(envelope)
        assert envelope is not None
        self.assertEqual(envelope.message.source_chat_id, -1001234567890)
        self.assertEqual(envelope.message.source_message_id, 88)
        self.assertEqual(envelope.message.source_chat_username, "taxi_source")
        self.assertEqual(envelope.message.sender_name, "Dispatcher")

    def test_ordinary_group_message_is_not_manual_forward(self) -> None:
        message = {
            "message_id": 1,
            "date": 1_777_000_000,
            "chat": {"id": -5496071500, "title": "Такси HamSafar"},
            "text": "Привет",
        }
        self.assertIsNone(manual_forward_from_bot_message(message, "Привет"))


class ManualForwardBatcherTest(unittest.TestCase):
    def test_groups_same_author_then_publishes_without_overwriting_duplicate(self) -> None:
        clock = _Clock()
        pipeline = _FakePipeline()
        original_timestamp = 1_777_000_000
        with tempfile.TemporaryDirectory() as directory:
            batcher = ManualForwardBatcher(
                data_dir=Path(directory),
                pipeline=pipeline,  # type: ignore[arg-type]
                batch_window_seconds=120,
                clock=clock,
            )
            first = _forwarded_user_message(
                message_id=63,
                original_timestamp=original_timestamp,
                text="Душанбе Худжанд мерам",
            )
            second = _forwarded_user_message(
                message_id=64,
                original_timestamp=original_timestamp + 60,
                text="4 кас даркор соати 13:00",
            )

            self.assertTrue(batcher.enqueue(first, str(first["text"])))
            clock.value += 30
            self.assertTrue(batcher.enqueue(second, str(second["text"])))
            clock.value += 119
            batcher.flush_due()
            self.assertEqual(pipeline.published, [])
            clock.value += 2
            batcher.flush_due()

            self.assertEqual(len(pipeline.prepared_messages), 1)
            self.assertEqual(len(pipeline.prepared_messages[0]), 2)
            self.assertEqual(
                pipeline.published,
                [({"message_count": 2}, False)],
            )
            batcher.close()

    def test_does_not_group_same_author_messages_over_two_minutes_apart(self) -> None:
        clock = _Clock()
        pipeline = _FakePipeline()
        original_timestamp = 1_777_000_000
        with tempfile.TemporaryDirectory() as directory:
            batcher = ManualForwardBatcher(
                data_dir=Path(directory),
                pipeline=pipeline,  # type: ignore[arg-type]
                batch_window_seconds=120,
                clock=clock,
            )
            first = _forwarded_user_message(
                message_id=63,
                original_timestamp=original_timestamp,
                text="Душанбе Худжанд мерам",
            )
            second = _forwarded_user_message(
                message_id=64,
                original_timestamp=original_timestamp + 121,
                text="Худжанд Душанбе мерам",
            )

            self.assertTrue(batcher.enqueue(first, str(first["text"])))
            self.assertTrue(batcher.enqueue(second, str(second["text"])))
            clock.value += 121
            batcher.flush_due()

            self.assertEqual(len(pipeline.prepared_messages), 2)
            self.assertEqual(
                [len(messages) for messages in pipeline.prepared_messages],
                [1, 1],
            )
            self.assertEqual(len(pipeline.published), 2)
            batcher.close()


if __name__ == "__main__":
    unittest.main()
