import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, AuthChangeEvent;

import 'activity_state.dart';
import '../core/preferences/preferences_store.dart';
import '../core/push/push_notifications_service.dart';
import '../core/supabase/supabase_service.dart';
import '../models/app_settings.dart';
import '../models/app_tab.dart';
import '../models/trip_section.dart';
import '../models/booked_trip.dart';
import '../models/car_profile.dart';
import '../models/ride_alert.dart';
import '../models/location.dart';
import '../models/passenger_request.dart';
import '../models/residence_country.dart';
import '../models/ride.dart';
import '../models/ride_search.dart';
import '../models/user_profile.dart';

/// Riverpod providers backing the app. Auth + marketplace + trips are wired to
/// the real Supabase backend (see [SupabaseService]); chat and the settings
/// toggles are still local.

/// The Supabase-backed service. The client is initialised in `main`.
final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService(Supabase.instance.client),
);

const _guestProfile = UserProfile(
  id: 'guest',
  name: '',
  rating: 0,
  completedTrips: 0,
);

const _emptyCarProfile = CarProfile(
  model: '',
  color: '',
  plateNumber: '',
  seats: '4',
);

// ---------------------------------------------------------------------------
// Session (auth + profile + vehicle) — replaces the SwiftUI `AppState.session`
// ---------------------------------------------------------------------------

class SessionState {
  const SessionState({
    required this.isAuthenticated,
    required this.isRestoring,
    required this.profile,
    required this.carProfile,
    required this.allowPublicProfile,
  });

  final bool isAuthenticated;
  final bool isRestoring;
  final UserProfile profile;
  final CarProfile carProfile;
  final bool allowPublicProfile;

  static const guest = SessionState(
    isAuthenticated: false,
    isRestoring: true,
    profile: _guestProfile,
    carProfile: _emptyCarProfile,
    allowPublicProfile: true,
  );

  SessionState copyWith({
    bool? isAuthenticated,
    bool? isRestoring,
    UserProfile? profile,
    CarProfile? carProfile,
    bool? allowPublicProfile,
  }) {
    return SessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isRestoring: isRestoring ?? this.isRestoring,
      profile: profile ?? this.profile,
      carProfile: carProfile ?? this.carProfile,
      allowPublicProfile: allowPublicProfile ?? this.allowPublicProfile,
    );
  }
}

class SessionNotifier extends Notifier<SessionState> {
  StreamSubscription<String>? _pushTokenSub;
  StreamSubscription<void>? _pushMessageSub;

  @override
  SessionState build() {
    _restore();
    _listenToAuthChanges();
    _listenToPushTokens();
    _listenToPushMessages();
    ref.onDispose(() {
      _pushTokenSub?.cancel();
      _pushMessageSub?.cancel();
    });
    return SessionState.guest;
  }

  SupabaseService get _service => ref.read(supabaseServiceProvider);

  Future<void> _restore() async {
    try {
      final data = await _service.restoreSession();
      if (data != null) {
        applySession(data);
        return;
      }
    } catch (_) {
      // Fall through to the guest state.
    }
    state = state.copyWith(isAuthenticated: false, isRestoring: false);
  }

