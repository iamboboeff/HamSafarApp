from __future__ import annotations

import re
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class ParsedMessage:
    kind: str
    cargo: bool
    from_city: str | None
    to_city: str | None
    depart_date: str | None
    depart_time: str | None
    date_precision: str
    seats: int | None
    phone: str | None
    confidence: float
    price: int | None = None
    currency: str | None = None
    contact_methods: tuple[str, ...] = ()

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


_CITY_ALIASES: dict[str, tuple[str, ...]] = {
    "Душанбе": ("душанбе", "dushanbe"),
    "Худжанд": ("худжанд", "хучанд", "хуҷанд", "khujand"),
    "Бохтар": (
        "бохтар",
        "курган-тюбе",
        "қӯрғонтеппа",
        "кургантюбе",
        "кургон",
        "қурғон",
    ),
    "Куляб": ("куляб", "кулоб", "кӯлоб", "kulob"),
    "Пенджикент": ("панджакент", "пенджикент", "панчакент", "panjakent"),
    "Истаравшан": ("истаравшан", "ура-тюбе", "urа-tube"),
    "Панч": ("панч", "панҷ", "пянж", "panj"),
    "Шахритус": (
        "шахритус",
        "шахритуз",
        "шаҳритус",
        "шахритюз",
        "shahritus",
        "shahrtuz",
    ),
    "Ташкент": ("ташкент", "тошкент", "tashkent", "toshkent"),
    "Ойбек": ("ойбек", "айбек", "oybek"),
    "Самарканд": ("самарканд", "самарқанд", "samarqand", "samarkand"),
    "Бухара": ("бухара", "бухоро", "buxoro", "bukhara"),
    "Коканд": ("коканд", "кукон", "қўқон", "qo'qon", "qoqon"),
    "Бешарык": ("бешарык", "бешарик", "beshariq", "besharik"),
    "Москва": ("москва", "масква", "moscow", "moskva"),
    "Санкт-Петербург": (
        "санкт-петербург",
        "санкт петербург",
        "питер",
        "санкт питер бург",
        "saint petersburg",
    ),
}

_OFFER_RE = re.compile(
    r"\b(?:еду|едем|поеду|выезжаю|выезжаем|"
    r"меравам|мерам|мерем|рафта\s+истодаам|"
    r"юрамиз|юраман|борамиз|кетаман|кетяпман|бораман|"
    r"йўлга\s+чиқаман)\b",
    re.IGNORECASE,
)
_REQUEST_RE = re.compile(
    r"(?:нуж(?:ен|на|но)\s+такси|ищу\s+(?:такси|машин|мест)|"
    r"такси\s+(?:даркор|лозим|керак)|"
    r"мерафтаги|мерафтагӣ|ҳастиянми|хастиянми|"
    r"машина\s+(?:есть|есть\s+ли)|такси\s+керак|"
    r"ягон\s+такси|такси\s+ай\b)",
    re.IGNORECASE,
)
_CARGO_RE = re.compile(
    r"\b(?:посылк\w*|посыл\w*|пасил\w*|поссы?л\w*|почт\w*|груз\w*|бор)\b",
    re.IGNORECASE,
)
_SEATS_RE = re.compile(
    r"(?<!\d)(\d{1,2})\s*(?:та\s*)?(?:свободн\w*\s*)?"
    r"(?:мест\w*|нафар|одам\w*|кас|пассажир\w*)\b",
    re.IGNORECASE,
)
_PHONE_RE = re.compile(r"(?<!\d)(?:\+?\d[\d\s()\-]{7,}\d)(?!\d)")
_TIME_RE = re.compile(
    r"(?:до|в|соат(?:и)?|soat)\s*(\d{1,2})(?:[:.](\d{2}))?",
    re.IGNORECASE,
)
_PRICE_RE = re.compile(
    r"(?<!\d)(\d{1,7})\s*(сомон(?:и)?|смн|tjs|сум|сўм|so['’]?m|uzs)\b",
    re.IGNORECASE,
)
_WHATSAPP_RE = re.compile(r"\b(?:whats?app|ватсап|вацап|вотсап)\b", re.IGNORECASE)
_TELEGRAM_RE = re.compile(r"\b(?:telegram|телеграм|телега|тг)\b", re.IGNORECASE)
_CALL_RE = re.compile(
    r"\b(?:звон\w*|позвон\w*|зан[гк]\w*|телефон\w*|қўнғироқ\w*)\b",
    re.IGNORECASE,
)


def _find_cities(text: str) -> list[str]:
    matches: list[tuple[int, str]] = []
    lowered = text.lower()
    for canonical, aliases in _CITY_ALIASES.items():
        best_position: int | None = None
        for alias in aliases:
            found = re.search(
                rf"(?<!\w){re.escape(alias)}"
                rf"(?:дан|да|гача|га|dan|da|gacha|ga|а|е|у|ом)?(?!\w)",
                lowered,
                re.IGNORECASE,
            )
            if found and (best_position is None or found.start() < best_position):
                best_position = found.start()
        if best_position is not None:
            matches.append((best_position, canonical))
    matches.sort(key=lambda item: item[0])
    return [city for _, city in matches]


