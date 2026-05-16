import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/activity_notification.dart';
import '../../models/booked_trip.dart';
import '../../models/car_profile.dart';
import '../../models/passenger_request.dart';
import '../../models/ride.dart';
import '../../models/ride_passenger_booking.dart';
import '../../models/trip_enums.dart';
import '../../models/user_profile.dart';
import 'supabase_config.dart';
import 'supabase_rows.dart';

/// App-level error with a user-facing (Russian) message.
class SupabaseServiceError implements Exception {
  SupabaseServiceError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Ported from `SupabaseSessionData` in `SupabaseServiceTypes.swift`.
class SupabaseSessionData {
  const SupabaseSessionData({
    required this.profile,
    required this.carProfile,
    required this.allowPublicProfile,
  });
  final UserProfile profile;
  final CarProfile? carProfile;
  final bool allowPublicProfile;
}

/// Payload for publishing a ride — ported from `RidePublishPayload`.
class RidePublishPayload {
  const RidePublishPayload({
    required this.fromCountry,
    required this.fromCity,
    required this.fromAddress,
    required this.toCountry,
    required this.toCity,
    required this.toAddress,
    required this.departureAt,
    required this.pricePerSeat,
    required this.seatsTotal,
    required this.availableSeatLabels,
    required this.notes,
    required this.routeSummary,
  });

  final String fromCountry;
  final String fromCity;
  final String? fromAddress;
  final String toCountry;
  final String toCity;
  final String? toAddress;
  final DateTime departureAt;
  final int pricePerSeat;
  final int seatsTotal;
  final List<String> availableSeatLabels;
  final String notes;
  final String routeSummary;
}

/// Payload for publishing a passenger request.
class PassengerRequestPublishPayload {
  const PassengerRequestPublishPayload({
    required this.fromCountry,
    required this.fromCity,
    required this.toCountry,
    required this.toCity,
    required this.departureAt,
    required this.seatsNeeded,
    required this.budget,
    required this.note,
  });

  final String fromCountry;
  final String fromCity;
  final String toCountry;
  final String toCity;
  final DateTime departureAt;
  final int seatsNeeded;
  final int budget;
  final String note;
}

/// Ported from `SupabaseService` (`SupabaseService.swift` + `...Account.swift`).
///
/// Covers auth/session and the marketplace + trips reads/writes. Chat,
/// notifications, push and support edge-functions are not ported yet.
class SupabaseService {
  SupabaseService(this._client);

  final SupabaseClient _client;

  static const _publishCooldown = Duration(seconds: 45);
  static const _duplicateDepartureTolerance = Duration(hours: 2);
  static const _maxActiveRidesPerDriver = 5;
  static const _maxActivePassengerRequestsPerUser = 3;
  static const _maxActiveBookingsPerPassenger = 3;

  User? get currentUser => _client.auth.currentUser;
  bool get hasSession => _client.auth.currentSession != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Auth (ported from SupabaseServiceAccount.swift)
  // ---------------------------------------------------------------------------

  Future<SupabaseSessionData?> restoreSession() async {
    final user = currentUser;
    if (user == null) return null;
    return _fetchSessionData(user);
  }

  Future<SupabaseSessionData> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (e) {
      throw SupabaseServiceError(_localizedAuthError(e.message, _AuthCtx.signIn));
    }
    final user = currentUser;
    if (user == null) {
      throw SupabaseServiceError('Не удалось войти. Попробуйте ещё раз.');
    }
    return _fetchSessionData(user);
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (e) {
      throw SupabaseServiceError(_localizedAuthError(e.message, _AuthCtx.register));
    }
  }

