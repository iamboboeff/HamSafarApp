from __future__ import annotations

import io
import json
import sys
import unittest
import urllib.error
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from classifier import classify_message  # noqa: E402
from openrouter_parser import (  # noqa: E402
    OpenRouterParserError,
    OpenRouterRideParser,
)


NOW = datetime(2026, 8, 28, 8, 0, tzinfo=ZoneInfo("Asia/Dushanbe"))
MODELS = (
    "dots-studio/dots-3-note-preview:free",
    "z-ai/glm-5.2:free",
    "openrouter/free",
)


class _FakeResponse:
    def __init__(self, payload: dict[str, object]) -> None:
        self._body = json.dumps(payload).encode("utf-8")

    def __enter__(self) -> "_FakeResponse":
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def read(self) -> bytes:
        return self._body


class OpenRouterRideParserTest(unittest.TestCase):
    def test_structured_result_fallback_chain_and_phone_redaction(self) -> None:
        captured: dict[str, object] = {}
        model_result = {
            "kind": "offer",
            "cargo": True,
            "from_city": "Бешарык",
            "to_city": "Ташкент",
            "depart_date": None,
            "depart_time": None,
            "date_precision": "unknown",
            "seats": 3,
            "confidence": 0.96,
        }

        def opener(request: object, *, timeout: int) -> _FakeResponse:
            captured["timeout"] = timeout
            captured["request"] = request
            return _FakeResponse(
                {
                    "model": MODELS[0],
                    "choices": [
                        {
                            "message": {
                                "content": json.dumps(model_result),
                                "role": "assistant",
                            }
                        }
                    ],
                }
            )

        text = "БЕШАРИКДАН ТОШКЕНТ юрамиз 3 та одам +998941317805"
        local = classify_message(text, NOW)
        parser = OpenRouterRideParser(
            api_key="test-key",
            models=MODELS,
            opener=opener,
        )
        parsed = parser.classify(text, NOW, local)

        request = captured["request"]
        body = json.loads(request.data.decode("utf-8"))  # type: ignore[attr-defined]
        sent_prompt = body["messages"][1]["content"]
        self.assertEqual(
            request.full_url,  # type: ignore[attr-defined]
            "https://openrouter.ai/api/v1/chat/completions",
        )
        self.assertEqual(
            request.get_header("Authorization"),  # type: ignore[attr-defined]
            "Bearer test-key",
        )
        self.assertNotIn("+998941317805", sent_prompt)
        self.assertIn("[PHONE]", sent_prompt)
        self.assertEqual(body["model"], MODELS[0])
        self.assertTrue(body["provider"]["require_parameters"])
        self.assertEqual(body["reasoning"]["effort"], "none")
        self.assertEqual(body["max_tokens"], 1600)
        response_format = body["response_format"]
        self.assertEqual(response_format["type"], "json_schema")
        self.assertTrue(response_format["json_schema"]["strict"])
        self.assertEqual(parsed.from_city, "Бешарык")
        self.assertEqual(parsed.to_city, "Ташкент")
        self.assertEqual(parsed.phone, "+998941317805")
        self.assertEqual(parsed.seats, 3)
        self.assertEqual(parser.last_model, MODELS[0])

    def test_accepts_fenced_json_from_text_part_response(self) -> None:
        model_result = {
            "kind": "request",
            "cargo": False,
            "from_city": "Худжанд",
            "to_city": "Душанбе",
            "depart_date": None,
            "depart_time": "13:00:00+05:00",
            "date_precision": "unknown",
            "seats": 2,
            "price": None,
            "currency": None,
            "contact_methods": ["telegram"],
            "confidence": 0.91,
        }

        def opener(request: object, *, timeout: int) -> _FakeResponse:
            del request, timeout
            return _FakeResponse(
                {
                    "model": MODELS[0],
                    "choices": [
                        {
                            "message": {
                                "content": [
                                    {
                                        "type": "text",
                                        "text": "```json\n"
                                        + json.dumps(model_result)
                                        + "\n```",
                                    }
                                ]
                            }
                        }
                    ],
                }
            )

        text = "2 нафар аз Хучанд ба Душанбе даркор"
        local = classify_message(text, NOW)
        parsed = OpenRouterRideParser(
            api_key="test-key",
            models=MODELS,
            opener=opener,
        ).classify(text, NOW, local)

        self.assertEqual(parsed.kind, "request")
        self.assertEqual(parsed.from_city, "Худжанд")
        self.assertEqual(parsed.to_city, "Душанбе")
        self.assertEqual(parsed.depart_time, "13:00")

    def test_accepts_message_parsed_object(self) -> None:
        model_result = {
            "kind": "offer",
            "cargo": False,
            "from_city": "Ойбек",
            "to_city": "Ташкент",
            "depart_date": None,
            "depart_time": None,
            "date_precision": "unknown",
            "seats": 4,
            "price": None,
            "currency": None,
            "contact_methods": ["phone"],
            "confidence": 0.94,
        }

        def opener(request: object, *, timeout: int) -> _FakeResponse:
            del request, timeout
            return _FakeResponse(
                {
                    "model": MODELS[0],
                    "choices": [{"message": {"content": None, "parsed": model_result}}],
                }
            )

        text = "Ойбекдан Тошкентга 4 та жой бор"
        local = classify_message(text, NOW)
        parsed = OpenRouterRideParser(
            api_key="test-key",
            models=MODELS,
            opener=opener,
        ).classify(text, NOW, local)

        self.assertEqual(parsed.from_city, "Ойбек")
        self.assertEqual(parsed.to_city, "Ташкент")

    def test_http_error_includes_safe_openrouter_reason(self) -> None:
        def opener(request: object, *, timeout: int) -> _FakeResponse:
            del request, timeout
            body = json.dumps(
                {
                    "error": {
                        "code": 429,
                        "message": "Rate limit exceeded for free model.",
                    }
                }
            ).encode("utf-8")
            raise urllib.error.HTTPError(
                "https://openrouter.ai/api/v1/chat/completions",
                429,
                "Too Many Requests",
                hdrs=None,
                fp=io.BytesIO(body),
            )

        parser = OpenRouterRideParser(
            api_key="test-key",
            models=MODELS,
            opener=opener,
        )
        local = classify_message("Худжанд Душанбе", NOW)

        with self.assertRaisesRegex(
            OpenRouterParserError,
            "HTTP 429: 429.*Rate limit exceeded",
        ):
            parser.classify("Худжанд Душанбе", NOW, local)

    def test_retries_next_model_for_http_200_error_envelope(self) -> None:
        attempts: list[str] = []
        model_result = {
            "kind": "offer",
            "cargo": False,
            "from_city": "Душанбе",
            "to_city": "Худжанд",
            "depart_date": None,
            "depart_time": "13:00",
            "date_precision": "unknown",
            "seats": 4,
            "price": None,
            "currency": None,
            "contact_methods": ["phone"],
            "confidence": 0.95,
        }

        def opener(request: object, *, timeout: int) -> _FakeResponse:
            del timeout
            body = json.loads(request.data.decode("utf-8"))  # type: ignore[attr-defined]
            attempts.append(body["model"])
            if len(attempts) == 1:
                return _FakeResponse(
                    {"error": {"code": 502, "message": "Upstream unavailable"}}
                )
            return _FakeResponse(
                {
                    "model": MODELS[1],
                    "choices": [{"message": {"content": json.dumps(model_result)}}],
                }
            )

        text = "Душанбе Худжанд мерам 4 кас даркор"
        local = classify_message(text, NOW)
        parser = OpenRouterRideParser(
            api_key="test-key",
            models=MODELS,
            opener=opener,
        )
        parsed = parser.classify(text, NOW, local)

        self.assertEqual(attempts, list(MODELS[:2]))
        self.assertEqual(parsed.kind, "offer")
        self.assertEqual(parser.last_model, MODELS[1])


if __name__ == "__main__":
    unittest.main()
