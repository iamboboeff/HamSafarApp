import 'package:hamsafar/core/i18n/l10n.dart';

import '../domain/date_formatter.dart';
import 'residence_country.dart';
import 'user_profile.dart';

enum RidePointKind { meeting, destination }

/// Ported from `RidePoint` in `Models.swift` (the map-coordinate helpers are
/// trimmed down — the Flutter port does not render a map yet).
class RidePoint {
  const RidePoint({
    required this.title,
    required this.subtitle,
    this.addressLine,
  });

  final String title;
  final String subtitle;
  final String? addressLine;

  factory RidePoint.meeting(String city) =>
      RidePoint(title: tr('Точка встречи'), subtitle: city);

  factory RidePoint.destination(String city) =>
      RidePoint(title: tr('Точка прибытия'), subtitle: city);

  factory RidePoint.custom(String city, String label) =>
      RidePoint(title: label, subtitle: city, addressLine: label);

  /// Ported from `RidePoint.popularPlaces` / `popularPlaceTitles` in
  /// `Models.swift` — well-known meeting/arrival spots per city.
  static List<RidePoint> popularPlaces(String city, RidePointKind kind) {
    // Real, well-known gathering / pickup spots per city — transport hubs,
    // central bazaars, main squares and landmarks (web-verified). The same set
    // works for both the pickup ("Откуда") and drop-off ("Куда") pickers. Small
    // district centers fall back to their genuinely-existing market / stand /
    // square. The `kind` argument is accepted for API compatibility but the
    // gathering points are the same regardless of travel direction.
    final titles = _cityPlaces[city] ??
        const ['Центральный рынок', 'Автовокзал', 'Главная площадь'];
    return [
      for (final title in titles)
        RidePoint(title: title, subtitle: city, addressLine: title),
    ];
  }

  static const Map<String, List<String>> _cityPlaces = {
    // Tajikistan
    'Душанбе': ['Автовокзал', 'Зелёный базар', 'Площадь Дусти'],
    'Худжанд': ['Базар Панчшанбе', 'Автовокзал', 'Парк Камоли Худжанди'],
    'Куляб': ['Центральный рынок', 'Мавзолей Хамадони', 'Аэропорт Куляб'],
    'Бохтар': ['Центральный базар', 'Парк Лохути', 'Автовокзал'],
    'Истаравшан': ['Центральный базар', 'Мечеть Кок-Гумбаз', 'Крепость Мугтеппа'],
    'Пенджикент': ['Центральный базар', 'Музей Рудаки', 'Древний Пенджикент'],
    'Турсунзаде': ['Центральный рынок', 'Завод ТАлКо', 'Городской музей'],
    'Канибадам': ['Центральный базар', 'Медресе Ойим', 'Медресе Мир Раджаб Додхо'],
    'Исфара': ['Автовокзал', 'Центральный базар', 'Парк Исмаила Самани'],
    'Айни': ['Автостанция', 'Центральный базар', 'Минарет Варзи Манор'],
    'Ашт': ['Центральный базар', 'Автостанция', 'Центральная площадь'],
    'Матча': ['Центральный базар', 'Автостанция', 'Центральная площадь'],
    'Спитамен': ['ЖД вокзал', 'Центральный базар', 'Центральная площадь'],
    'Бободжон Гафуров': ['ЖД вокзал', 'Базар Фаравон', 'Музей Гафурова'],
    'Вахдат': ['Янги Бозор', 'Автовокзал', 'Памятник матери'],
    'Гиссар': ['Гиссарская крепость', 'Центральный рынок', 'Автовокзал'],
    'Нурек': ['Автовокзал', 'Центральный рынок', 'Нурекская ГЭС'],
    'Рогун': ['Автовокзал', 'Центральный рынок', 'Рогунская ГЭС'],
    'Дангара': ['Центральный рынок', 'ЖД вокзал', 'Площадь Сомони'],
    'Фархор': ['Центральный рынок', 'Автовокзал', 'Центральная площадь'],
    'Яван': ['Автовокзал', 'Центральный рынок', 'ЖД вокзал'],
    'Хамадони': ['Центральный рынок', 'Автовокзал', 'Центральная площадь'],
    'Левакант': ['Автовокзал', 'Центральный рынок', 'Центральная площадь'],
    'Шахринав': ['Центральный рынок', 'Автостанция', 'Шахринавское городище'],
    'Рудаки': ['Центральный рынок', 'Автостанция', 'Центральная площадь'],
    'Кушониён': ['Центральный рынок', 'Автостанция', 'Центральная площадь'],
    'Кубодиён': ['Центральный рынок', 'ЖД вокзал', 'Центральная площадь'],
    'Джайхун': ['Центральный рынок', 'Автостанция', 'Центральная площадь'],
    'Муминабад': ['Центральный рынок', 'Автостанция', 'Центральная площадь'],
    'Темурмалик': ['Центральный рынок', 'Автостанция', 'Центральная площадь'],
    'Восе': ['Центральный рынок', 'Автовокзал', 'Центральная площадь'],
    'Хорог': ['Центральный рынок', 'Парк Шипанг', 'Памирский ботанический сад'],
    // Uzbekistan
    'Ташкент': ['Базар Чорсу', 'Автовокзал Ташкент', 'Бекат Куйлюк'],
    'Самарканд': ['Сиабский базар', 'Регистан', 'Автовокзал'],
    'Бухара': ['Колхозный рынок', 'Ляби-Хауз', 'Центральный автовокзал'],
    'Хива': ['Ичан-Кала', 'Дехкан базар', 'ЖД вокзал'],
    'Андижан': ['Автовокзал', 'Старый рынок (Эски бозор)', 'Парк Бабура'],
    'Наманган': ['Автовокзал', 'Базар Чорсу', 'Парк Бабура'],
    'Фергана': ['Центральный рынок', 'Автовокзал', 'Центральный парк'],
    'Коканд': ['Дворец Худояр-хана', 'Базар Янги Чорсу', 'Автовокзал'],
    'Нукус': ['Автовокзал', 'Центральный рынок', 'Музей Савицкого'],
    'Термез': ['ЖД вокзал', 'Дехканский рынок', 'Археологический музей'],
    'Карши': ['ЖД вокзал', 'Старый рынок (Эски бозор)', 'Площадь Мустакиллик'],
    'Джизак': ['Автовокзал', 'Центральный рынок', 'Парк Истиклол'],
    'Навои': ['ЖД вокзал', 'Янги базар', 'Дворец культуры Фархад'],
    'Гулистан': ['ЖД вокзал', 'Базар Чорсу', 'Центральная площадь'],
    'Ургенч': ['ЖД вокзал', 'Центральный рынок', 'Мемориал Джалолиддина'],
    'Маргилан': ['ЖД вокзал', 'Базар Кумтепа', 'Фабрика Ёдгорлик'],
    'Шахрисабз': ['Ак-Сарай', 'Базар Чорсу', 'Автовокзал'],
    'Денау': ['Базар Бободехкон', 'ЖД вокзал', 'Медресе Саид Аталык'],
    'Зарафшан': ['Центральный базар', 'Автовокзал', 'Центральная площадь'],
    'Кунград': ['ЖД вокзал', 'Центральный базар', 'Центральная площадь'],
  };

