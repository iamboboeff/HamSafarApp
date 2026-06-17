import '../../models/car_profile.dart';
import '../../models/passenger_request.dart';
import '../../models/residence_country.dart';
import '../../models/ride.dart';
import '../../models/user_profile.dart';

/// Row DTOs ported from `SupabaseServiceRows.swift` — they parse the raw
/// Supabase JSON (column-name keyed) into typed objects and the app models.

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _parseInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

double _parseDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

/// Ported from `ProfileRow`.
class ProfileRow {
  ProfileRow(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;

  UserProfile toModel({double? overrideRating, int? overrideCompletedTrips}) {
    final genderRaw = json['gender'] as String?;
    final countryRaw = json['country_of_residence'] as String?;
    final birthRaw = json['birth_date'] as String?;
    return UserProfile(
      id: id,
      backendId: id,
      name: (json['full_name'] as String?) ?? 'Пользователь',
      rating: overrideRating ?? _parseDouble(json['rating'], 5),
      completedTrips:
          overrideCompletedTrips ?? _parseInt(json['completed_trips']),
      phoneNumber: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      avatarBytes: UserProfile.decodeAvatarUrl(json['avatar_url'] as String?),
      avatarUrl: UserProfile.avatarUrlFromColumn(json['avatar_url'] as String?),
      gender: ProfileGender.values
          .where((g) => g.name == genderRaw)
          .cast<ProfileGender?>()
          .firstWhere((_) => true, orElse: () => null),
      birthDate: birthRaw == null ? null : DateTime.tryParse(birthRaw),
      registeredAt: _parseDate(json['registered_at']),
      countryOfResidence: ResidenceCountry.values
          .where((c) => c.name == countryRaw)
          .cast<ResidenceCountry?>()
          .firstWhere((_) => true, orElse: () => null),
      allowPublicProfile: (json['allow_public_profile'] as bool?) ?? true,
    );
  }
}

/// Ported from `VehicleRow`.
class VehicleRow {
  VehicleRow(this.json);
  final Map<String, dynamic> json;

  String? get id => json['id'] as String?;
  String? get ownerId => json['owner_id'] as String?;
  String get model => (json['model'] as String?) ?? 'Автомобиль';
  String get color => (json['color'] as String?) ?? '';
  String get plateNumber => (json['plate_number'] as String?) ?? '';

  CarProfile toModel() {
    return CarProfile(
      model: model,
      color: color,
      plateNumber: plateNumber,
      seats: '${_parseInt(json['seats'], 4)}',
    );
  }
}

/// Ported from `RideRow` (the `rides_with_availability` view).
class RideRow {
  RideRow(this.json);
  final Map<String, dynamic> json;

  String? get id => json['id'] as String?;
  String get driverId => json['driver_id'] as String;
  String? get vehicleId => json['vehicle_id'] as String?;
  String get fromCity => (json['from_city'] as String?) ?? '';
  String get toCity => (json['to_city'] as String?) ?? '';
  String? get fromAddress => json['from_address'] as String?;
  String? get toAddress => json['to_address'] as String?;
  DateTime get departureAt =>
      _parseDate(json['departure_at']) ?? DateTime.now();
  int get pricePerSeat => _parseInt(json['price_per_seat']);
  int get seatsTotal => _parseInt(json['seats_total'], 4);
  int? get seatsLeft =>
      json['seats_left'] == null ? null : _parseInt(json['seats_left']);
  List<String>? get availableSeatLabels {
    final raw = json['available_seat_labels'];
    if (raw is List) return raw.map((e) => '$e').toList();
    return null;
  }

  String? get routeSummary => json['route_summary'] as String?;
  String? get notes => json['notes'] as String?;
  bool? get searchPassengersEnabled =>
      json['search_passengers_enabled'] as bool?;
  String get status => (json['status'] as String?) ?? 'active';
  String? get currency => json['currency'] as String?;
  int? get durationSeconds =>
      json['duration_seconds'] == null ? null : _parseInt(json['duration_seconds']);

