from __future__ import annotations

import sys
import unittest
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from classifier import classify_message  # noqa: E402


NOW = datetime(2026, 8, 17, 18, 0, tzinfo=ZoneInfo("Asia/Dushanbe"))


class ClassifierTest(unittest.TestCase):
    def test_reference_messages(self) -> None:
        cases = [
            ("Mengami uka", "not_a_ride", False),
            (
                "Салом алейкум. Нужен такси Ташкент - Ойбек, есть 1 пассажир. Метро Минор.",
                "request",
                False,
            ),
            ("990190966", "not_a_ride", False),
            ("+998950373299 телефон килинг", "not_a_ride", False),
            (
                "душанбе мерафтагиҳо ҳастиянми срочно пасилка ҳаст",
                "request",
                True,
            ),
            (
                "Салом аллейкум пагох то соати 10:00 аз самти Хучанд ба Душанбе "
                "меравам 4 нафар лозим бор поссылька бошадам мебарам занг занед 552421001",
                "offer",
                True,
            ),
            ("олинди", "not_a_ride", False),
            ("250 ками", "not_a_ride", False),
        ]
        for text, expected_kind, expected_cargo in cases:
            with self.subTest(text=text):
                parsed = classify_message(text, NOW)
                self.assertEqual(parsed.kind, expected_kind)
                self.assertEqual(parsed.cargo, expected_cargo)

    def test_complete_tajik_offer(self) -> None:
        parsed = classify_message(
            "пагох то соати 10:00 аз самти Хучанд ба Душанбе меравам "
            "4 нафар лозим, занг занед 552421001",
            NOW,
        )
        self.assertEqual(parsed.kind, "offer")
        self.assertEqual(parsed.from_city, "Худжанд")
        self.assertEqual(parsed.to_city, "Душанбе")
        self.assertEqual(parsed.depart_date, "2026-08-18")
        self.assertEqual(parsed.depart_time, "10:00")
        self.assertEqual(parsed.seats, 4)
        self.assertEqual(parsed.phone, "552421001")

    def test_colloquial_tajik_offer_with_kas(self) -> None:
        parsed = classify_message(
            "А Душанбе Худжанд мерам 4 кас даркор мошин сонг "
            "+92 760 80 20 соати 13:00",
            NOW,
        )
        self.assertEqual(parsed.kind, "offer")
        self.assertEqual(parsed.from_city, "Душанбе")
        self.assertEqual(parsed.to_city, "Худжанд")
        self.assertEqual(parsed.seats, 4)
        self.assertEqual(parsed.depart_time, "13:00")
        self.assertEqual(parsed.phone, "+927608020")

    def test_bare_phone_is_not_a_ride(self) -> None:
        parsed = classify_message("+998931861414 tel qiling", NOW)
        self.assertEqual(parsed.kind, "not_a_ride")
        self.assertEqual(parsed.phone, "+998931861414")

    def test_besharyk_to_tashkent_with_uzbek_suffixes(self) -> None:
        parsed = classify_message(
            "ЭРТАЛАБ БЕШАРИКДАН ТОШКЕНТ шахар ичига юрамиз "
            "3 та одам ва почта оламиз Авто Коболт БАГАЖ бор "
            "+998941317805",
            NOW,
        )
        self.assertEqual(parsed.kind, "offer")
        self.assertEqual(parsed.from_city, "Бешарык")
        self.assertEqual(parsed.to_city, "Ташкент")
        self.assertEqual(parsed.seats, 3)
        self.assertTrue(parsed.cargo)

    def test_kokand_multistop_offer(self) -> None:
        parsed = classify_message(
            "КУКОНДАН ЮРАМИЗ, ДУШАНБЕ, КУРГОН, ПЯНЖ, "
            "ШАХРИТУЗ, ТАМОЖНА ЮРАМИЗ, МОШИНА ОНИКС-ТРЕКЕР",
            NOW,
        )
        self.assertEqual(parsed.kind, "offer")
        self.assertEqual(parsed.from_city, "Коканд")
        self.assertEqual(parsed.to_city, "Душанбе")

    def test_oybek_is_a_route_endpoint(self) -> None:
        parsed = classify_message(
            "Салом, аз Ойбек ба Тошкент меравам, 2 нафар",
            NOW,
        )
        self.assertEqual(parsed.kind, "offer")
        self.assertEqual(parsed.from_city, "Ойбек")
        self.assertEqual(parsed.to_city, "Ташкент")
        self.assertEqual(parsed.seats, 2)

    def test_extracts_price_and_stated_contact_method(self) -> None:
        parsed = classify_message(
            "Из Худжанда в Душанбе еду, 3 места, WhatsApp +992900001122, 120 сомони",
            NOW,
        )
        self.assertEqual(parsed.price, 120)
        self.assertEqual(parsed.currency, "TJS")
        self.assertEqual(parsed.contact_methods, ("whatsapp",))


if __name__ == "__main__":
    unittest.main()
