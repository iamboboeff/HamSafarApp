import 'dart:io' show HttpClient, HttpDate, HttpException, Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n/l10n.dart';
import '../../models/activity_notification.dart';
import '../../models/booked_trip.dart';
import '../../models/car_profile.dart';
import '../../models/ride_alert.dart';
import '../../models/passenger_request.dart';
import '../../models/ride.dart';
import '../../models/ride_passenger_booking.dart';
import '../../models/trip_enums.dart';
import '../../models/user_profile.dart';
import 'supabase_config.dart';
import 'supabase_rows.dart';

/// App-level error with a user-facing (Russian) message.
class SupabaseServiceError implements Exception {
  SupabaseServiceError(this.message, {this.retryAfterSeconds});
  final String message;

  /// When the backend rate-limits an action it reports how many seconds the
  /// user must wait. Surfaced so the UI can show a live countdown (QA #80).
  final int? retryAfterSeconds;

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
    this.currency = 'TJS',
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

  /// Currency the driver priced the ride in (TJS/UZS), persisted so the card
  /// shows the right currency instead of the driver's residence default.
  final String currency;
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
      throw SupabaseServiceError(tr('Не удалось войти. Попробуйте ещё раз.'));
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
      throw SupabaseServiceError(
        _localizedAuthError(e.message, _AuthCtx.register),
        retryAfterSeconds: _retryAfterSeconds(e.message),
      );
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
        retryAfterSeconds: _retryAfterSeconds(e.message),
      );
    }
  }

  /// Sends a password-recovery code to [email] (QA #67). Mirrors the signup OTP
  /// flow — the recovery email template must include the `{{ .Token }}` code.
  Future<void> sendPasswordRecovery(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on AuthException catch (e) {
      throw SupabaseServiceError(
        _localizedAuthError(e.message, _AuthCtx.resendCode),
        retryAfterSeconds: _retryAfterSeconds(e.message),
      );
    }
  }

  /// Verifies the recovery code, establishing a short-lived session that lets
  /// the user set a new password via [updatePassword] (QA #67).
  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _client.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: token.trim(),
        type: OtpType.recovery,
      );
    } on AuthException catch (e) {
      throw SupabaseServiceError(
        _localizedAuthError(e.message, _AuthCtx.verifyCode),
      );
    }
    if (currentUser == null) {
      throw SupabaseServiceError(
        tr('Не удалось подтвердить код. Попробуйте снова.'),
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
        tr('Не удалось завершить регистрацию. Попробуйте снова.'),
      );
    }
    return _fetchSessionData(user);
  }

  // Local scope clears the persisted session without a network round-trip, so
  // signing out works offline (global scope hangs/fails with no connection and
  // could leave the session persisted, re-logging the user in on restart —
  // QA #92). It also only logs out this device, which is what a normal
  // "log out" should do.
  Future<void> signOut() =>
      _client.auth.signOut(scope: SignOutScope.local);

  /// Returns the current server time by issuing a HEAD request against the
  /// Supabase URL and parsing the `Date` HTTP response header.
  ///
  /// Ported from `SupabaseServiceAccount.swift:80 fetchCurrentServerDate`.
  /// Used by the create-ride flow to guard against publishing rides with a
  /// past timestamp when the device clock is skewed.
  Future<DateTime> fetchCurrentServerDate() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.openUrl(
        'HEAD',
        Uri.parse(SupabaseConfig.url),
      );
      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
      // Drain the (empty) body so the socket can be reused.
      await response.drain<void>();
      final dateHeader = response.headers.value('date');
      if (dateHeader == null || dateHeader.isEmpty) {
        throw SupabaseServiceError(tr('Не удалось получить серверное время.'));
      }
      try {
        return HttpDate.parse(dateHeader).toUtc();
      } on HttpException {
        throw SupabaseServiceError(tr('Не удалось разобрать серверное время.'));
      } on FormatException {
        throw SupabaseServiceError(tr('Не удалось разобрать серверное время.'));
      }
    } finally {
      client.close(force: false);
    }
  }

  /// Updates the password for the currently-authenticated user.
  ///
  /// Ported from `SupabaseServiceAccount.swift:103 updatePassword`. The Swift
  /// flow re-authenticates with the current password first (see
  /// `ProfileViews.swift:512`) — that re-auth is kept on the caller side so
  /// this method only handles the actual password update RPC.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw SupabaseServiceError(
        _localizedAuthError(e.message, _AuthCtx.signIn),
      );
    }
  }

  /// Permanently deletes the signed-in user's account via the `delete-account`
  /// edge function (QA #82). The backend removes the auth user; every owned row
  /// in public.* is cleaned up by ON DELETE CASCADE. Callers must sign out
  /// locally afterwards — the session is no longer valid.
  Future<void> deleteAccount() async {
    try {
      final res = await _client.functions.invoke('delete-account');
      if (res.status != 200) {
        throw SupabaseServiceError(
          tr('Не удалось удалить аккаунт. Попробуйте ещё раз.'),
        );
      }
    } on SupabaseServiceError {
      rethrow;
    } catch (_) {
      throw SupabaseServiceError(
        tr('Не удалось удалить аккаунт. Попробуйте ещё раз.'),
      );
    }
  }

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
          tr('Пользователь'),
      rating: 5,
      completedTrips: 0,
      phoneNumber: user.phone ?? '',
      email: user.email ?? '',
    );
  }

  /// Uploads a newly-picked avatar to the `avatars` Storage bucket and returns
  /// its public URL (with a cache-busting `?t=` so updates aren't masked by a
  /// stale cache). Returns the existing [UserProfile.avatarUrl] unchanged when
  /// no new image was picked.
  Future<String?> _uploadAvatarIfNeeded(String userId, UserProfile profile) async {
    final bytes = profile.avatarBytes;
    if (bytes == null || bytes.isEmpty) return profile.avatarUrl;
    final path = '$userId/avatar.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final base = _client.storage.from('avatars').getPublicUrl(path);
    return '$base?t=${DateTime.now().millisecondsSinceEpoch}';
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

    // A freshly-picked avatar arrives as bytes — upload it to Storage (small,
    // CDN-served) and persist the public URL instead of inlining base64 into
    // the row. With no new pick, keep whatever URL the profile already has.
    final avatarUrl = await _uploadAvatarIfNeeded(user.id, profile);

    await _client.from('profiles').upsert({
      'id': user.id,
      'full_name': profile.name,
      'phone': profile.phoneNumber,
      'email': profile.email,
      'avatar_url': avatarUrl,
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

  /// Fetches only the referenced profiles by id. Crucial for performance:
  /// every `profiles` row carries a large base64 avatar inline (hundreds of KB
  /// each), so an unfiltered `select()` downloads several MB on every call.
  /// Fetching just the ids actually shown keeps each load small.
  Future<List<ProfileRow>> _profilesByIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const [];
    final rows = await _client.from('profiles').select().inFilter('id', list);
    return rows.map(ProfileRow.new).toList();
  }

  /// [_enrichedProfilesById] that fetches the referenced rows by id first.
  Future<Map<String, UserProfile>> _enrichedProfilesByIds(
    Iterable<String> ids,
  ) async {
    final rows = await _profilesByIds(ids);
    if (rows.isEmpty) return {};
    return _enrichedProfilesById(rows);
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
        ratingCount: entry.value.count,
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
    int ratingCount = 0,
  }) {
    return UserProfile(
      id: p.id,
      backendId: p.backendId,
      name: p.name,
      rating: rating,
      completedTrips: completedTrips,
      ratingCount: ratingCount,
      phoneNumber: p.phoneNumber,
      email: p.email,
      avatarBytes: p.avatarBytes,
      avatarUrl: p.avatarUrl,
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
      carColor: ride.carColor,
      carPlate: ride.carPlate,
      durationSeconds: ride.durationSeconds,
      routeSummary: ride.routeSummary,
      notes: ride.notes,
      driver: ride.driver,
      reviews: ride.reviews,
      availableSeatLabels: remaining,
      pricingCountry: ride.pricingCountry,
    );
  }

  Future<List<RideReviewRow>> _fetchReviewRows(
    List<String> revieweeIds,
  ) async {
    if (revieweeIds.isEmpty) return const [];
    final rows = await _client
        .from('ride_reviews')
        .select()
        .inFilter('reviewee_id', revieweeIds)
        .order('created_at', ascending: false);
    return rows.map(RideReviewRow.new).toList();
  }

  Map<String, List<RideReview>> _groupReviews(
    List<RideReviewRow> rows,
    Map<String, UserProfile> profilesById,
  ) {
    final result = <String, List<RideReview>>{};
    for (final row in rows) {
      final author = profilesById[row.reviewerId]?.name ?? tr('Пассажир');
      result.putIfAbsent(row.revieweeId, () => []).add(row.toModel(author));
    }
    return result;
  }

  /// Ported from `fetchRides`.
  Future<List<Ride>> fetchRides() async {
    // Kick off the independent queries concurrently instead of one-by-one —
    // this is the main cause of the slow search (was ~6 sequential round-trips).
    // Only active rides are fetched (filter pushed to Postgres), and profiles
    // are fetched by id afterwards so we never download the whole profiles
    // table (each row carries a large base64 avatar).
    final ridesFuture =
        _client.from('rides_with_availability').select().eq('status', 'active');
    final vehiclesFuture = _fetchVehiclesById();
    final bookingsFuture = _fetchAllBookings();

    final rideRows = (await ridesFuture).map(RideRow.new).toList();
    final active = rideRows.where((r) => r.status == 'active').toList()
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    final driverIds = active.map((r) => r.driverId).toSet().toList();
    final reviewRows = await _fetchReviewRows(driverIds);
    final profilesById = await _enrichedProfilesByIds(
      {...driverIds, ...reviewRows.map((r) => r.reviewerId)},
    );
    final reviews = _groupReviews(reviewRows, profilesById);
    final vehiclesById = await vehiclesFuture;
    final occupied = _occupiedSeatsByRideId(await bookingsFuture);

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
    final rows = (await _client
            .from('passenger_requests')
            .select()
            .eq('status', 'active'))
        .map(PassengerRequestRow.new)
        .toList();

    final active = rows.where((r) => r.status == 'active').toList()
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    final profilesById = await _enrichedProfilesByIds(
      active.map((r) => r.passengerId).toSet(),
    );

    return active
        .map((row) {
          final passenger = profilesById[row.passengerId] ??
              UserProfile(
                id: row.passengerId,
                backendId: row.passengerId,
                name: tr('Пассажир'),
                rating: 5,
                completedTrips: 0,
              );
          return row.toModel(passenger, localizedStatus: tr('Активно'));
        })
        .where((r) => !r.isCompleted)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Ride alerts (notify-me-when-a-ride-appears-on-this-route)
  // ---------------------------------------------------------------------------

  Future<List<RideAlert>> fetchRideAlerts() async {
    final user = currentUser;
    if (user == null) return const [];
    final rows = await _client
        .from('ride_alerts')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return rows.map((r) => RideAlert.fromRow(r)).toList();
  }

  Future<RideAlert> createRideAlert({
    required String fromCity,
    required String toCity,
  }) async {
    final user = _requireUser();
    final row = await _client
        .from('ride_alerts')
        .upsert({
          'user_id': user.id,
          'from_city': fromCity,
          'to_city': toCity,
        }, onConflict: 'user_id,from_city,to_city')
        .select()
        .single();
    return RideAlert.fromRow(row);
  }

  Future<void> deleteRideAlert(String id) async {
    await _client.from('ride_alerts').delete().eq('id', id);
  }

  /// Ported from `fetchBookedTrips`.
  Future<List<BookedTrip>> fetchBookedTrips() async {
    final user = _requireUser();
    // Round-trip 1: independent queries in parallel (was 5 sequential awaits).
    final ridesFuture = _client.from('rides_with_availability').select();
    final vehiclesFuture = _fetchVehiclesById();
    final bookingsFuture = _fetchAllBookings();
    final searchPrefsFuture = _client
        .from('rides')
        .select('id, search_passengers_enabled')
        .eq('driver_id', user.id);

    final rideRows = (await ridesFuture).map(RideRow.new).toList();
    final vehiclesById = await vehiclesFuture;
    final bookings = await bookingsFuture;
    final searchPrefsRaw = await searchPrefsFuture;

    final ridesById = {
      for (final r in rideRows)
        if (r.id != null) r.id!: r,
    };
    final occupied = _occupiedSeatsByRideId(bookings);
    final searchPrefs = {
      for (final raw in searchPrefsRaw)
        raw['id'] as String:
            (raw['search_passengers_enabled'] as bool?) ?? true,
    };

    // Round-trip 2: only the profiles actually rendered — the user (their own
    // trips) plus the drivers of rides they booked. Avoids pulling the whole
    // profiles table with its inline base64 avatars.
    final referencedProfileIds = <String>{user.id};
    for (final b in bookings) {
      if (b.passengerId == user.id) {
        final driverId = ridesById[b.rideId]?.driverId;
        if (driverId != null) referencedProfileIds.add(driverId);
      }
    }
    final profilesById = await _enrichedProfilesByIds(referencedProfileIds);

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
            cancelReason: booking.cancelReason,
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
            name: tr('Пассажир'),
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
      duplicateMessage: tr(
          'Похожая поездка уже опубликована. Не создавайте дубликат маршрута.'),
      activeLimitMessage:
          tr('Можно держать не больше 5 активных поездок одновременно.'),
      cooldownMessage: (s) => trf(
          'Подождите {s} сек. перед следующей публикацией поездки.', {'s': s}),
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
          'currency': payload.currency,
          'search_passengers_enabled': true,
          'status': 'active',
        })
        .select()
        .single();

    final row = RideRow(inserted);
    return row.toModel(
      profilesById: {driver.backendId ?? driver.id: driver},
      vehiclesById: {
        ?vehicleId: VehicleRow({
          'id': vehicleId,
          'model': carProfile.model,
          'color': carProfile.color,
          'plate_number': carProfile.plateNumber,
        }),
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
      duplicateMessage: tr(
          'Похожий запрос уже опубликован. Не создавайте дубликат маршрута.'),
      activeLimitMessage: tr(
          'Можно держать не больше 3 активных пассажирских запросов одновременно.'),
      cooldownMessage: (s) => trf(
          'Подождите {s} сек. перед следующим запросом пассажира.', {'s': s}),
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
        .toModel(passenger, localizedStatus: tr('Активно'));
  }

  Future<BookedTrip> createBooking({
    required Ride ride,
    required int seatsCount,
  }) async {
    final user = _requireUser();
    final rideId = ride.backendId;
    if (rideId == null) {
      throw SupabaseServiceError(
        tr('Не удалось определить поездку для бронирования.'),
      );
    }
    if (ride.driver.backendId == user.id) {
      throw SupabaseServiceError(tr('Нельзя забронировать собственную поездку.'));
    }
    if (seatsCount <= 0) {
      throw SupabaseServiceError(tr('Выберите количество мест.'));
    }
    // Can't book a ride whose departure time has already passed (QA #71).
    if (!ride.departureDate.isAfter(DateTime.now())) {
      throw SupabaseServiceError(
        tr('Время отправления этой поездки уже прошло.'),
      );
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
        tr('Можно держать не больше 3 активных бронирований одновременно.'),
      );
    }

    final status = ride.instantBookingEnabled ? 'confirmed' : 'pending';

    // `bookings` is UNIQUE on (ride_id, passenger_id), so a passenger who was
    // previously cancelled by the driver still has a row here. Re-activate it
    // instead of inserting a duplicate, which would violate the constraint and
    // make re-booking impossible (QA #83).
    final existingRows = await _client
        .from('bookings')
        .select('id, status')
        .eq('ride_id', rideId)
        .eq('passenger_id', user.id)
        .limit(1);
    final existing = existingRows.isNotEmpty ? existingRows.first : null;

    final Map<String, dynamic> bookingData = {
      'seats_count': seatsCount,
      'selected_seat_labels': <String>[],
      'status': status,
      'cancel_reason': null,
    };

    final Map<String, dynamic> row;
    if (existing != null) {
      final existingStatus = existing['status'] as String?;
      if (existingStatus == 'pending' || existingStatus == 'confirmed') {
        throw SupabaseServiceError(tr('Вы уже забронировали эту поездку.'));
      }
      row = await _client
          .from('bookings')
          .update(bookingData)
          .eq('id', existing['id'] as Object)
          .select()
          .single();
    } else {
      row = await _client
          .from('bookings')
          .insert({
            'ride_id': rideId,
            'passenger_id': user.id,
            ...bookingData,
          })
          .select()
          .single();
    }
    final bookingRow = BookingRow(row);

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
      throw SupabaseServiceError(tr('Пользователь не авторизован.'));
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
      // A ride that has merely passed its departure time is NOT finished — it
      // is under way. Completion is driven by the estimated arrival
      // (`BookedTrip.isCompleted` -> `ride.hasFinished`) or an explicit server
      // `completed` status, both of which are identical for the driver and the
      // passenger — so the trip flips to "completed" for both at the same
      // moment. Previously a passed departure was localised to "Завершена"
      // here, which auto-completed the ride for the driver at its start time
      // while the passenger (whose status comes from the booking row) stayed
      // active — see QA #96/#97.
      _ => departureAt.isBefore(DateTime.now()) ? 'В пути' : 'Опубликована',
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

  // ---------------------------------------------------------------------------
  // Blocking (App Store Guideline 1.2 — let users block abusive users)
  // ---------------------------------------------------------------------------

  /// Every user id the current user is in a block relationship with, in either
  /// direction (people they blocked + people who blocked them). The client uses
  /// this to hide blocked users' chats, rides and requests mutually. Backed by
  /// the `blocked_relationship_ids` SECURITY DEFINER function, so neither side
  /// can tell who blocked whom.
  Future<Set<String>> fetchBlockedUserIds() async {
    if (_client.auth.currentUser == null) return <String>{};
    try {
      final result = await _client.rpc('blocked_relationship_ids');
      if (result is List) {
        return result.map((e) => e?.toString()).whereType<String>().toSet();
      }
    } catch (_) {
      // Best-effort: a failure here must never break the chat list or feed.
    }
    return <String>{};
  }

  /// Blocks [blockedId] for the current user. Idempotent.
  Future<void> blockUser(String blockedId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw SupabaseServiceError(tr('Пользователь не авторизован.'));
    }
    if (blockedId == userId) return;
    await _client.from('blocked_users').upsert(
      {'blocker_id': userId, 'blocked_id': blockedId},
      onConflict: 'blocker_id,blocked_id',
    );
  }

  /// Removes the current user's block on [blockedId]. Idempotent.
  Future<void> unblockUser(String blockedId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('blocked_users')
        .delete()
        .eq('blocker_id', userId)
        .eq('blocked_id', blockedId);
  }

  /// The profiles the current user has blocked, newest first — for the
  /// "Заблокированные пользователи" management screen. Returns only the user's
  /// own outgoing blocks (never "who blocked me").
  Future<List<UserProfile>> fetchBlockedProfiles() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final blockRows = await _client
        .from('blocked_users')
        .select('blocked_id, created_at')
        .eq('blocker_id', userId)
        .order('created_at', ascending: false);
    final ids = blockRows
        .map((r) => r['blocked_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return const [];
    final profiles = await _client
        .from('profiles')
        .select('id,full_name,avatar_url')
        .inFilter('id', ids);
    final byId = <String, UserProfile>{};
    for (final raw in profiles) {
      final id = raw['id'] as String?;
      if (id == null) continue;
      byId[id] = UserProfile(
        id: id,
        backendId: id,
        name: (raw['full_name'] as String?) ?? tr('Пользователь'),
        rating: 0,
        completedTrips: 0,
        avatarBytes: UserProfile.decodeAvatarUrl(raw['avatar_url'] as String?),
        avatarUrl: UserProfile.avatarUrlFromColumn(raw['avatar_url'] as String?),
      );
    }
    // Preserve the blocked-at ordering from `blockRows`.
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
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
        trf('Не удалось отправить обращение (HTTP {status}).', {'status': status}),
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
    final base =
        ProfileRow(Map<String, dynamic>.from(rows.first as Map)).toModel();
    // Overlay the real review aggregate so the rating badge reflects actual
    // reviews (and shows a placeholder when there are none) rather than the
    // profile row's default 5.0 (QA #20).
    final agg = (await _fetchReviewAggregates([userId]))[userId];
    if (agg == null) return base;
    return _withRatings(
      base,
      rating: agg.rating,
      ratingCount: agg.count,
      completedTrips:
          base.completedTrips > agg.count ? base.completedTrips : agg.count,
    );
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
            ((raw)['full_name'] as String?) ?? tr('Пользователь'),
    };
    return [
      for (final row in rows)
        row.toModel(namesById[row.reviewerId] ?? tr('Пользователь')),
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
    return row.toModel(tr('Вы'));
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
      throw SupabaseServiceError(tr('Пользователь не авторизован.'));
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
      // NB: the unique constraint on `push_device_tokens` is composite —
      // `UNIQUE (user_id, device_token)` — so the conflict target has to
      // match both columns. Specifying just `device_token` causes
      // PostgREST to reject the upsert with "no unique or exclusion
      // constraint matching ON CONFLICT specification" and the call
      // would otherwise fail silently because the call site uses
      // `.ignore()`.
    }, onConflict: 'user_id,device_token');
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
/// Extracts the "...after N seconds" wait hint Supabase returns on rate-limit
/// errors, so the UI can count down to the next allowed attempt (QA #80).
int? _retryAfterSeconds(String raw) {
  final match = RegExp(r'(\d+)\s*second', caseSensitive: false).firstMatch(raw);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

String _localizedAuthError(String raw, _AuthCtx context) {
  final n = raw.toLowerCase();
  if (n.contains('invalid login credentials') ||
      n.contains('invalid credentials') ||
      n.contains('invalid email or password')) {
    return tr('Неверный email или пароль.');
  }
  if (n.contains('email not confirmed')) {
    return tr('Подтвердите email и попробуйте снова.');
  }
  if (n.contains('user already registered') ||
      n.contains('already been registered')) {
    return tr('Пользователь с таким email уже зарегистрирован.');
  }
  if (n.contains('rate limit') ||
      n.contains('security purposes') ||
      n.contains('too many requests')) {
    final secs = _retryAfterSeconds(raw);
    if (secs != null) {
      return trf(
          'Слишком много попыток. Попробуйте снова через {secs} сек.',
          {'secs': secs});
    }
    return tr('Слишком много попыток. Подождите немного и попробуйте снова.');
  }
  if (n.contains('otp') && n.contains('expired')) {
    return tr('Срок действия кода истёк. Запросите новый код.');
  }
  if (n.contains('otp') && (n.contains('invalid') || n.contains('token'))) {
    return tr('Неверный код подтверждения. Проверьте письмо и попробуйте снова.');
  }
  // Offline: gotrue wraps the underlying socket/HTTP failure in an
  // AuthRetryableFetchException whose message is error.toString(), e.g.
  // "ClientException with SocketException: Failed host lookup ...". None of
  // those contain "network"/"internet", so match the raw socket markers too —
  // otherwise an offline login falls through to the generic credentials error
  // and the user can't tell "no connection" from "wrong password" (QA #92).
  if (n.contains('network') ||
      n.contains('internet') ||
      n.contains('offline') ||
      n.contains('socketexception') ||
      n.contains('clientexception') ||
      n.contains('retryablefetch') ||
      n.contains('failed host lookup') ||
      n.contains('connection refused') ||
      n.contains('connection closed') ||
      n.contains('connection reset') ||
      n.contains('connection timed out') ||
      n.contains('timed out')) {
    return tr('Нет соединения с интернетом. Проверьте сеть и повторите попытку.');
  }
  return switch (context) {
    _AuthCtx.signIn =>
      tr('Не удалось войти. Проверьте данные и попробуйте снова.'),
    _AuthCtx.register =>
      tr('Не удалось начать регистрацию. Проверьте данные и попробуйте снова.'),
    _AuthCtx.verifyCode =>
      tr('Не удалось завершить регистрацию. Проверьте код и попробуйте снова.'),
    _AuthCtx.resendCode =>
      tr('Не удалось отправить код повторно. Попробуйте чуть позже.'),
  };
}