  /// Ported from `SupabaseService.mapRide`.
  Ride toModel({
    required Map<String, UserProfile> profilesById,
    required Map<String, VehicleRow> vehiclesById,
    Map<String, List<RideReview>> reviewsByUserId = const {},
  }) {
    final driver = profilesById[driverId] ??
        UserProfile(
          id: driverId,
          backendId: driverId,
          name: 'Водитель',
          rating: 5,
          completedTrips: 0,
        );
    final vehicle = vehicleId == null ? null : vehiclesById[vehicleId];
    final carModel = vehicle?.model ?? 'Автомобиль';
    final labels = availableSeatLabels ?? SeatLayout.seatLabels(seatsTotal);
    return Ride(
      id: id ?? driverId,
      backendId: id,
      fromCity: fromCity,
      toCity: toCity,
      meetingPoint: RidePoint(
        title: 'Точка встречи',
        subtitle: fromCity,
        addressLine: fromAddress,
      ),
      destinationPoint: RidePoint(
        title: 'Точка прибытия',
        subtitle: toCity,
        addressLine: toAddress,
      ),
      departureDate: departureAt,
      pricePerSeat: pricePerSeat,
      seatsLeft: (seatsLeft ?? seatsTotal).clamp(0, 1 << 30),
      carModel: carModel,
      carColor: vehicle?.color ?? '',
      carPlate: vehicle?.plateNumber ?? '',
      durationSeconds: durationSeconds,
      routeSummary:
          routeSummary ?? 'Маршрут между $fromCity и $toCity',
      notes: notes ?? '',
      driver: driver,
      reviews: reviewsByUserId[driverId] ?? const [],
      availableSeatLabels: labels,
      // The ride carries its own currency (TJS/UZS) chosen at publish; only
      // fall back to the driver's residence for legacy rows without it.
      pricingCountry: currency == 'UZS'
          ? ResidenceCountry.uzbekistan
          : currency == 'TJS'
              ? ResidenceCountry.tajikistan
              : (driver.countryOfResidence ?? ResidenceCountry.tajikistan),
    );
  }
}

/// Ported from `PassengerRequestRow`.
class PassengerRequestRow {
  PassengerRequestRow(this.json);
  final Map<String, dynamic> json;

  String? get id => json['id'] as String?;
  String get passengerId => json['passenger_id'] as String;
  String get fromCity => (json['from_city'] as String?) ?? '';
  String get toCity => (json['to_city'] as String?) ?? '';
  DateTime get departureAt =>
      _parseDate(json['departure_at']) ?? DateTime.now();
  int get seatsNeeded => _parseInt(json['seats_needed'], 1);
  int get budget => _parseInt(json['budget']);
  String get note => (json['note'] as String?) ?? '';
  String get status => (json['status'] as String?) ?? 'active';

  PassengerRequest toModel(UserProfile passenger, {String? localizedStatus}) {
    return PassengerRequest(
      id: id ?? passengerId,
      backendId: id,
      passenger: passenger,
      fromCity: fromCity,
      toCity: toCity,
      departureDate: departureAt,
      seatsNeeded: seatsNeeded,
      budget: budget,
      note: note,
      status: localizedStatus ?? status,
      budgetCountry:
          passenger.countryOfResidence ?? ResidenceCountry.tajikistan,
    );
  }
}

/// Ported from `BookingRow`.
class BookingRow {
  BookingRow(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String get rideId => json['ride_id'] as String;
  String get passengerId => json['passenger_id'] as String;
  int get seatsCount => _parseInt(json['seats_count'], 1);
  String get status => (json['status'] as String?) ?? 'pending';
  String? get cancelReason => json['cancel_reason'] as String?;
  DateTime? get createdAt => _parseDate(json['created_at']);
}

/// Ported from `DBRideReviewRow`.
class RideReviewRow {
  RideReviewRow(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String? get rideId => json['ride_id'] as String?;
  String get reviewerId => json['reviewer_id'] as String;
  String get revieweeId => json['reviewee_id'] as String;
  double get rating => _parseDouble(json['rating'], 5);
  String get comment => (json['comment'] as String?) ?? '';
  DateTime? get createdAt => _parseDate(json['created_at']);

  RideReview toModel(String authorName) {
    return RideReview(
      id: id,
      backendId: id,
      author: authorName,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
    );
  }
}