  void _listenToAuthChanges() {
    final sub = _service.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        final token = PushNotificationsService.instance.latestToken;
        if (token != null) {
          _service.unregisterPushDeviceToken(token).ignore();
        }
        state = const SessionState(
          isAuthenticated: false,
          isRestoring: false,
          profile: _guestProfile,
          carProfile: _emptyCarProfile,
          allowPublicProfile: true,
        );
      }
    });
    ref.onDispose(sub.cancel);
  }

  /// Subscribes to APNs device-token updates and pushes them to Supabase
  /// whenever the user is signed in. Mirrors `registerPushDeviceToken` plus
  /// the iOS APNs callback in `HamSafarApp.swift`.
  void _listenToPushTokens() {
    _pushTokenSub =
        PushNotificationsService.instance.tokenStream.listen((token) {
      // Read own state directly — going through `isAuthenticatedProvider`
      // would form a cycle (sessionProvider → isAuthenticatedProvider →
      // sessionProvider) and Riverpod refuses to resolve it.
      if (state.isAuthenticated) {
        _service.registerPushDeviceToken(token).ignore();
      }
    });
  }

  /// Refreshes the in-app notification feed (and booking statuses) whenever a
  /// push arrives in the foreground or reopens the app, so the unread counter
  /// and notification list reflect it instead of going stale (QA #23, #86).
  void _listenToPushMessages() {
    _pushMessageSub =
        PushNotificationsService.instance.incomingMessages.listen((_) {
      if (!state.isAuthenticated) return;
      ref.read(activityProvider.notifier).refresh();
      ref.read(bookedTripsProvider.notifier).refresh();
    });
  }

  /// Applies a freshly fetched Supabase session.
  void applySession(SupabaseSessionData data) {
    state = SessionState(
      isAuthenticated: true,
      isRestoring: false,
      profile: data.profile,
      carProfile: data.carProfile ?? _emptyCarProfile,
      allowPublicProfile: data.allowPublicProfile,
    );
    // Request APNs permission + sync the cached device token.
    Future.microtask(_syncPushTokenForActiveSession);
  }

  Future<void> _syncPushTokenForActiveSession() async {
    final push = PushNotificationsService.instance;
    // No prompt here — only re-register if the user already granted
    // notifications. The system prompt is shown later, on the first
    // contextually-relevant action (see [ensurePushPermission]).
    await push.registerIfAlreadyGranted();
    final token = push.latestToken ?? await push.currentDeviceToken();
    if (token != null && state.isAuthenticated) {
      _service.registerPushDeviceToken(token).ignore();
    }
  }

  /// Shows the system push-permission prompt the first time notifications
  /// become relevant — e.g. right after a driver publishes a ride or a
  /// passenger sends a booking request, where they'll want to hear back.
  /// iOS only surfaces the prompt on the first call; later calls are no-ops,
  /// so callers can fire this freely after any such action.
  Future<void> ensurePushPermission() async {
    if (!PushNotificationsService.pushEnabled) return;
    final push = PushNotificationsService.instance;
    await push.requestPermissionAndRegister();
    final token = push.latestToken ?? await push.currentDeviceToken();
    if (token != null && state.isAuthenticated) {
      _service.registerPushDeviceToken(token).ignore();
    }
  }

  /// Master push gate (QA #34). When [enabled] is false we stop the contextual
  /// prompt + tray notifications (via the static gate) and deactivate the
  /// device token so the backend stops pushing to this device.
  Future<void> setPushEnabled(bool enabled) async {
    PushNotificationsService.pushEnabled = enabled;
    final push = PushNotificationsService.instance;
    if (enabled) {
      await _syncPushTokenForActiveSession();
    } else {
      final token = push.latestToken ?? await push.currentDeviceToken();
      if (token != null) {
        _service.unregisterPushDeviceToken(token).ignore();
      }
    }
  }

  Future<void> signOut() async {
    // Deactivate the push token *before* clearing the session. After
    // `_service.signOut()` there is no authenticated user, and
    // `unregisterPushDeviceToken` no-ops in that state (it guards on
    // `currentUser` and RLS would block the update anyway). Doing it afterwards
    // left the row `is_active = true`, so the device kept receiving pushes for
    // the signed-out account.
    final push = PushNotificationsService.instance;
    final token = push.latestToken ?? await push.currentDeviceToken();
    if (token != null) {
      try {
        await _service.unregisterPushDeviceToken(token);
      } catch (_) {
        // Best-effort; sign-out must proceed regardless.
      }
    }
    try {
      await _service.signOut();
    } catch (_) {
      // The auth-state listener still resets to guest on success; ignore.
    }
    state = const SessionState(
      isAuthenticated: false,
      isRestoring: false,
      profile: _guestProfile,
      carProfile: _emptyCarProfile,
      allowPublicProfile: true,
    );
  }

  /// Persists the profile to Supabase and updates the session.
  Future<void> updateProfile(UserProfile profile) async {
    final data = await _service.saveProfile(profile);
    applySession(data);
  }

  /// Persists the vehicle to Supabase and updates the session.
  Future<void> updateCar(CarProfile car) async {
    final saved = await _service.saveVehicle(car);
    state = state.copyWith(carProfile: saved);
  }

  Future<void> setAllowPublicProfile(bool value) async {
    state = state.copyWith(allowPublicProfile: value);
    try {
      await _service.savePrivacySettings(allowPublicProfile: value);
    } catch (_) {
      // Keep the optimistic local value even if the write fails.
    }
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// Whether a real Supabase session exists.
final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(sessionProvider).isAuthenticated);