  @override
  bool operator ==(Object other) =>
      other is RidePoint &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.addressLine == addressLine;

  @override
  int get hashCode => Object.hash(title, subtitle, addressLine);
}

/// Ported from `RideReview` in `Models.swift`.
class RideReview {
  const RideReview({
    required this.id,
    this.backendId,
    required this.author,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  final String id;
  final String? backendId;
  final String author;
  final double rating;
  final String comment;
  final DateTime? createdAt;
}

/// Result of parsing the `[hsride:...]` metadata prefix embedded in `notes`.
class _RideMetadata {
  const _RideMetadata({
    required this.instantBookingEnabled,
    required this.maxTwoPassengersInBackEnabled,
    required this.displayNotes,
  });

  final bool instantBookingEnabled;
  final bool maxTwoPassengersInBackEnabled;
  final String displayNotes;

  static const _prefix = '[hsride:';

  static _RideMetadata parse(String rawNotes) {
    final trimmed = rawNotes.trim();
    final closing = trimmed.indexOf(']');
    if (!trimmed.startsWith(_prefix) || closing == -1) {
      return _RideMetadata(
        instantBookingEnabled: false,
        maxTwoPassengersInBackEnabled: false,
        displayNotes: trimmed,
      );
    }
    final metadataString = trimmed.substring(_prefix.length, closing);
    final body = trimmed.substring(closing + 1).trim();
    final values = <String, String>{};
    for (final part in metadataString.split(';')) {
      final pieces = part.split('=');
      if (pieces.length == 2) values[pieces[0]] = pieces[1];
    }
    return _RideMetadata(
      instantBookingEnabled: values['instant'] == '1',
      maxTwoPassengersInBackEnabled: values['back2'] == '1',
      displayNotes: body,
    );
  }
}

/// Ported from `Ride` in `Models.swift`.
class Ride {
  const Ride({
    required this.id,
    this.backendId,
    required this.fromCity,
    required this.toCity,
    required this.meetingPoint,
    required this.destinationPoint,
    required this.departureDate,
    required this.pricePerSeat,
    required this.seatsLeft,
    required this.carModel,
    this.carColor = '',
    this.carPlate = '',
    this.durationSeconds,
    this.routeSummary = '',
    this.notes = '',
    required this.driver,
    this.reviews = const [],
    this.availableSeatLabels = const [],
    this.pricingCountry = ResidenceCountry.tajikistan,
  });

  final String id;
  final String? backendId;
  final String fromCity;
  final String toCity;
  final RidePoint meetingPoint;
  final RidePoint destinationPoint;
  final DateTime departureDate;
  final int pricePerSeat;
  final int seatsLeft;
  final String carModel;
  final String carColor;
  final String carPlate;

  /// Driving time in seconds for this city pair, from the `route_durations`
  /// cache (null when not computed — see [travelDuration] for the fallback).
  final int? durationSeconds;
  final String routeSummary;
  final String notes;
  final UserProfile driver;
  final List<RideReview> reviews;
  final List<String> availableSeatLabels;
  final ResidenceCountry pricingCountry;

  /// Builds the `notes` string with the metadata prefix — mirrors
  /// `Ride.encodedNotes`.
  static String encodedNotes(
    String notes, {
    required bool instantBookingEnabled,
    required bool maxTwoPassengersInBackEnabled,
  }) {
    final trimmed = notes.trim();
    final metadata =
        '[hsride:instant=${instantBookingEnabled ? 1 : 0};back2=${maxTwoPassengersInBackEnabled ? 1 : 0}]';
    return trimmed.isEmpty ? metadata : '$metadata\n$trimmed';
  }

  _RideMetadata get _metadata => _RideMetadata.parse(notes);

  String get displayNotes => _metadata.displayNotes;
  bool get instantBookingEnabled => _metadata.instantBookingEnabled;
  bool get maxTwoPassengersInBackEnabled =>
      _metadata.maxTwoPassengersInBackEnabled;

  String formattedPrice() => pricingCountry.formatAmount(pricePerSeat);

  String get priceText => formattedPrice();

  List<String> get effectiveAvailableSeatLabels => availableSeatLabels.isEmpty
      ? SeatLayout.seatLabels(seatsLeft < 1 ? 1 : seatsLeft)
      : availableSeatLabels;

  int get availableSeatsCount => availableSeatLabels.isEmpty
      ? (seatsLeft < 0 ? 0 : seatsLeft)
      : effectiveAvailableSeatLabels.length;

  String get departureTimeText => DateTextFormatter.dayMonthTime(departureDate);

  /// Real driving time from the `route_durations` cache (OpenRouteService),
  /// when available for this city pair; otherwise a coarse hard-coded estimate
  /// for legacy / not-yet-computed routes.
  Duration get travelDuration {
    final secs = durationSeconds;
    if (secs != null && secs > 0) return Duration(seconds: secs);
    return _fallbackTravelDuration;
  }

  String get travelTimeText {
    final d = travelDuration;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0 && m > 0) {
      return trf('{h} ч {m} мин', {'h': '$h', 'm': '$m'});
    }
    if (h > 0) return trf('{h} ч', {'h': '$h'});
    return trf('{m} мин', {'m': '$m'});
  }

  Duration get _fallbackTravelDuration {
    final from = fromCity.toLowerCase();
    final to = toCity.toLowerCase();
    bool route(String a, String b) =>
        (from == a && to == b) || (from == b && to == a);
    if (route('ташкент', 'самарканд')) {
      return const Duration(hours: 4, minutes: 30);
    }
    if (route('ташкент', 'бухара')) return const Duration(hours: 7, minutes: 15);
    if (route('ташкент', 'хива')) return const Duration(hours: 12, minutes: 40);
    if (route('душанбе', 'худжанд')) return const Duration(hours: 5, minutes: 20);
    return const Duration(hours: 3, minutes: 45);
  }

  DateTime get estimatedArrivalDate => departureDate.add(travelDuration);

  bool get hasStarted => !DateTime.now().isBefore(departureDate);
  bool get hasFinished => !DateTime.now().isBefore(estimatedArrivalDate);
  bool get isInProgress => hasStarted && !hasFinished;
}

/// Ported from `SeatLayout` in `Models.swift`.
abstract final class SeatLayout {
  static final List<String> allSeatLabels = List.generate(
    10,
    (i) => '${i + 1}',
  );

  static List<String> seatLabels(int capacity) {
    final count = capacity.clamp(0, allSeatLabels.length);
    return allSeatLabels.take(count).toList();
  }
}
