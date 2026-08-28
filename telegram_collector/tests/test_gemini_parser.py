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
from gemini_parser import GeminiParserError, GeminiRideParser  # noqa: E402


NOW = datetime(2026, 8, 28, 8, 0, tzinfo=ZoneInfo("Asia/Dushanbe"))


class _FakeResponse:
    def __init__(self, payload: dict[str, object]) -> None:
        self._body = json.dumps(payload).encode("utf-8")

    def __enter__(self) -> "_FakeResponse":
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def read(self) -> bytes:
        return self._body


class GeminiRideParserTest(unittest.TestCase):
    def test_structured_result_and_phone_redaction(self) -> None:
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
                    "candidates": [
                        {
                            "content": {
                                "parts": [{"text": json.dumps(model_result)}]
                            }
                        }
                    ]
                }
            )

        text = "БЕШАРИКДАН ТОШКЕНТ юрамиз 3 та одам +998941317805"
        local = classify_message(text, NOW)
        parser = GeminiRideParser(api_key="test-key", opener=opener)
        parsed = parser.classify(text, NOW, local)

        request = captured["request"]
        body = json.loads(request.data.decode("utf-8"))  # type: ignore[attr-defined]
        sent_prompt = body["contents"][0]["parts"][0]["text"]
        self.assertIn(
            "/v1beta/models/gemini-3.7-flash:generateContent",
            request.full_url,  # type: ignore[attr-defined]
        )
        self.assertNotIn("+998941317805", sent_prompt)
        self.assertIn("[PHONE]", sent_prompt)
        self.assertEqual(
            body["generationConfig"]["thinkingConfig"]["thinkingLevel"], "low"
        )
        response_text = body["generationConfig"]["responseFormat"]["text"]
        self.assertEqual(response_text["mimeType"], "application/json")
        self.assertEqual(response_text["schema"]["type"], "object")
        self.assertIn("kind", response_text["schema"]["required"])
        self.assertNotIn("temperature", body["generationConfig"])
        self.assertEqual(parsed.from_city, "Бешарык")
        self.assertEqual(parsed.to_city, "Ташкент")
        self.assertEqual(parsed.phone, "+998941317805")
        self.assertEqual(parsed.seats, 3)

    def test_http_error_includes_safe_google_reason(self) -> None:
        def opener(request: object, *, timeout: int) -> _FakeResponse:
            del request, timeout
            body = json.dumps(
                {
                    "error": {
                        "code": 400,
                        "status": "FAILED_PRECONDITION",
                        "message": "User location is not supported for the API use.",
                    }
                }
            ).encode("utf-8")
            raise urllib.error.HTTPError(
                "https://generativelanguage.googleapis.com/",
                400,
                "Bad Request",
                hdrs=None,
                fp=io.BytesIO(body),
            )

        parser = GeminiRideParser(api_key="test-key", opener=opener)
        local = classify_message("Худжанд Душанбе", NOW)

        with self.assertRaisesRegex(
            GeminiParserError,
            "HTTP 400: FAILED_PRECONDITION.*User location is not supported",
        ):
            parser.classify("Худжанд Душанбе", NOW, local)


if __name__ == "__main__":
    unittest.main()