/// Whether the initial session restore is still in flight.
final isRestoringSessionProvider =
    Provider<bool>((ref) => ref.watch(sessionProvider).isRestoring);

/// The signed-in user (or a blank guest profile when not authenticated).
final currentUserProvider =
    Provider<UserProfile>((ref) => ref.watch(sessionProvider).profile);

/// The current user's vehicle.
final carProfileProvider =
    Provider<CarProfile>((ref) => ref.watch(sessionProvider).carProfile);

/// `AppState.residenceCountry` — driven by the current user's profile.
final residenceCountryProvider = Provider<ResidenceCountry>((ref) {
  return ref.watch(currentUserProvider).countryOfResidence ??
      ResidenceCountry.tajikistan;
});

/// `AppState.isCurrentUser(_:)` as an injectable closure.
final isCurrentUserProvider = Provider<bool Function(UserProfile)>((ref) {
  final me = ref.watch(currentUserProvider);
  return (UserProfile user) {
    if (me.backendId != null && user.backendId != null) {
      return me.backendId == user.backendId;
    }
    return me.id == user.id;
  };
});

// ---------------------------------------------------------------------------
// Trips — loaded from Supabase, reloaded when the session changes
// ---------------------------------------------------------------------------

/// `AppState.trips.bookedTrips` — the user's published rides and bookings.
class BookedTripsNotifier extends Notifier<List<BookedTrip>> {
  @override
  List<BookedTrip> build() {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (isAuthenticated) Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      state = await ref.read(supabaseServiceProvider).fetchBookedTrips();
    } catch (_) {
      // Keep whatever is already loaded — a failed refresh must not blank the
      // list (caused content to disappear during pull-to-refresh).
    }
  }

  Future<void> refresh() => _load();

  /// Optimistically prepends a freshly published driver trip.
  void add(BookedTrip trip) => state = [trip, ...state];

  void setSearchPassengers(String tripId, bool enabled) {
    state = [
      for (final trip in state)
        if (trip.id == tripId)
          trip.copyWith(searchPassengersEnabled: enabled)
        else
          trip,
    ];
    final ride = state.firstWhere((t) => t.id == tripId).ride;
    final rideId = ride.backendId;
    if (rideId != null) {
      ref
          .read(supabaseServiceProvider)
          .updateRideSearchPassengers(rideId: rideId, enabled: enabled)
          .ignore();
    }
  }
}

final bookedTripsProvider =
    NotifierProvider<BookedTripsNotifier, List<BookedTrip>>(
  BookedTripsNotifier.new,
);

/// `AppState.trips.myPassengerRequests` — passenger requests the user created.
class MyPassengerRequestsNotifier extends Notifier<List<PassengerRequest>> {
  @override
  List<PassengerRequest> build() {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (isAuthenticated) Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      state =
          await ref.read(supabaseServiceProvider).fetchMyPassengerRequests();
    } catch (_) {
      // Keep existing requests on a failed refresh (don't blank the list).
    }
  }

  Future<void> refresh() => _load();

  void add(PassengerRequest request) => state = [request, ...state];

  /// Cancels the passenger's own request and drops it from the list (QA #61).
  /// Rethrows so the UI can surface a failure.
  Future<void> cancel(PassengerRequest request) async {
    await ref.read(supabaseServiceProvider).cancelPassengerRequest(request);
    state = state.where((r) => r.id != request.id).toList();
  }
}