def _extract_phone(text: str) -> str | None:
    for match in _PHONE_RE.finditer(text):
        raw = match.group(0).strip()
        normalized = ("+" if raw.startswith("+") else "") + re.sub(r"\D", "", raw)
        digit_count = len(normalized.lstrip("+"))
        if 9 <= digit_count <= 15:
            return normalized
    return None


def _extract_price(text: str) -> tuple[int | None, str | None]:
    match = _PRICE_RE.search(text)
    if not match:
        return None, None
    value = int(match.group(1))
    unit = match.group(2).lower()
    currency = "UZS" if unit in {"сум", "сўм", "som", "so'm", "so’m", "uzs"} else "TJS"
    return value, currency


def _extract_contact_methods(text: str, phone: str | None) -> tuple[str, ...]:
    methods: list[str] = []
    if _TELEGRAM_RE.search(text):
        methods.append("telegram")
    if _WHATSAPP_RE.search(text):
        methods.append("whatsapp")
    if _CALL_RE.search(text) or (phone and not methods):
        methods.append("phone")
    return tuple(dict.fromkeys(methods))


def _extract_time(text: str) -> str | None:
    match = _TIME_RE.search(text)
    if not match:
        return None
    hour = int(match.group(1))
    minute = int(match.group(2) or 0)
    if hour > 23 or minute > 59:
        return None
    return f"{hour:02d}:{minute:02d}"


def _extract_date(text: str, message_date: datetime) -> tuple[str | None, str]:
    lowered = text.lower()
    today = message_date.date()
    fuzzy_today_tomorrow = re.search(
        r"(?:имруз|сегодня|бугун)\s*(?:ё|е|или|/|-)\s*"
        r"(?:пагох|пагоҳ|завтра|эртага)",
        lowered,
    )
    if fuzzy_today_tomorrow:
        return today.isoformat(), "fuzzy"
    if re.search(r"\b(?:пагох|пагоҳ|завтра|эртага)\b", lowered):
        return (today + timedelta(days=1)).isoformat(), "exact"
    if re.search(r"\b(?:имруз|сегодня|бугун)\b", lowered):
        return today.isoformat(), "exact"
    return None, "unknown"


def classify_message(text: str, message_date: datetime) -> ParsedMessage:
    cleaned = " ".join(text.split())
    cities = _find_cities(cleaned)
    cargo = bool(_CARGO_RE.search(cleaned))
    offer_cue = bool(_OFFER_RE.search(cleaned))
    request_cue = bool(_REQUEST_RE.search(cleaned))
    phone = _extract_phone(cleaned)
    price, currency = _extract_price(cleaned)
    contact_methods = _extract_contact_methods(cleaned, phone)
    seats_match = _SEATS_RE.search(cleaned)
    seats = int(seats_match.group(1)) if seats_match else None

    has_route = len(cities) >= 2
    has_partial_ride = len(cities) == 1 and (cargo or offer_cue or request_cue)
    if not (has_route or has_partial_ride or offer_cue or request_cue):
        return ParsedMessage(
            kind="not_a_ride",
            cargo=cargo,
            from_city=None,
            to_city=None,
            depart_date=None,
            depart_time=None,
            date_precision="unknown",
            seats=None,
            phone=phone,
            confidence=0.95 if phone or len(cleaned) < 30 else 0.82,
            price=price,
            currency=currency,
            contact_methods=contact_methods,
        )

    if offer_cue:
        kind = "offer"
    elif request_cue or cargo:
        kind = "request"
    else:
        kind = "request"

    from_city: str | None = None
    to_city: str | None = None
    if len(cities) >= 2:
        from_city, to_city = cities[0], cities[1]
    elif cities:
        city = cities[0]
        lowered = cleaned.lower()
        if offer_cue and re.search(r"(?:из|аз(?:\s+самти)?|from)\s+", lowered):
            from_city = city
        elif request_cue or cargo:
            to_city = city
        else:
            from_city = city

    depart_date, date_precision = _extract_date(cleaned, message_date)
    depart_time = _extract_time(cleaned)

    confidence = 0.46
    if offer_cue or request_cue:
        confidence += 0.18
    if has_route:
        confidence += 0.20
    elif has_partial_ride:
        confidence += 0.10
    if phone:
        confidence += 0.07
    if seats is not None:
        confidence += 0.05
    if depart_date:
        confidence += 0.04

    return ParsedMessage(
        kind=kind,
        cargo=cargo,
        from_city=from_city,
        to_city=to_city,
        depart_date=depart_date,
        depart_time=depart_time,
        date_precision=date_precision,
        seats=seats,
        phone=phone,
        confidence=round(min(confidence, 0.99), 2),
        price=price,
        currency=currency,
        contact_methods=contact_methods,
    )
