import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, AuthChangeEvent;

import '../core/preferences/preferences_store.dart';
import '../core/push/push_notifications_service.dart';
import '../core/supabase/supabase_service.dart';
import '../models/app_settings.dart';
import '../models/app_tab.dart';
import '../models/booked_trip.dart';
import '../models/car_profile.dart';
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

  @override
  SessionState build() {
    _restore();
    _listenToAuthChanges();
    _listenToPushTokens();
    ref.onDispose(() {
      _pushTokenSub?.cancel();
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
      if (ref.read(isAuthenticatedProvider)) {
        _service.registerPushDeviceToken(token).ignore();
      }
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
    await push.requestPermissionAndRegister();
    final token = push.latestToken ?? await push.currentDeviceToken();
    if (token != null && ref.read(isAuthenticatedProvider)) {
      _service.registerPushDeviceToken(token).ignore();
    }
  }

  Future<void> signOut() async {
    final token = PushNotificationsService.instance.latestToken;
    try {
      await _service.signOut();
    } catch (_) {
      // The auth-state listener still resets to guest on success; ignore.
    }
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
      state = const [];
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
      state = const [];
    }
  }

  Future<void> refresh() => _load();

  void add(PassengerRequest request) => state = [request, ...state];
}

final myPassengerRequestsProvider =
    NotifierProvider<MyPassengerRequestsNotifier, List<PassengerRequest>>(
  MyPassengerRequestsNotifier.new,
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
  }

  void update(NotificationSettings settings) {
    state = settings;
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
  @override
  MarketplaceState build() {
    // Defer so the notifier is fully initialised before `_load` reads `state`.
    Future.microtask(_load);
    // Refresh history when auth state changes.
    ref.listen<bool>(isAuthenticatedProvider, (_, isAuthed) {
      if (isAuthed) Future.microtask(_loadSearchHistory);
    });
    return MarketplaceState.empty;
  }

  /// Mirrors `SupabaseService.fetchRides` / `fetchPassengerRequests`.
  Future<void> _load() async {
    final service = ref.read(supabaseServiceProvider);
    state = state.copyWith(isLoading: true);
    try {
      final rides = await service.fetchRides();
      final requests = await service.fetchPassengerRequests();
      state = state.copyWith(
        rides: rides,
        passengerRequests: requests,
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
    state = state.copyWith(rides: [ride, ...state.rides]);
  }

  /// Optimistically prepends a freshly published passenger request.
  void addPassengerRequest(PassengerRequest request) {
    state = state.copyWith(
      passengerRequests: [request, ...state.passengerRequests],
    );
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
    state = state.copyWith(search: state.search.copyWith(date: date));
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

class SelectedHomeSectionNotifier extends Notifier<HomeListingSection> {
  @override
  HomeListingSection build() => HomeListingSection.rides;

  void select(HomeListingSection section) => state = section;
}

final selectedHomeSectionProvider =
    NotifierProvider<SelectedHomeSectionNotifier, HomeListingSection>(
  SelectedHomeSectionNotifier.new,
);