final myPassengerRequestsProvider =
    NotifierProvider<MyPassengerRequestsNotifier, List<PassengerRequest>>(
  MyPassengerRequestsNotifier.new,
);

/// The user's route ride-alerts ("notify me when a ride appears on this route").
class RideAlertsNotifier extends Notifier<List<RideAlert>> {
  @override
  List<RideAlert> build() {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (isAuthenticated) Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    try {
      state = await ref.read(supabaseServiceProvider).fetchRideAlerts();
    } catch (_) {
      // Keep whatever is loaded.
    }
  }

  Future<void> refresh() => _load();

  RideAlert? alertFor(String fromCity, String toCity) {
    for (final a in state) {
      if (a.fromCity == fromCity && a.toCity == toCity) return a;
    }
    return null;
  }

  Future<void> create(String fromCity, String toCity) async {
    final alert = await ref
        .read(supabaseServiceProvider)
        .createRideAlert(fromCity: fromCity, toCity: toCity);
    if (!state.any((a) => a.id == alert.id)) state = [alert, ...state];
  }

  Future<void> remove(String id) async {
    await ref.read(supabaseServiceProvider).deleteRideAlert(id);
    state = state.where((a) => a.id != id).toList();
  }
}

final rideAlertsProvider =
    NotifierProvider<RideAlertsNotifier, List<RideAlert>>(
  RideAlertsNotifier.new,
);

// ---------------------------------------------------------------------------
// Settings — local (the SwiftUI app also persists these to Supabase/UserDefaults)
// ---------------------------------------------------------------------------