  Future<void> resendEmailSignupOtp(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
      );
    } on AuthException catch (e) {
      throw SupabaseServiceError(
        _localizedAuthError(e.message, _AuthCtx.resendCode),
      );
    }
  }

  Future<SupabaseSessionData> verifyEmailSignupOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.signup,
      );
    } on AuthException catch (e) {
      throw SupabaseServiceError(
        _localizedAuthError(e.message, _AuthCtx.verifyCode),
      );
    }
    final user = currentUser;
    if (user == null) {
      throw SupabaseServiceError(
        'Не удалось завершить регистрацию. Попробуйте снова.',
      );
    }
    return _fetchSessionData(user);
  }

  Future<void> signOut() => _client.auth.signOut();

  // ---------------------------------------------------------------------------
  // Session / profile (ported from SupabaseServiceAccount.swift)
  // ---------------------------------------------------------------------------

  Future<SupabaseSessionData> _fetchSessionData(User user) async {
    final profileRows = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .limit(1);
    final vehicleRows = await _client
        .from('vehicles')
        .select()
        .eq('owner_id', user.id)
        .limit(1);

    UserProfile profile;
    if (profileRows.isNotEmpty) {
      final enriched = await _enrichedProfilesById([
        ProfileRow(profileRows.first),
      ]);
      profile = enriched[user.id] ??
          _fallbackProfile(user);
    } else {
      profile = _fallbackProfile(user);
    }

    final car =
        vehicleRows.isEmpty ? null : VehicleRow(vehicleRows.first).toModel();
    final allowPublic = profileRows.isEmpty
        ? true
        : (profileRows.first['allow_public_profile'] as bool? ?? true);

    return SupabaseSessionData(
      profile: profile,
      carProfile: car,
      allowPublicProfile: allowPublic,
    );
  }

  UserProfile _fallbackProfile(User user) {
    return UserProfile(
      id: user.id,
      backendId: user.id,
      name: (user.userMetadata?['full_name'] as String?) ??
          user.email ??
          'Пользователь',
      rating: 5,
      completedTrips: 0,
      phoneNumber: user.phone ?? '',
      email: user.email ?? '',
    );
  }

  Future<SupabaseSessionData> saveProfile(UserProfile profile) async {
    final user = _requireUser();
    final existing = await _client
        .from('profiles')
        .select('allow_public_profile')
        .eq('id', user.id)
        .limit(1);
    final allowPublic = existing.isEmpty
        ? true
        : (existing.first['allow_public_profile'] as bool? ?? true);

    await _client.from('profiles').upsert({
      'id': user.id,
      'full_name': profile.name,
      'phone': profile.phoneNumber,
      'email': profile.email,
      'avatar_url': UserProfile.encodeAvatarBytes(profile.avatarBytes),
      'rating': profile.rating,
      'completed_trips': profile.completedTrips,
      'gender': profile.gender?.name,
      'birth_date': profile.birthDate == null
          ? null
          : _dateOnly(profile.birthDate!),
      'registered_at':
          (profile.registeredAt ?? DateTime.now()).toUtc().toIso8601String(),
      'country_of_residence': profile.countryOfResidence?.name,
      'allow_public_profile': allowPublic,
    }, onConflict: 'id');

    return _fetchSessionData(user);
  }

  Future<void> savePrivacySettings({required bool allowPublicProfile}) async {
    final user = _requireUser();
    await _client
        .from('profiles')
        .update({'allow_public_profile': allowPublicProfile})
        .eq('id', user.id);
  }

  Future<CarProfile> saveVehicle(CarProfile car) async {
    final user = _requireUser();
    final saved = await _client
        .from('vehicles')
        .upsert({
          'owner_id': user.id,
          'model': car.model,
          'color': car.color,
          'plate_number': car.plateNumber,
          'seats': (int.tryParse(car.seats) ?? 4).clamp(1, 4),
        }, onConflict: 'owner_id')
        .select()
        .single();
    return VehicleRow(saved).toModel();
  }

  Future<String?> _ensureVehicleExists(CarProfile car) async {
    final user = _requireUser();
    final saved = await _client
        .from('vehicles')
        .upsert({
          'owner_id': user.id,
          'model': car.model,
          'color': car.color,
          'plate_number': car.plateNumber,
          'seats': (int.tryParse(car.seats) ?? 4).clamp(1, 4),
        }, onConflict: 'owner_id')
        .select()
        .single();
    return saved['id'] as String?;
  }

  // ---------------------------------------------------------------------------
  // Marketplace reads (ported from SupabaseService.swift)
  // ---------------------------------------------------------------------------

  Future<List<ProfileRow>> _fetchAllProfiles() async {
    final rows = await _client.from('profiles').select();
    return rows.map(ProfileRow.new).toList();
  }

  Future<Map<String, VehicleRow>> _fetchVehiclesById() async {
    final rows = await _client.from('vehicles').select();
    final map = <String, VehicleRow>{};
    for (final raw in rows) {
      final row = VehicleRow(raw);
      final id = row.id;
      if (id != null) map[id] = row;
    }
    return map;
  }

  Future<List<BookingRow>> _fetchAllBookings() async {
    final rows = await _client.from('bookings').select();
    return rows.map(BookingRow.new).toList();
  }

  /// `{revieweeId: (avgRating, count)}` — ported from `fetchReviewAggregates`.
  Future<Map<String, ({double rating, int count})>> _fetchReviewAggregates(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('ride_reviews')
        .select('reviewee_id, rating')
        .inFilter('reviewee_id', userIds);
    final grouped = <String, List<double>>{};
    for (final raw in rows) {
      final id = raw['reviewee_id'] as String;
      final rating = (raw['rating'] as num?)?.toDouble() ?? 5;
      grouped.putIfAbsent(id, () => []).add(rating);
    }
    return grouped.map((id, ratings) {
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      return MapEntry(id, (rating: avg, count: ratings.length));
    });
  }

  /// Ported from `enrichedProfilesByID` — overlays the review aggregate
  /// (average rating + count) on top of the base profile.
  Future<Map<String, UserProfile>> _enrichedProfilesById(
    List<ProfileRow> rows,
  ) async {
    final base = {for (final r in rows) r.id: r.toModel()};
    final aggregates = await _fetchReviewAggregates(base.keys.toList());
    for (final entry in aggregates.entries) {
      final profile = base[entry.key];
      if (profile == null) continue;
      base[entry.key] = _withRatings(
        profile,
        rating: entry.value.rating,
        completedTrips: profile.completedTrips > entry.value.count
            ? profile.completedTrips
            : entry.value.count,
      );
    }
    return base;
  }

  UserProfile _withRatings(
    UserProfile p, {
    required double rating,
    required int completedTrips,
  }) {
    return UserProfile(
      id: p.id,
      backendId: p.backendId,
      name: p.name,
      rating: rating,
      completedTrips: completedTrips,
      phoneNumber: p.phoneNumber,
      email: p.email,
      gender: p.gender,
      birthDate: p.birthDate,
      registeredAt: p.registeredAt,
      countryOfResidence: p.countryOfResidence,
      allowPublicProfile: p.allowPublicProfile,
    );
  }

  /// Ported from `occupiedSeatsCountByRideID`.
  Map<String, int> _occupiedSeatsByRideId(List<BookingRow> bookings) {
    final map = <String, int>{};
    for (final b in bookings) {
      if (b.status == 'cancelled') continue;
      map[b.rideId] = (map[b.rideId] ?? 0) + b.seatsCount;
    }
    return map;
  }

  /// Ported from `rideWithUpdatedAvailability`.
  Ride _rideWithAvailability(Ride ride, int occupiedSeats) {
    final labels = ride.effectiveAvailableSeatLabels;
    final drop = occupiedSeats.clamp(0, labels.length);
    final remaining = labels.sublist(drop);
    return Ride(
      id: ride.id,
      backendId: ride.backendId,
      fromCity: ride.fromCity,
      toCity: ride.toCity,
      meetingPoint: ride.meetingPoint,
      destinationPoint: ride.destinationPoint,
      departureDate: ride.departureDate,
      pricePerSeat: ride.pricePerSeat,
      seatsLeft: remaining.length,
      carModel: ride.carModel,
      routeSummary: ride.routeSummary,
      notes: ride.notes,
      driver: ride.driver,
      reviews: ride.reviews,
      availableSeatLabels: remaining,
      pricingCountry: ride.pricingCountry,
    );
  }

  Future<Map<String, List<RideReview>>> _reviewsByReviewee(
    List<String> userIds,
    Map<String, UserProfile> profilesById,
  ) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('ride_reviews')
        .select()
        .inFilter('reviewee_id', userIds)
        .order('created_at', ascending: false);
    final result = <String, List<RideReview>>{};
    for (final raw in rows) {
      final row = RideReviewRow(raw);
      final author = profilesById[row.reviewerId]?.name ?? 'Пассажир';
      result.putIfAbsent(row.revieweeId, () => []).add(row.toModel(author));
    }
    return result;
  }

  /// Ported from `fetchRides`.
  Future<List<Ride>> fetchRides() async {
    final rideRowsRaw = await _client.from('rides_with_availability').select();
    final rideRows = rideRowsRaw.map(RideRow.new).toList();

    final profilesById =
        await _enrichedProfilesById(await _fetchAllProfiles());
    final vehiclesById = await _fetchVehiclesById();
    final bookings = await _fetchAllBookings();
    final occupied = _occupiedSeatsByRideId(bookings);
    final reviews = await _reviewsByReviewee(
      rideRows.map((r) => r.driverId).toSet().toList(),
      profilesById,
    );

    final active = rideRows.where((r) => r.status == 'active').toList()
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    return active
        .map((row) {
          final ride = row.toModel(
            profilesById: profilesById,
            vehiclesById: vehiclesById,
            reviewsByUserId: reviews,
          );
          return _rideWithAvailability(ride, occupied[row.id] ?? 0);
        })
        .where((ride) => !ride.hasFinished)
        .toList();
  }

  /// Ported from `fetchPassengerRequests`.
  Future<List<PassengerRequest>> fetchPassengerRequests() async {
    final rowsRaw = await _client.from('passenger_requests').select();
    final rows = rowsRaw.map(PassengerRequestRow.new).toList();
    final profilesById =
        await _enrichedProfilesById(await _fetchAllProfiles());

    final active = rows.where((r) => r.status == 'active').toList()
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    return active
        .map((row) {
          final passenger = profilesById[row.passengerId] ??
              UserProfile(
                id: row.passengerId,
                backendId: row.passengerId,
                name: 'Пассажир',
                rating: 5,
                completedTrips: 0,
              );
          return row.toModel(passenger, localizedStatus: 'Активно');
        })
        .where((r) => !r.isCompleted)
        .toList();
  }

  /// Ported from `fetchBookedTrips`.
  Future<List<BookedTrip>> fetchBookedTrips() async {
    final user = _requireUser();
    final rideRowsRaw = await _client.from('rides_with_availability').select();
    final rideRows = rideRowsRaw.map(RideRow.new).toList();
    final ridesById = {
      for (final r in rideRows)
        if (r.id != null) r.id!: r,
    };

    final profilesById =
        await _enrichedProfilesById(await _fetchAllProfiles());
    final vehiclesById = await _fetchVehiclesById();
    final bookings = await _fetchAllBookings();
    final occupied = _occupiedSeatsByRideId(bookings);

    final searchPrefsRaw = await _client
        .from('rides')
        .select('id, search_passengers_enabled')
        .eq('driver_id', user.id);
    final searchPrefs = {
      for (final raw in searchPrefsRaw)
        raw['id'] as String:
            (raw['search_passengers_enabled'] as bool?) ?? true,
    };

    final driverTrips = rideRows.where((r) => r.driverId == user.id).map((row) {
      final base = row.toModel(
        profilesById: profilesById,
        vehiclesById: vehiclesById,
      );
      final ride = _rideWithAvailability(base, occupied[row.id] ?? 0);
      final occupiedSeats =
          (base.effectiveAvailableSeatLabels.length - ride.availableSeatsCount)
              .clamp(0, 1 << 30);
      final related = bookings
          .where((b) => b.rideId == row.id && b.status != 'cancelled')
          .toList();
      final confirmed = related.where((b) => b.status == 'confirmed').length;
      final pending = related.where((b) => b.status == 'pending').length;
      final status = _localizedRideStatus(row.status, row.departureAt);
      final archived = row.status != 'active' ||
          status.toLowerCase().contains('заверш') ||
          ride.hasFinished;
      return BookedTrip(
        id: row.id ?? user.id,
        backendId: row.id,
        ride: ride,
        seatsBooked: occupiedSeats,
        status: status,
        category:
            row.status == 'active' ? TripCategory.active : TripCategory.history,
        role: TripRole.driver,
        searchPassengersEnabled:
            archived ? false : (searchPrefs[row.id] ?? row.searchPassengersEnabled ?? true),
        confirmedPassengerCount: confirmed,
        pendingPassengerCount: archived ? 0 : pending,
      );
    });

    final passengerTrips = bookings
        .where((b) => b.passengerId == user.id)
        .map((booking) {
          final rideRow = ridesById[booking.rideId];
          if (rideRow == null) return null;
          final base = rideRow.toModel(
            profilesById: profilesById,
            vehiclesById: vehiclesById,
          );
          final ride =
              _rideWithAvailability(base, occupied[booking.rideId] ?? 0);
          return BookedTrip(
            id: booking.id,
            backendId: booking.id,
            ride: ride,
            seatsBooked: booking.seatsCount,
            status: _localizedBookingStatus(booking.status),
            category: booking.status == 'cancelled' ||
                    booking.status == 'completed'
                ? TripCategory.history
                : TripCategory.active,
            role: TripRole.passenger,
            confirmedPassengerCount: booking.status == 'confirmed' ? 1 : 0,
            pendingPassengerCount: booking.status == 'pending' ? 1 : 0,
          );
        })
        .whereType<BookedTrip>();

    return [...driverTrips, ...passengerTrips]
      ..sort((a, b) => b.ride.departureDate.compareTo(a.ride.departureDate));
  }

  /// Ported from `fetchMyPassengerRequests`.
  Future<List<PassengerRequest>> fetchMyPassengerRequests() async {
    final user = _requireUser();
    final rowsRaw = await _client
        .from('passenger_requests')
        .select()
        .eq('passenger_id', user.id)
        .order('departure_at', ascending: false);
    final rows = rowsRaw.map(PassengerRequestRow.new).toList();
    final session = await _fetchSessionData(user);
    return rows
        .map((row) => row.toModel(
              session.profile,
              localizedStatus:
                  _localizedPassengerRequestStatus(row.status),
            ))
        .toList();
  }

  Future<List<RidePassengerBooking>> fetchRidePassengerBookings(
    String rideId,
  ) async {
    final rowsRaw = await _client
        .from('bookings')
        .select()
        .eq('ride_id', rideId)
        .order('created_at', ascending: false);
    final rows = rowsRaw
        .map(BookingRow.new)
        .where((b) => b.status != 'cancelled')
        .toList();
    if (rows.isEmpty) return [];

    final passengerIds = rows.map((b) => b.passengerId).toSet().toList();
    final profileRows = await _client
        .from('profiles')
        .select()
        .inFilter('id', passengerIds);
    final profilesById = await _enrichedProfilesById(
      profileRows.map(ProfileRow.new).toList(),
    );

    return rows.map((row) {
      final passenger = profilesById[row.passengerId] ??
          UserProfile(
            id: row.passengerId,
            backendId: row.passengerId,
            name: 'Пассажир',
            rating: 5,
            completedTrips: 0,
          );
      return RidePassengerBooking(
        id: row.id,
        backendId: row.id,
        passenger: passenger,
        seatsCount: row.seatsCount,
        status: _localizedBookingStatus(row.status),
        createdAt: row.createdAt,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Marketplace writes (ported from SupabaseService.swift)
  // ---------------------------------------------------------------------------

  Future<Ride> publishRide({
    required RidePublishPayload payload,
    required UserProfile driver,
    required CarProfile carProfile,
  }) async {
    final user = _requireUser();
    await _validatePublication(
      table: 'rides',
      ownerColumn: 'driver_id',
      ownerId: user.id,
      payloadFromCity: payload.fromCity,
      payloadToCity: payload.toCity,
      payloadDepartureAt: payload.departureAt,
      maxActive: _maxActiveRidesPerDriver,
      duplicateMessage:
          'Похожая поездка уже опубликована. Не создавайте дубликат маршрута.',
      activeLimitMessage:
          'Можно держать не больше 5 активных поездок одновременно.',
      cooldownMessage: (s) =>
          'Подождите $s сек. перед следующей публикацией поездки.',
    );
    final vehicleId = await _ensureVehicleExists(carProfile);

    final inserted = await _client
        .from('rides')
        .insert({
          'driver_id': user.id,
          'vehicle_id': vehicleId,
          'from_country': payload.fromCountry,
          'from_city': payload.fromCity,
          'from_address': payload.fromAddress,
          'to_country': payload.toCountry,
          'to_city': payload.toCity,
          'to_address': payload.toAddress,
          'departure_at': payload.departureAt.toUtc().toIso8601String(),
          'price_per_seat': payload.pricePerSeat,
          'seats_total': payload.seatsTotal,
          'available_seat_labels': payload.availableSeatLabels,
          'notes': payload.notes,
          'route_summary': payload.routeSummary,
          'search_passengers_enabled': true,
          'status': 'active',
        })
        .select()
        .single();

    final row = RideRow(inserted);
    return row.toModel(
      profilesById: {driver.backendId ?? driver.id: driver},
      vehiclesById: {
        ?vehicleId: VehicleRow({'id': vehicleId, 'model': carProfile.model}),
      },
    );
  }

  Future<PassengerRequest> publishPassengerRequest({
    required PassengerRequestPublishPayload payload,
    required UserProfile passenger,
  }) async {
    final user = _requireUser();
    await _validatePublication(
      table: 'passenger_requests',
      ownerColumn: 'passenger_id',
      ownerId: user.id,
      payloadFromCity: payload.fromCity,
      payloadToCity: payload.toCity,
      payloadDepartureAt: payload.departureAt,
      maxActive: _maxActivePassengerRequestsPerUser,
      duplicateMessage:
          'Похожий запрос уже опубликован. Не создавайте дубликат маршрута.',
      activeLimitMessage:
          'Можно держать не больше 3 активных пассажирских запросов одновременно.',
      cooldownMessage: (s) =>
          'Подождите $s сек. перед следующим запросом пассажира.',
    );

    final inserted = await _client
        .from('passenger_requests')
        .insert({
          'passenger_id': user.id,
          'from_country': payload.fromCountry,
          'from_city': payload.fromCity,
          'to_country': payload.toCountry,
          'to_city': payload.toCity,
          'departure_at': payload.departureAt.toUtc().toIso8601String(),
          'seats_needed': payload.seatsNeeded,
          'budget': payload.budget,
          'note': payload.note,
          'status': 'active',
        })
        .select()
        .single();

    return PassengerRequestRow(inserted)
        .toModel(passenger, localizedStatus: 'Активно');
  }

  Future<BookedTrip> createBooking({
    required Ride ride,
    required int seatsCount,
  }) async {
    final user = _requireUser();
    final rideId = ride.backendId;
    if (rideId == null) {
      throw SupabaseServiceError(
        'Не удалось определить поездку для бронирования.',
      );
    }
    if (ride.driver.backendId == user.id) {
      throw SupabaseServiceError('Нельзя забронировать собственную поездку.');
    }
    if (seatsCount <= 0) {
      throw SupabaseServiceError('Выберите количество мест.');
    }

    final activeBookings = await _client
        .from('bookings')
        .select('status')
        .eq('passenger_id', user.id)
        .order('created_at', ascending: false)
        .limit(12);
    final activeCount = activeBookings
        .where((b) =>
            b['status'] == 'pending' || b['status'] == 'confirmed')
        .length;
    if (activeCount >= _maxActiveBookingsPerPassenger) {
      throw SupabaseServiceError(
        'Можно держать не больше 3 активных бронирований одновременно.',
      );
    }

    final status = ride.instantBookingEnabled ? 'confirmed' : 'pending';
    final inserted = await _client
        .from('bookings')
        .insert({
          'ride_id': rideId,
          'passenger_id': user.id,
          'seats_count': seatsCount,
          'selected_seat_labels': <String>[],
          'status': status,
        })
        .select()
        .single();
    final bookingRow = BookingRow(inserted);

    return BookedTrip(
      id: bookingRow.id,
      backendId: bookingRow.id,
      ride: ride,
      seatsBooked: bookingRow.seatsCount,
      status: _localizedBookingStatus(bookingRow.status),
      category: TripCategory.active,
      role: TripRole.passenger,
    );
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await _client
        .from('bookings')
        .update({'status': status})
        .eq('id', bookingId);
  }

  Future<void> cancelBookedTrip(BookedTrip trip) async {
    switch (trip.role) {
      case TripRole.passenger:
        final id = trip.backendId;
        if (id == null) return;
        await _client.from('bookings').update({'status': 'cancelled'}).eq(
          'id',
          id,
        );
      case TripRole.driver:
        final rideId = trip.ride.backendId;
        if (rideId == null) return;
        await _client.from('rides').update({
          'status': 'cancelled',
          'search_passengers_enabled': false,
        }).eq('id', rideId);
    }
  }

  Future<void> cancelPassengerRequest(PassengerRequest request) async {
    final id = request.backendId;
    if (id == null) return;
    await _client
        .from('passenger_requests')
        .update({'status': 'cancelled'})
        .eq('id', id);
  }

  Future<void> updateRideSearchPassengers({
    required String rideId,
    required bool enabled,
  }) async {
    await _client
        .from('rides')
        .update({'search_passengers_enabled': enabled})
        .eq('id', rideId);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  User _requireUser() {
    final user = currentUser;
    if (user == null) {
      throw SupabaseServiceError('Пользователь не авторизован.');
    }
    return user;
  }

  String _dateOnly(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  /// Ported from `validatePublicationWindow`.
  Future<void> _validatePublication({
    required String table,
    required String ownerColumn,
    required String ownerId,
    required String payloadFromCity,
    required String payloadToCity,
    required DateTime payloadDepartureAt,
    required int maxActive,
    required String duplicateMessage,
    required String activeLimitMessage,
    required String Function(int) cooldownMessage,
  }) async {
    final rows = await _client
        .from(table)
        .select('from_city,to_city,departure_at,status,created_at')
        .eq(ownerColumn, ownerId)
        .order('created_at', ascending: false)
        .limit(20);
    final now = DateTime.now();
    final activeStatuses = {'active', 'pending'};

    final activeUpcoming = rows.where((row) {
      final status = (row['status'] as String? ?? '').toLowerCase();
      final departure = DateTime.tryParse('${row['departure_at']}')?.toLocal();
      return activeStatuses.contains(status) &&
          departure != null &&
          departure.isAfter(now);
    }).toList();

    if (activeUpcoming.length >= maxActive) {
      throw SupabaseServiceError(activeLimitMessage);
    }

    if (rows.isNotEmpty) {
      final latestCreated =
          DateTime.tryParse('${rows.first['created_at']}')?.toLocal();
      if (latestCreated != null) {
        final elapsed = now.difference(latestCreated);
        if (elapsed < _publishCooldown) {
          final remaining = (_publishCooldown - elapsed).inSeconds + 1;
          throw SupabaseServiceError(cooldownMessage(remaining));
        }
      }
    }

    String norm(String v) => v.trim().toLowerCase();
    final hasDuplicate = activeUpcoming.any((row) {
      final sameRoute = norm('${row['from_city']}') == norm(payloadFromCity) &&
          norm('${row['to_city']}') == norm(payloadToCity);
      final departure = DateTime.tryParse('${row['departure_at']}')?.toLocal();
      final closeDeparture = departure != null &&
          departure.difference(payloadDepartureAt).abs() <=
              _duplicateDepartureTolerance;
      return sameRoute && closeDeparture;
    });
    if (hasDuplicate) {
      throw SupabaseServiceError(duplicateMessage);
    }
  }

  String _localizedBookingStatus(String status) => switch (status) {
        'pending' => 'Ждёт подтверждения',
        'confirmed' => 'Подтверждена',
        'cancelled' => 'Отменена',
        'completed' => 'Завершена',
        _ => status,
      };

  String _localizedRideStatus(String status, DateTime departureAt) {
    return switch (status) {
      'cancelled' => 'Поездка отменена',
      'completed' => 'Завершена',
      _ => departureAt.isBefore(DateTime.now())
          ? 'Завершена'
          : 'Опубликована',
    };
  }

  String _localizedPassengerRequestStatus(String status) => switch (status) {
        'cancelled' => 'Запрос отменён',
        'completed' => 'Запрос завершён',
        _ => 'Активно',
      };

  // ---------------------------------------------------------------------------
  // Support / idea / report (ported from SupabaseServiceSupport.swift)
  // ---------------------------------------------------------------------------

  /// Ported from `submitSupportRequest`. Wraps the contact intake with the
  /// `support` kind and a `Поддержка: …` subject.
  Future<void> submitSupportRequest({
    required String topic,
    required String message,
    required UserProfile profile,
  }) {
    return _submitContactIntake(
      kind: 'support',
      subject: 'Поддержка: $topic',
      message: message,
      topic: topic,
      profile: profile,
    );
  }

  /// Ported from `submitIdea`.
  Future<void> submitIdea({
    required String title,
    required String details,
    required UserProfile profile,
  }) {
    return _submitContactIntake(
      kind: 'idea',
      subject: 'Идея: $title',
      message: details,
      profile: profile,
    );
  }

  /// Ported from `submitUserReport`.
  Future<void> submitUserReport({
    required UserProfile reportedUser,
    required String reason,
    required String details,
    required UserProfile profile,
  }) {
    final name = reportedUser.name.trim();
    final id = reportedUser.backendId ?? 'unknown';
    final header =
        'Жалоба на пользователя\nПользователь: $name\nID: $id\nПричина: $reason';
    return _submitContactIntake(
      kind: 'support',
      subject: 'Жалоба на пользователя: $name',
      message: '$header\n\n$details',
      topic: 'Жалоба на пользователя',
      profile: profile,
    );
  }

  /// Ported from `submitContactIntake` — posts to the
  /// `contact--intake` Edge function with the same payload shape the Swift
  /// client uses.
  Future<void> _submitContactIntake({
    required String kind,
    required String subject,
    required String message,
    required UserProfile profile,
    String? topic,
  }) async {
    final session = _client.auth.currentSession;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'apikey': SupabaseConfig.publishableKey,
      if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
    };
    final payload = <String, dynamic>{
      'kind': kind,
      'subject': subject,
      'message': message,
      'name': profile.name,
    };
    if (topic != null) payload['topic'] = topic;
    if (profile.email.isNotEmpty) payload['email'] = profile.email;
    if (profile.phoneNumber.isNotEmpty) payload['phone'] = profile.phoneNumber;
    if (profile.backendId != null) payload['userID'] = profile.backendId;
    if (profile.countryOfResidence != null) {
      payload['residenceCountry'] = profile.countryOfResidence!.title;
    }

    final response = await _client.functions.invoke(
      SupabaseConfig.contactIntakeFunctionPath,
      headers: headers,
      body: payload,
    );
    final status = response.status;
    if (status < 200 || status >= 300) {
      throw SupabaseServiceError(
        'Не удалось отправить обращение (HTTP $status).',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Public profile (ported from fetchPublicProfile / fetchPublicProfileStats /
  // fetchProfileReviews)
  // ---------------------------------------------------------------------------

  /// Ported from `fetchPublicProfile`. Returns the requested user's profile
  /// (no special enrichment — same fields as a normal profile fetch).
  Future<UserProfile?> fetchPublicProfile(String userId) async {
    final rows = await _client.from('profiles').select().eq('id', userId).limit(1);
    if (rows.isEmpty) return null;
    return ProfileRow(Map<String, dynamic>.from(rows.first as Map)).toModel();
  }

  /// Ported from `fetchPublicProfileStats`. Calls the `public_profile_stats`
  /// RPC and returns the driver/passenger trip counters.
  Future<PublicProfileStats> fetchPublicProfileStats(String userId) async {
    try {
      final raw = await _client.rpc(
        'public_profile_stats',
        params: {'target_user_id': userId},
      );
      if (raw is List && raw.isNotEmpty) {
        final row = Map<String, dynamic>.from(raw.first as Map);
        return PublicProfileStats(
          driverTripsCount:
              (row['driver_trips_count'] as num?)?.toInt() ?? 0,
          passengerTripsCount:
              (row['passenger_trips_count'] as num?)?.toInt() ?? 0,
        );
      }
      return PublicProfileStats.empty;
    } catch (_) {
      return PublicProfileStats.empty;
    }
  }

  /// Ported from `fetchProfileReviews`. Returns every review of [userId] with
  /// the reviewer's display name resolved from `profiles.full_name`.
  Future<List<RideReview>> fetchProfileReviews(String userId) async {
    final reviewRows = await _client
        .from('ride_reviews')
        .select()
        .eq('reviewee_id', userId)
        .order('created_at', ascending: false);
    if (reviewRows.isEmpty) return const [];
    final rows = reviewRows
        .map((e) => RideReviewRow(Map<String, dynamic>.from(e as Map)))
        .toList();
    final reviewerIds = rows.map((r) => r.reviewerId).toSet().toList();
    final profileRows = await _client
        .from('profiles')
        .select('id,full_name')
        .inFilter('id', reviewerIds);
    final namesById = <String, String>{
      for (final raw in profileRows)
        (raw as Map)['id'] as String:
            ((raw)['full_name'] as String?) ?? 'Пользователь',
    };
    return [
      for (final row in rows)
        row.toModel(namesById[row.reviewerId] ?? 'Пользователь'),
    ];
  }

  // ---------------------------------------------------------------------------
  // Reviews (ported from fetchMyRideReview / submitRideReview)
  // ---------------------------------------------------------------------------

  /// Ported from `fetchMyRideReview`. Returns the signed-in user's review of
  /// [revieweeId] for [rideId], or null if none exists.
  Future<RideReview?> fetchMyRideReview({
    required String rideId,
    required String revieweeId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final rows = await _client
        .from('ride_reviews')
        .select()
        .eq('ride_id', rideId)
        .eq('reviewer_id', user.id)
        .eq('reviewee_id', revieweeId)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = RideReviewRow(Map<String, dynamic>.from(rows.first as Map));
    return row.toModel('Вы');
  }

  /// Ported from `submitRideReview`. No-ops if the user has already left a
  /// review for the same (ride, reviewee).
  Future<void> submitRideReview({
    required String rideId,
    required String revieweeId,
    required double rating,
    required String comment,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw SupabaseServiceError('Пользователь не авторизован.');
    }
    final existing = await fetchMyRideReview(
      rideId: rideId,
      revieweeId: revieweeId,
    );
    if (existing != null) return;
    await _client.from('ride_reviews').insert({
      'ride_id': rideId,
      'reviewer_id': user.id,
      'reviewee_id': revieweeId,
      'rating': rating,
      'comment': comment,
    });
  }

  // ---------------------------------------------------------------------------
  // Push device tokens (ported from registerPushDeviceToken /
  // unregisterPushDeviceToken)
  // ---------------------------------------------------------------------------

  /// Ported from `registerPushDeviceToken(_:)`. Upserts the device token to
  /// `push_device_tokens` and marks it active. No-op when not signed in.
  ///
  /// `platform` mirrors Swift (`"ios"` / `"android"`). `push_environment`
  /// mirrors the Swift `#if DEBUG ? "development" : "production"` for iOS;
  /// FCM has no dev/prod split so Android always sends `"production"`.
  Future<void> registerPushDeviceToken(String token) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('push_device_tokens').upsert({
      'user_id': user.id,
      'device_token': token,
      'platform': _platformIdentifier,
      'app_bundle_id': 'com.hamsafar.hamsafar',
      'push_environment': _pushEnvironment,
      'is_active': true,
    }, onConflict: 'device_token');
  }

  static String get _platformIdentifier {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  static String get _pushEnvironment {
    if (Platform.isAndroid) return 'production';
    return kReleaseMode ? 'production' : 'development';
  }

  /// Ported from `unregisterPushDeviceToken(_:)`. Sets `is_active = false`
  /// for the given token row.
  Future<void> unregisterPushDeviceToken(String token) async {
    if (_client.auth.currentUser == null) return;
    await _client
        .from('push_device_tokens')
        .update({'is_active': false}).eq('device_token', token);
  }

  // ---------------------------------------------------------------------------
  // Activity notifications (ported from fetchActivityNotifications /
  // markAllActivityNotificationsRead)
  // ---------------------------------------------------------------------------

  /// Ported from `fetchActivityNotifications`. Returns the signed-in user's
  /// activity feed (newest first). Returns an empty list if not signed in.
  Future<List<ActivityNotification>> fetchActivityNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('activity_notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return [
      for (final raw in rows)
        ActivityNotification.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  /// Ported from `markAllActivityNotificationsRead`.
  Future<void> markAllActivityNotificationsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('activity_notifications')
        .update({'is_read': true}).eq('user_id', user.id);
  }

  // ---------------------------------------------------------------------------
  // Search history (ported from fetchSearchHistory / recordSearchHistory)
  // ---------------------------------------------------------------------------

  /// Ported from `fetchSearchHistory`. Returns up to 3 most recent unique
  /// from→to pairs.
  Future<List<MapEntry<String, String>>> fetchSearchHistory() async {
    if (_client.auth.currentUser == null) return const [];
    final rows = await _client
        .from('search_history')
        .select('from_city,to_city,created_at')
        .order('created_at', ascending: false)
        .limit(12);
    final seen = <String>{};
    final result = <MapEntry<String, String>>[];
    for (final row in rows) {
      final from = (row['from_city'] as String?) ?? '';
      final to = (row['to_city'] as String?) ?? '';
      if (from.isEmpty || to.isEmpty) continue;
      final key = '$from|$to';
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(MapEntry(from, to));
      if (result.length == 3) break;
    }
    return result;
  }

  /// Ported from `recordSearchHistory`. Inserts a new row for the
  /// current user; best-effort, errors are swallowed by the caller.
  Future<void> recordSearchHistory({
    required String from,
    required String to,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('search_history').insert({
      'user_id': user.id,
      'from_city': from,
      'to_city': to,
    });
  }
}

enum _AuthCtx { signIn, register, verifyCode, resendCode }

/// Ported from `localizedAuthErrorMessage` in `AuthenticationViews.swift`.
String _localizedAuthError(String raw, _AuthCtx context) {
  final n = raw.toLowerCase();
  if (n.contains('invalid login credentials') ||
      n.contains('invalid credentials') ||
      n.contains('invalid email or password')) {
    return 'Неверный email или пароль.';
  }
  if (n.contains('email not confirmed')) {
    return 'Подтвердите email и попробуйте снова.';
  }
  if (n.contains('user already registered') ||
      n.contains('already been registered')) {
    return 'Пользователь с таким email уже зарегистрирован.';
  }
  if (n.contains('rate limit') ||
      n.contains('security purposes') ||
      n.contains('too many requests')) {
    return 'Слишком много попыток. Подождите немного и попробуйте снова.';
  }
  if (n.contains('otp') && n.contains('expired')) {
    return 'Срок действия кода истёк. Запросите новый код.';
  }
  if (n.contains('otp') && (n.contains('invalid') || n.contains('token'))) {
    return 'Неверный код подтверждения. Проверьте письмо и попробуйте снова.';
  }
  if (n.contains('network') || n.contains('internet') || n.contains('offline')) {
    return 'Нет соединения с интернетом. Проверьте сеть и повторите попытку.';
  }
  return switch (context) {
    _AuthCtx.signIn => 'Не удалось войти. Проверьте данные и попробуйте снова.',
    _AuthCtx.register =>
      'Не удалось начать регистрацию. Проверьте данные и попробуйте снова.',
    _AuthCtx.verifyCode =>
      'Не удалось завершить регистрацию. Проверьте код и попробуйте снова.',
    _AuthCtx.resendCode =>
      'Не удалось отправить код повторно. Попробуйте чуть позже.',
  };
}

