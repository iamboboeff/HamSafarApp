from __future__ import annotations

import sys
import unittest
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from telegram_publisher import (  # noqa: E402
    TelegramBatchMessage,
    TelegramLeadPipeline,
)


class _FakeWriter:
    def __init__(self) -> None:
        self.calls: list[tuple[dict[str, object], bool]] = []

    def upsert(
        self,
        payload: dict[str, object],
        *,
        merge_duplicates: bool = True,
    ) -> None:
        self.calls.append((payload, merge_duplicates))


class TelegramLeadPipelineTest(unittest.TestCase):
    def test_combines_author_messages_and_keeps_contact_metadata(self) -> None:
        writer = _FakeWriter()
        pipeline = TelegramLeadPipeline(
            writer=writer,  # type: ignore[arg-type]
            timezone_name="Asia/Dushanbe",
            ai=None,
        )
        messages = [
            TelegramBatchMessage(
                source_chat_id=-1001234567890,
                source_chat_title="Taxi",
                source_chat_username="taxi_group",
                source_message_id=10,
                sender_id=42,
                sender_name="Driver",
                sender_username="driver42",
                sent_at=datetime(2026, 8, 28, 8, tzinfo=timezone.utc),
                text="Салом, аз Худжанд",
            ),
            TelegramBatchMessage(
                source_chat_id=-1001234567890,
                source_chat_title="Taxi",
                source_chat_username="taxi_group",
                source_message_id=11,
                sender_id=42,
                sender_name="Driver",
                sender_username="driver42",
                sent_at=datetime(2026, 8, 28, 8, 1, tzinfo=timezone.utc),
                text="ба Душанбе меравам, 4 нафар, WhatsApp +992900001122, 120 сомони",
            ),
        ]

        prepared = pipeline.prepare(messages)

        self.assertIsNotNone(prepared)
        assert prepared is not None
        self.assertEqual(prepared.parsed.from_city, "Худжанд")
        self.assertEqual(prepared.parsed.to_city, "Душанбе")
        self.assertEqual(prepared.parsed.price, 120)
        self.assertEqual(prepared.parsed.contact_methods, ("whatsapp",))
        self.assertEqual(prepared.payload["source_message_ids"], [10, 11])
        self.assertEqual(prepared.payload["author_username"], "driver42")
        self.assertEqual(
            prepared.payload["source_message_url"],
            "https://t.me/taxi_group/10",
        )

        pipeline.publish(prepared)
        self.assertEqual(writer.calls, [(prepared.payload, True)])

    def test_content_fingerprint_deduplicates_automatic_and_manual_paths(self) -> None:
        pipeline = TelegramLeadPipeline(
            writer=_FakeWriter(),  # type: ignore[arg-type]
            timezone_name="Asia/Dushanbe",
            ai=None,
        )
        sent_at = datetime(2026, 8, 28, 8, tzinfo=timezone.utc)
        automatic = TelegramBatchMessage(
            source_chat_id=-100123,
            source_chat_title="Original taxi chat",
            source_chat_username="original_chat",
            source_message_id=15,
            sender_id=42,
            sender_name="Driver",
            sender_username="driver42",
            sent_at=sent_at,
            text="Душанбе Худжанд мерам 4 кас",
        )
        manual = TelegramBatchMessage(
            source_chat_id=-5496071500,
            source_chat_title="Такси HamSafar",
            source_chat_username=None,
            source_message_id=63,
            sender_id=42,
            sender_name="Driver",
            sender_username="driver42",
            sent_at=sent_at,
            text="  Душанбе   Худжанд МЕРАМ 4 КАС  ",
        )

        automatic_prepared = pipeline.prepare([automatic])
        manual_prepared = pipeline.prepare([manual])

        self.assertIsNotNone(automatic_prepared)
        self.assertIsNotNone(manual_prepared)
        assert automatic_prepared is not None and manual_prepared is not None
        self.assertEqual(
            automatic_prepared.payload["source_batch_key"],
            manual_prepared.payload["source_batch_key"],
        )

    def test_rejects_obvious_non_ride_batch(self) -> None:
        pipeline = TelegramLeadPipeline(
            writer=_FakeWriter(),  # type: ignore[arg-type]
            timezone_name="Asia/Dushanbe",
            ai=None,
        )
        message = TelegramBatchMessage(
            source_chat_id=-1001,
            source_chat_title="Taxi",
            source_chat_username=None,
            source_message_id=1,
            sender_id=2,
            sender_name="User",
            sender_username=None,
            sent_at=datetime(2026, 8, 28, tzinfo=timezone.utc),
            text="Всем доброе утро",
        )
        self.assertIsNone(pipeline.prepare([message]))

    @staticmethod
    def _pipeline() -> TelegramLeadPipeline:
        return TelegramLeadPipeline(
            writer=_FakeWriter(),  # type: ignore[arg-type]
            timezone_name="Asia/Dushanbe",
            ai=None,
        )

    @staticmethod
    def _message(*, sender_id: int | None, sender_username: str | None, text: str) -> TelegramBatchMessage:
        return TelegramBatchMessage(
            source_chat_id=-1001,
            source_chat_title="Taxi",
            source_chat_username=None,
            source_message_id=1,
            sender_id=sender_id,
            sender_name=None if sender_id is None else "Driver",
            sender_username=sender_username,
            sent_at=datetime(2026, 8, 28, 8, tzinfo=timezone.utc),
            text=text,
        )

    def test_skips_a_listing_nobody_can_answer(self) -> None:
        """No handle and no phone means every button in the app is missing."""
        unreachable = self._message(
            sender_id=None,
            sender_username=None,
            text="Душанбе Худжанд 4 нафар",
        )
        self.assertIsNone(self._pipeline().prepare([unreachable]))

        # The same text from an author the app can deep-link is published.
        reachable = self._message(
            sender_id=None,
            sender_username="driver42",
            text="Душанбе Худжанд 4 нафар",
        )
        self.assertIsNotNone(self._pipeline().prepare([reachable]))

    def test_a_listing_without_a_date_dies_with_the_day_it_was_written(self) -> None:
        """Such a post always means today, and most listings are written that way."""
        prepared = self._pipeline().prepare(
            [
                self._message(
                    sender_id=42,
                    sender_username="driver42",
                    text="Душанбе Худжанд 4 нафар даркор",
                )
            ]
        )
        assert prepared is not None
        self.assertEqual(prepared.parsed.date_precision, "unknown")
        expires = datetime.fromisoformat(str(prepared.payload["expires_at"]))
        local = expires.astimezone(ZoneInfo("Asia/Dushanbe"))
        # Posted 2026-08-28 13:00 Dushanbe time — gone at the end of that day,
        # not two days later as the flat rule used to give it.
        self.assertEqual(local.date(), date(2026, 8, 28))
        self.assertEqual((local.hour, local.minute), (23, 59))


if __name__ == "__main__":
    unittest.main()