/// `AppState.notificationSettings` — persisted via [AppPreferencesStore],
/// keyed by the current user's backend id (`'guest'` when signed out). Mirrors
/// the Swift `AppPreferencesStore` UserDefaults bundle.
class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    ref.listen<UserProfile>(currentUserProvider, (_, profile) {
      _load(profile.backendId);
    });
    Future.microtask(
        () => _load(ref.read(currentUserProvider).backendId));
    return const NotificationSettings();
  }

  Future<void> _load(String? backendId) async {
    final cached = await AppPreferencesStore.load(backendId: backendId);
    if (cached != null) state = cached.notifications;
    PushNotificationsService.pushEnabled = state.pushEnabled;
  }

  void update(NotificationSettings settings) {
    state = settings;
    PushNotificationsService.pushEnabled = settings.pushEnabled;
    _persist();
  }

  void _persist() {
    final backendId = ref.read(currentUserProvider).backendId;
    AppPreferencesStore.save(
      backendId: backendId,
      notifications: state,
      appearance: ref.read(appearanceSettingsProvider),
      privacy: PrivacySettings(
        allowPublicProfile: ref.read(sessionProvider).allowPublicProfile,
      ),
    );
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

class AppearanceSettingsNotifier extends Notifier<AppearanceSettings> {
  @override
  AppearanceSettings build() {
    ref.listen<UserProfile>(currentUserProvider, (_, profile) {
      _load(profile.backendId);
    });
    Future.microtask(
        () => _load(ref.read(currentUserProvider).backendId));
    return const AppearanceSettings();
  }

  Future<void> _load(String? backendId) async {
    final cached = await AppPreferencesStore.load(backendId: backendId);
    if (cached != null) state = cached.appearance;
  }

  void update(AppearanceSettings settings) {
    state = settings;
    _persist();
  }

  void _persist() {
    final backendId = ref.read(currentUserProvider).backendId;
    AppPreferencesStore.save(
      backendId: backendId,
      notifications: ref.read(notificationSettingsProvider),
      appearance: state,
      privacy: PrivacySettings(
        allowPublicProfile: ref.read(sessionProvider).allowPublicProfile,
      ),
    );
  }
}

final appearanceSettingsProvider =
    NotifierProvider<AppearanceSettingsNotifier, AppearanceSettings>(
  AppearanceSettingsNotifier.new,
);

/// Privacy mirrors the session's `allowPublicProfile`.
final privacySettingsProvider = Provider<PrivacySettings>((ref) {
  return PrivacySettings(
    allowPublicProfile: ref.watch(sessionProvider).allowPublicProfile,
  );
});

/// `AppState.availableTravelCountries`.
final availableTravelCountriesProvider = Provider<List<LocationCountry>>(
  (ref) => LocationDirectory.countries,
);

// ---------------------------------------------------------------------------
// Blocking (App Store Guideline 1.2)
// ---------------------------------------------------------------------------

/// The set of user ids the signed-in user is in a block relationship with, in
/// either direction. Other providers (chat, marketplace) watch this to hide
/// blocked users' content. Loaded on sign-in and updated optimistically when
/// the user blocks/unblocks someone.
class BlockedUsersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (isAuthenticated) {
      Future.microtask(_load);
    }
    return <String>{};
  }

  Future<void> _load() async {
    try {
      state = await ref.read(supabaseServiceProvider).fetchBlockedUserIds();
    } catch (_) {
      // Best-effort — filtering simply does nothing until this succeeds.
    }
  }

  bool isBlocked(String userId) => state.contains(userId);

  /// Blocks [userId], hiding their content immediately. Rethrows on failure so
  /// the caller can surface an error (state is rolled back first).
  Future<void> block(String userId) async {
    if (state.contains(userId)) return;
    state = {...state, userId};
    try {
      await ref.read(supabaseServiceProvider).blockUser(userId);
    } catch (e) {
      state = {...state}..remove(userId);
      rethrow;
    }
  }

  /// Unblocks [userId]. Rethrows on failure (state is rolled back first).
  Future<void> unblock(String userId) async {
    if (!state.contains(userId)) return;
    state = {...state}..remove(userId);
    try {
      await ref.read(supabaseServiceProvider).unblockUser(userId);
    } catch (e) {
      state = {...state, userId};
      rethrow;
    }
  }

  Future<void> refresh() => _load();
}

final blockedUserIdsProvider =
    NotifierProvider<BlockedUsersNotifier, Set<String>>(
  BlockedUsersNotifier.new,
);

// ---------------------------------------------------------------------------
// Marketplace (rides + passenger requests + search history)
// ---------------------------------------------------------------------------

class MarketplaceState {
  const MarketplaceState({
    required this.rides,
    required this.passengerRequests,
    required this.searchHistory,
    this.isLoading = false,
  });

  final List<Ride> rides;
  final List<PassengerRequest> passengerRequests;
  final List<LocationSearchHistoryItem> searchHistory;
  final bool isLoading;

  static const empty = MarketplaceState(
    rides: [],
    passengerRequests: [],
    searchHistory: [],
    isLoading: true,
  );

