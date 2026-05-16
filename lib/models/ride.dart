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
      RidePoint(title: 'Точка встречи', subtitle: city);

  factory RidePoint.destination(String city) =>
      RidePoint(title: 'Точка прибытия', subtitle: city);

  factory RidePoint.custom(String city, String label) =>
      RidePoint(title: label, subtitle: city, addressLine: label);

  /// Ported from `RidePoint.popularPlaces` / `popularPlaceTitles` in
  /// `Models.swift` — well-known meeting/arrival spots per city.
  static List<RidePoint> popularPlaces(String city, RidePointKind kind) {
    const departureCandidates = <String, List<String>>{
      'Ташкент': ['Северный вокзал', 'ТЦ Mega Planet', 'Метро Буюк Ипак Йули'],
      'Самарканд': [
        'Регистан, главный вход',
        'Самарканд City',
        'Железнодорожный вокзал',
      ],
      'Бухара': ['Ляби-Хауз', 'Бухара Молл', 'ЖД вокзал Каган'],
      'Хива': [
        'Ичан-Кала, восточные ворота',
        'Автовокзал Хива',
        'Центральный рынок',
      ],
      'Душанбе': ['ТЦ Сиёма Молл', 'Южный автовокзал', 'Оперный театр'],
      'Худжанд': ['ТЦ Атуш', 'Парк Камоли Худжанди', 'Автовокзал Худжанд'],
    };
    const arrivalCandidates = <String, List<String>>{
      'Ташкент': ['Magic City', 'Северный вокзал', 'ТЦ Compass'],
      'Самарканд': ['Сиабский рынок', 'Регистан', 'ЖД вокзал Самарканд'],
      'Бухара': ['Ляби-Хауз', 'Старый город', 'Автовокзал Бухара'],
      'Хива': [
        'Ичан-Кала, западные ворота',
        'Центральный рынок',
        'Автостанция Хива',
      ],
      'Душанбе': ['Площадь Дусти', 'Сиёма Молл', 'Южный автовокзал'],
      'Худжанд': ['Парк Камоли Худжанди', 'Центральный рынок', 'ТЦ Атуш'],
    };
    final titles = switch (kind) {
      RidePointKind.meeting =>
        departureCandidates[city] ??
            const [
              'Центральный вокзал',
              'Центральный рынок',
              'Главная площадь',
            ],
      RidePointKind.destination =>
        arrivalCandidates[city] ??
            const ['Главная площадь', 'Центральный рынок', 'Автовокзал'],
    };
    return [
      for (final title in titles)
        RidePoint(title: title, subtitle: city, addressLine: title),
    ];
  }

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

  /// Mirrors the hard-coded route durations in the Swift `travelTimeText`.
  String get travelTimeText {
    final from = fromCity.toLowerCase();
    final to = toCity.toLowerCase();
    bool route(String a, String b) =>
        (from == a && to == b) || (from == b && to == a);
    if (route('ташкент', 'самарканд')) return '4 ч 30 мин';
    if (route('ташкент', 'бухара')) return '7 ч 15 мин';
    if (route('ташкент', 'хива')) return '12 ч 40 мин';
    if (route('душанбе', 'худжанд')) return '5 ч 20 мин';
    return '3 ч 45 мин';
  }

  Duration get travelDuration {
    final hours = RegExp(r'(\d+)\s*ч').firstMatch(travelTimeText);
    final minutes = RegExp(r'(\d+)\s*мин').firstMatch(travelTimeText);
    final h = hours == null ? 0 : int.parse(hours.group(1)!);
    final m = minutes == null ? 0 : int.parse(minutes.group(1)!);
    return Duration(hours: h, minutes: m);
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