  MarketplaceState copyWith({
    List<Ride>? rides,
    List<PassengerRequest>? passengerRequests,
    List<LocationSearchHistoryItem>? searchHistory,
    bool? isLoading,
  }) {
    return MarketplaceState(
      rides: rides ?? this.rides,
      passengerRequests: passengerRequests ?? this.passengerRequests,
      searchHistory: searchHistory ?? this.searchHistory,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MarketplaceNotifier extends Notifier<MarketplaceState> {
  // The full, unfiltered fetch results. `state` exposes these with blocked
  // users removed; keeping the originals lets us re-filter on block/unblock
  // without a network round-trip.
  List<Ride> _allRides = const [];
  List<PassengerRequest> _allRequests = const [];

  @override
  MarketplaceState build() {
    // Defer so the notifier is fully initialised before `_load` reads `state`.
    Future.microtask(_load);
    // Refresh history when auth state changes.
    ref.listen<bool>(isAuthenticatedProvider, (_, isAuthed) {
      if (isAuthed) Future.microtask(_loadSearchHistory);
    });
    // Re-filter the visible feed whenever the blocked set changes — no refetch.
    ref.listen<Set<String>>(blockedUserIdsProvider, (_, _) => _applyBlocked());
    return MarketplaceState.empty;
  }

  List<Ride> _filterRides(List<Ride> rides) {
    final blocked = ref.read(blockedUserIdsProvider);
    if (blocked.isEmpty) return rides;
    return rides
        .where((r) =>
            r.driver.backendId == null ||
            !blocked.contains(r.driver.backendId))
        .toList();
  }

  List<PassengerRequest> _filterRequests(List<PassengerRequest> requests) {
    final blocked = ref.read(blockedUserIdsProvider);
    if (blocked.isEmpty) return requests;
    return requests
        .where((r) =>
            r.passenger.backendId == null ||
            !blocked.contains(r.passenger.backendId))
        .toList();
  }

  /// Re-derives the visible rides/requests from the cached full lists using the
  /// current blocked set. Called when the blocked set changes.
  void _applyBlocked() {
    state = state.copyWith(
      rides: _filterRides(_allRides),
      passengerRequests: _filterRequests(_allRequests),
    );
  }

  /// Mirrors `SupabaseService.fetchRides` / `fetchPassengerRequests`.
  Future<void> _load() async {
    final service = ref.read(supabaseServiceProvider);
    state = state.copyWith(isLoading: true);
    try {
      // Fetch rides and requests concurrently to halve the wait.
      final results = await Future.wait([
        service.fetchRides(),
        service.fetchPassengerRequests(),
      ]);
      _allRides = results[0] as List<Ride>;
      _allRequests = results[1] as List<PassengerRequest>;
      state = state.copyWith(
        rides: _filterRides(_allRides),
        passengerRequests: _filterRequests(_allRequests),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
    // Search history is fetched in parallel so the home screen has it ready.
    Future.microtask(_loadSearchHistory);
  }

  /// Ported from `SupabaseService.fetchSearchHistory`. Replaces the local
  /// history with whatever the backend last recorded for this user.
  Future<void> _loadSearchHistory() async {
    if (!ref.read(isAuthenticatedProvider)) return;
    try {
      final rows = await ref
          .read(supabaseServiceProvider)
          .fetchSearchHistory();
      final items = [
        for (final row in rows)
          LocationSearchHistoryItem(from: row.key, to: row.value),
      ];
      state = state.copyWith(searchHistory: items);
    } catch (_) {
      // History is best-effort; the local list still works.
    }
  }

  Future<void> refresh() => _load();

  /// Like [refresh] but rethrows on failure so callers (e.g. the search flow)
  /// can tell the user we're offline instead of silently showing an empty
  /// result set (QA #59).
  Future<void> refreshOrThrow() async {
    final service = ref.read(supabaseServiceProvider);
    state = state.copyWith(isLoading: true);
    try {
      // Fetch rides and requests concurrently — this is the search path, so the
      // wait directly drives how long "Поиск" spins (slow-search fix).
      final results = await Future.wait([
        service.fetchRides(),
        service.fetchPassengerRequests(),
      ]);
      _allRides = results[0] as List<Ride>;
      _allRequests = results[1] as List<PassengerRequest>;
      state = state.copyWith(
        rides: _filterRides(_allRides),
        passengerRequests: _filterRequests(_allRequests),
        isLoading: false,
      );
      Future.microtask(_loadSearchHistory);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Mirrors `AppSearchHistoryDomain.recordSearch` — newest first, de-duped,
  /// capped at 10 entries — and persists to Supabase (`search_history`).
  void recordSearch(LocationSearchHistoryItem item) {
    final history = [
      item,
      ...state.searchHistory.where(
        (existing) => !(existing.from == item.from && existing.to == item.to),
      ),
    ].take(10).toList();
    state = state.copyWith(searchHistory: history);
    if (ref.read(isAuthenticatedProvider)) {
      ref
          .read(supabaseServiceProvider)
          .recordSearchHistory(from: item.from, to: item.to)
          .ignore();
    }
  }

  /// Optimistically prepends a freshly published ride.
  void addRide(Ride ride) {
    _allRides = [ride, ..._allRides];
    state = state.copyWith(rides: _filterRides(_allRides));
  }

  /// Optimistically prepends a freshly published passenger request.
  void addPassengerRequest(PassengerRequest request) {
    _allRequests = [request, ..._allRequests];
    state = state.copyWith(passengerRequests: _filterRequests(_allRequests));
  }
}

final marketplaceProvider =
    NotifierProvider<MarketplaceNotifier, MarketplaceState>(
  MarketplaceNotifier.new,
);

// ---------------------------------------------------------------------------
// Home search form
// ---------------------------------------------------------------------------

class HomeSearchNotifier extends Notifier<HomeSearchState> {
  @override
  HomeSearchState build() => HomeSearchState();

  void setFrom(LocationSelection location) {
    state = state.copyWith(
      search: state.search.copyWith(fromLocation: location),
      hasSelectedFrom: true,
    );
  }

  void setTo(LocationSelection location) {
    state = state.copyWith(
      search: state.search.copyWith(toLocation: location),
      hasSelectedTo: true,
    );
  }

  void setDate(DateTime date) {
    state = state.copyWith(
      search: state.search.copyWith(date: date),
      hasSelectedDate: true,
    );
  }

  /// Reset to the "Все даты" default (keeps the stored anchor date).
  void clearDate() {
    state = state.copyWith(hasSelectedDate: false);
  }

  void setPassengers(int passengers) {
    state = state.copyWith(
      search: state.search.copyWith(passengers: passengers.clamp(1, 4)),
    );
  }

  void applyRoute(LocationSelection from, LocationSelection to) {
    state = state.applyRoute(from, to);
  }

  void swapLocations() {
    state = state.swapLocations();
  }
}

final homeSearchProvider =
    NotifierProvider<HomeSearchNotifier, HomeSearchState>(
  HomeSearchNotifier.new,
);

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}

final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, AppTab>(SelectedTabNotifier.new);

/// Optional handler the foreground tab can register so the shell's Android
/// system-back button steps through in-tab state (e.g. the create-ride
/// wizard) instead of backgrounding the app. Returns true when it consumed
/// the back press. Only the create tab registers one today.
class InTabBackHandlerNotifier extends Notifier<bool Function()?> {
  @override
  bool Function()? build() => null;

  void set(bool Function()? handler) => state = handler;
}

final inTabBackHandlerProvider =
    NotifierProvider<InTabBackHandlerNotifier, bool Function()?>(
  InTabBackHandlerNotifier.new,
);

/// Bumped every time the "+" (create) tab is tapped so the create-ride screen
/// can reset its wizard to the start — tapping "+" always opens a fresh form,
/// never a half-finished step left over from last time.
class CreateTabResetNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final createTabResetProvider =
    NotifierProvider<CreateTabResetNotifier, int>(CreateTabResetNotifier.new);

/// One-shot request to open a specific My Trips section — e.g. after a booking
/// we jump the rider to «Запросы» / «Активные». My Trips consumes and clears it.
class RequestedTripsSectionNotifier extends Notifier<TripSection?> {
  @override
  TripSection? build() => null;

  void request(TripSection section) => state = section;

  void clear() => state = null;
}

final requestedTripsSectionProvider =
    NotifierProvider<RequestedTripsSectionNotifier, TripSection?>(
  RequestedTripsSectionNotifier.new,
);

class SelectedHomeSectionNotifier extends Notifier<HomeListingSection> {
  @override
  HomeListingSection build() => HomeListingSection.rides;

  void select(HomeListingSection section) => state = section;
}

final selectedHomeSectionProvider =
    NotifierProvider<SelectedHomeSectionNotifier, HomeListingSection>(
  SelectedHomeSectionNotifier.new,
);
