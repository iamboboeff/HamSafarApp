import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../core/app_navigator.dart';
import '../core/preferences/preferences_store.dart';
import '../core/supabase/supabase_chat_service.dart';
import '../domain/date_formatter.dart';
import '../domain/trip_lifecycle.dart';
import '../models/booked_trip.dart';
import '../models/chat.dart';
import '../models/passenger_request.dart';
import '../models/trip_enums.dart';
import '../models/user_profile.dart';
import 'app_state.dart';

/// The Supabase-backed chat service. Mirrors `supabaseServiceProvider`.
final supabaseChatServiceProvider = Provider<SupabaseChatService>(
  (ref) => SupabaseChatService(Supabase.instance.client),
);

/// Chat list state — ported from the `ChatStore` fields the UI observes.
class ChatState {
  const ChatState({
    required this.threads,
    required this.isListLoading,
    this.pendingBooking,
    this.reviewPrompt,
  });

  final List<ChatThread> threads;
  final bool isListLoading;

  /// The pending-booking banner above the composer in chat detail. Set when
  /// the active thread is the chat with a passenger who has a pending booking
  /// against one of the signed-in driver's rides; cleared otherwise.
  final PendingChatBookingContext? pendingBooking;

  /// The "leave a review" banner above the composer. Set after a completed
  /// driver-led trip while the 7-day window is open and no review yet exists.
  final ReviewPromptContext? reviewPrompt;

  static const empty = ChatState(threads: [], isListLoading: false);

  ChatState copyWith({
    List<ChatThread>? threads,
    bool? isListLoading,
    Object? pendingBooking = _unset,
    Object? reviewPrompt = _unset,
  }) {
    return ChatState(
      threads: threads ?? this.threads,
      isListLoading: isListLoading ?? this.isListLoading,
      pendingBooking: identical(pendingBooking, _unset)
          ? this.pendingBooking
          : pendingBooking as PendingChatBookingContext?,
      reviewPrompt: identical(reviewPrompt, _unset)
          ? this.reviewPrompt
          : reviewPrompt as ReviewPromptContext?,
    );
  }

  static const _unset = Object();
}

/// Ported from `ChatStore` (`ChatStore.swift`) plus the chat slices of
/// `ContentCoordinatorDataDomain.swift` — find-or-create, send, read-state and
/// archive now go through [SupabaseChatService], and the merge/dedup
/// reconciliation keeps optimistic local threads consistent with fetches and
/// realtime updates.
class ChatNotifier extends Notifier<ChatState> {
  final Map<String, String> _pendingDrafts = {};
  String? _activeThreadId;
  Timer? _syncDebounce;
  bool _mounted = true;
  // Per-thread unread baseline, so a realtime bump in a non-open chat can fire
  // an in-app banner once (and not on initial load).
  final Map<String, int> _lastUnread = {};

  @override
  ChatState build() {
    _mounted = true;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final service = ref.read(supabaseChatServiceProvider);

    // Sync trip lifecycle system messages when the booked-trips list changes.
    ref.listen<List<BookedTrip>>(
      bookedTripsProvider,
      (previous, next) {
        if (!_mounted) return;
        Future.microtask(() => _syncTripLifecycle(previous ?? const [], next));
      },
    );

    // Hide blocked users' chats the instant they're blocked; restore them on
    // unblock (App Store Guideline 1.2).
    ref.listen<Set<String>>(
      blockedUserIdsProvider,
      (previous, next) => _onBlockedChanged(previous ?? const {}, next),
    );

    ref.onDispose(() {
      _mounted = false;
      _syncDebounce?.cancel();
      service.stopChatRealtimeSync();
    });

    if (isAuthenticated) {
      Future.microtask(_initialize);
      return const ChatState(threads: [], isListLoading: true);
    }
    service.stopChatRealtimeSync();
    return ChatState.empty;
  }

  SupabaseChatService get _service => ref.read(supabaseChatServiceProvider);

  Future<void> _initialize() async {
    await loadChats();
    await _startRealtime();
  }

  // ---------------------------------------------------------------------------
  // Loading + realtime
  // ---------------------------------------------------------------------------

  /// Ported from `ContentCoordinatorDataDomain.loadChats`.
  ///
  /// Wraps the fetch in a 25s timeout + `finally` block so the spinner can
  /// never be stuck forever — without these, a hung Supabase request (slow
  /// network, RLS lock, expired JWT) would leave `isListLoading=true` and
  /// the chat list would show an indefinite spinner on the empty UI.
  Future<void> loadChats() async {
    if (state.threads.isEmpty && !state.isListLoading) {
      state = state.copyWith(isListLoading: true);
    }
    try {
      final fetched =
          await _service.fetchChats().timeout(const Duration(seconds: 25));
      if (!_mounted) return;
      _mergeChats(_withoutBlocked(fetched));
      // Seed the unread baseline so banners only fire on *new* messages.
      for (final t in state.threads) {
        _lastUnread[t.id] = t.unreadCount;
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[chat] loadChats failed: $e\n$st');
    } finally {
      if (_mounted) {
        state = state.copyWith(isListLoading: false);
      }
    }
  }

  Future<void> refresh() => loadChats();

  /// Removes threads whose counterpart the user has blocked (either direction).
  List<ChatThread> _withoutBlocked(List<ChatThread> threads) {
    final blocked = ref.read(blockedUserIdsProvider);
    if (blocked.isEmpty) return threads;
    return threads
        .where((t) =>
            t.participantBackendId == null ||
            !blocked.contains(t.participantBackendId))
        .toList();
  }

  bool _isThreadBlocked(ChatThread thread) {
    final pid = thread.participantBackendId;
    if (pid == null) return false;
    return ref.read(blockedUserIdsProvider).contains(pid);
  }

  /// Drops now-blocked threads from the list immediately, and refetches when a
  /// user is unblocked so their thread reappears.
  void _onBlockedChanged(Set<String> previous, Set<String> next) {
    if (!_mounted) return;
    if (next.isNotEmpty) {
      final filtered = state.threads
          .where((t) =>
              t.participantBackendId == null ||
              !next.contains(t.participantBackendId))
          .toList();
      if (filtered.length != state.threads.length) {
        state = state.copyWith(threads: filtered);
      }
    }
    if (previous.difference(next).isNotEmpty) {
      Future.microtask(loadChats);
    }
  }

  Future<void> _startRealtime() async {
    try {
      await _service.startChatRealtimeSync(_handleRealtimeSync);
    } catch (_) {
      // Realtime is best-effort; explicit refetches still keep chat fresh.
    }
  }

  /// Debounced so a burst of postgres changes triggers a single sync pass.
  void _handleRealtimeSync(String? threadId) {
    _syncDebounce?.cancel();
    // Short debounce just coalesces rapid bursts; kept small so an incoming
    // message in an open chat appears almost instantly.
    _syncDebounce = Timer(const Duration(milliseconds: 120), () {
      _performSync(threadId);
    });
  }

  /// Ported from `ContentCoordinatorDataDomain.handleChatSync`.
  Future<void> _performSync(String? threadId) async {
    if (!_mounted) return;
    if (threadId != null) {
      final isActive = state.threads
              .where((t) => t.id == _activeThreadId)
              .map((t) => t.backendId)
              .cast<String?>()
              .firstWhere((_) => true, orElse: () => null) ==
          threadId;
      try {
        final refreshed = isActive
            ? await _service.fetchChat(threadId)
            : await _service.fetchChatSummary(threadId);
        if (refreshed != null && _mounted) {
          // A blocked user's realtime message must not re-surface the thread.
          if (_isThreadBlocked(refreshed)) return;
          _mergeChat(refreshed);
          if (!isActive) _maybeBanner(refreshed);
        }
      } catch (_) {
        // Ignore — a later sync or explicit refresh recovers.
      }
      return;
    }
    await loadChats();
  }

  /// Fires an in-app banner once when a non-open chat gains a new unread
  /// message (so the user is notified like a messenger while elsewhere).
  void _maybeBanner(ChatThread thread) {
    final previous = _lastUnread[thread.id] ?? 0;
    final current = thread.unreadCount;
    _lastUnread[thread.id] = current;
    if (current > previous && current > 0) {
      inAppMessages.add(InAppMessage(
        localThreadId: thread.id,
        title: thread.name,
        body: thread.preview,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Lookups + drafts
  // ---------------------------------------------------------------------------

  String? consumePendingDraft(String threadId) =>
      _pendingDrafts.remove(threadId);

  ChatThread? threadById(String id) {
    for (final thread in state.threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  /// Publishes the current user's presence in [localThreadId] so the other
  /// participant sees "в сети" / "печатает..." (heartbeated by the chat screen).
  void updatePresence(String localThreadId, {bool typing = false}) {
    final backendId = threadById(localThreadId)?.backendId;
    if (backendId == null) return;
    _service.updateChatPresence(threadId: backendId, isTyping: typing).ignore();
  }

  /// Clears presence when leaving a chat (the row then goes stale → offline).
  void clearPresence() {
    _service.clearChatPresence().ignore();
  }

  void setActiveThread(String? threadId) {
    _activeThreadId = threadId;
    if (threadId == null) {
      if (state.pendingBooking != null || state.reviewPrompt != null) {
        state = state.copyWith(pendingBooking: null, reviewPrompt: null);
      }
      return;
    }
    Future.microtask(() => _refreshPendingBooking(threadId));
    Future.microtask(() => _refreshReviewPrompt(threadId));
  }

  void clearActiveThread() {
    _activeThreadId = null;
    if (state.pendingBooking != null || state.reviewPrompt != null) {
      state = state.copyWith(pendingBooking: null, reviewPrompt: null);
    }
  }

  /// Loads the full thread (most recent message page) from the backend, then
  /// refreshes the pending-booking banner. Ported from
  /// `ChatDetailActionsDomain.loadThread`.
  Future<void> loadThread(String threadId) async {
    final backendId = threadById(threadId)?.backendId;
    if (backendId == null) return;
    try {
      final fetched = await _service.fetchChat(backendId);
      if (fetched != null && _mounted) _mergeChat(fetched);
    } catch (_) {
      // Ignore — the cached thread still renders.
    }
    await _refreshPendingBooking(threadId);
    await _refreshReviewPrompt(threadId);
  }

  /// Ported from `ChatDetailActionsDomain.fetchReviewPromptContext`. Looks for
  /// a completed driver-led trip with this chat partner whose 7-day review
  /// window is still open and no review yet exists, and stores it in state
  /// when [threadId] is still the active thread.
  Future<void> _refreshReviewPrompt(String threadId) async {
    final thread = threadById(threadId);
    final participantId = thread?.participantBackendId;
    if (thread == null || participantId == null) {
      if (_activeThreadId == threadId && state.reviewPrompt != null) {
        state = state.copyWith(reviewPrompt: null);
      }
      return;
    }

    final bookedTrips = ref.read(bookedTripsProvider);
    final normalizedThreadRoute = normalizedChatRoute(thread.route);
    BookedTrip? matched;
    for (final trip in bookedTrips) {
      if (trip.role != TripRole.passenger) continue;
      if (!trip.isCompleted || trip.isCancelled) continue;
      final tripRideId = trip.ride.backendId;
      final threadRideId = thread.rideId;
      if (threadRideId != null && tripRideId != null &&
          threadRideId == tripRideId) {
        matched = trip;
        break;
      }
      if (trip.ride.driver.backendId == participantId &&
          normalizedChatRoute(
                  '${trip.ride.fromCity} — ${trip.ride.toCity}') ==
              normalizedThreadRoute) {
        matched = trip;
        break;
      }
    }
    if (matched == null) {
      if (_activeThreadId == threadId && state.reviewPrompt != null) {
        state = state.copyWith(reviewPrompt: null);
      }
      return;
    }
    final rideId = matched.ride.backendId;
    final revieweeId = matched.ride.driver.backendId;
    if (rideId == null || revieweeId == null) return;

    const reviewWindow = Duration(days: 7);
    final age = DateTime.now().difference(matched.ride.estimatedArrivalDate);
    if (age.isNegative || age > reviewWindow) return;

    // Ported from `ContentCoordinatorTripLifecycle.shouldPresentReviewPrompt`:
    // count == 0 → show immediately; count == 1 → wait 6h; count >= 2 → hide.
    final promptId = '$rideId-$revieweeId';
    final dismissals =
        await ReviewPromptDismissalStore.dismissalCount(promptId);
    if (dismissals >= 2) return;
    if (dismissals == 1 && age < const Duration(hours: 6)) return;

    try {
      final existing = await ref
          .read(supabaseServiceProvider)
          .fetchMyRideReview(rideId: rideId, revieweeId: revieweeId);
      if (existing != null) return;
    } catch (_) {
      return;
    }
    if (!_mounted || _activeThreadId != threadId) return;
    state = state.copyWith(
      reviewPrompt: ReviewPromptContext(
        rideId: rideId,
        revieweeId: revieweeId,
        targetName: matched.ride.driver.name,
        routeText: '${matched.ride.fromCity} — ${matched.ride.toCity}',
      ),
    );
  }

  /// Ported from `ContentCoordinatorTripLifecycle.recordReviewPromptDismissal`.
  /// Called when the user taps the close button on the review-prompt banner.
  Future<void> dismissReviewPrompt() async {
    final prompt = state.reviewPrompt;
    if (prompt == null) return;
    state = state.copyWith(reviewPrompt: null);
    await ReviewPromptDismissalStore.recordDismissal(
      '${prompt.rideId}-${prompt.revieweeId}',
    );
  }

  /// Ported from `ContentCoordinatorTripLifecycle.syncTripLifecycleMessages` —
  /// when the booked-trips list changes, posts at-most-one "поездка началась /
  /// завершена / оставьте отзыв" system message into every chat thread whose
  /// route matches the affected trip.
  Future<void> _syncTripLifecycle(
    List<BookedTrip> previous,
    List<BookedTrip> current,
  ) async {
    final threads = state.threads;
    if (threads.isEmpty) return;
    try {
      await TripLifecycleDomain.sync(
        previous: previous,
        current: current,
        chatService: _service,
        matchingThreadBackendIds: (trip) =>
            TripLifecycleDomain.matchingThreadBackendIds(
                trip: trip, threads: threads),
        hasOwnReview: (trip) async {
          final rideId = trip.ride.backendId;
          final revieweeId = trip.ride.driver.backendId;
          if (rideId == null || revieweeId == null) return true;
          try {
            final existing = await ref
                .read(supabaseServiceProvider)
                .fetchMyRideReview(
                  rideId: rideId,
                  revieweeId: revieweeId,
                );
            return existing != null;
          } catch (_) {
            return true;
          }
        },
      );
    } catch (_) {
      // Lifecycle sync is non-critical.
    }
  }

  /// Ported from `ChatDetailActionsDomain.submitReview`. Returns null on
  /// success, or a Russian error string suitable for an alert.
  Future<String?> submitReview({
    required double rating,
    required String comment,
  }) async {
    final prompt = state.reviewPrompt;
    if (prompt == null) return 'Запрос отзыва больше не доступен.';
    try {
      await ref.read(supabaseServiceProvider).submitRideReview(
            rideId: prompt.rideId,
            revieweeId: prompt.revieweeId,
            rating: rating,
            comment: comment.trim(),
          );
      if (!_mounted) return null;
      state = state.copyWith(reviewPrompt: null);
      await ReviewPromptDismissalStore.markSubmitted(
        '${prompt.rideId}-${prompt.revieweeId}',
      );
      return null;
    } catch (e) {
      return 'Не удалось отправить отзыв: $e';
    }
  }

  /// Ported from `ChatDetailActionsDomain.fetchPendingBookingContext`. Fetches
  /// the pending booking for the chat partner (if any) and stores it in state
  /// when [threadId] is still the active thread.
  Future<void> _refreshPendingBooking(String threadId) async {
    final thread = threadById(threadId);
    final participantId = thread?.participantBackendId;
    if (thread == null || participantId == null) {
      if (_activeThreadId == threadId && state.pendingBooking != null) {
        state = state.copyWith(pendingBooking: null);
      }
      return;
    }
    PendingChatBookingContext? context;
    try {
      context = await _service.fetchPendingBookingContext(
        participantId: participantId,
        route: thread.route,
      );
    } catch (_) {
      context = null;
    }
    if (!_mounted || _activeThreadId != threadId) return;
    state = state.copyWith(pendingBooking: context);
  }

  /// Ported from `ChatDetailActionsDomain.loadOlderMessages` — prepends the
  /// preceding page of messages. Returns whether anything new was loaded.
  Future<bool> loadOlderMessages(String threadId) async {
    final thread = threadById(threadId);
    if (thread == null) return false;
    final backendId = thread.backendId;
    if (backendId == null || thread.messages.isEmpty) return false;

    final before = thread.messages.first.sentAt;
    try {
      final older = await _service.fetchOlderChatMessages(backendId, before);
      if (older.isEmpty || !_mounted) return false;
      final existingBackendIds =
          thread.messages.map((m) => m.backendId).whereType<String>().toSet();
      final fresh = older
          .where((m) =>
              m.backendId == null || !existingBackendIds.contains(m.backendId))
          .toList();
      if (fresh.isEmpty) return false;
      thread.messages = [...fresh, ...thread.messages];
      state = state.copyWith(threads: [...state.threads]);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Find-or-create (ported from ChatStore.openChat)
  // ---------------------------------------------------------------------------

  String _contextText(String route, String departureText) =>
      'Маршрут: $route. $departureText.';

  void _resort() {
    final sorted = [...state.threads]
      ..sort((a, b) => b.latestActivityDate.compareTo(a.latestActivityDate));
    state = state.copyWith(threads: sorted);
  }

  /// Ported from `ChatStore.openChat(for request:)`.
  String openChatForRequest(PassengerRequest request) {
    final route = normalizedChatRoute('${request.fromCity} - ${request.toCity}');
    final contextText = _contextText(route, request.departureText);
    final initialDraft =
        'Здравствуйте! Могу взять ваш запрос по маршруту $route.';
    final now = DateTime.now();

    final existing = _findThread(
      passengerRequestId: request.backendId,
      name: request.passenger.name,
      route: route,
    );
    if (existing != null) {
      existing.appendSystemMessageIfNeeded(
        contextText,
        timeLabel: DateTextFormatter.time(now),
        dayLabel: chatDayLabel(now),
      );
      if (!existing.hasStartedConversation) {
        _pendingDrafts[existing.id] = initialDraft;
      } else {
        _pendingDrafts.remove(existing.id);
      }
      _resort();
      return existing.id;
    }

    final thread = ChatThread(
      id: 'chat-${now.microsecondsSinceEpoch}',
      passengerRequestId: request.backendId,
      participantBackendId: request.passenger.backendId,
      name: request.passenger.name,
      route: route,
      preview: 'Новый диалог',
      timeLabel: 'Сейчас',
      tripStatus: request.departureText,
      tagline: 'Новый диалог',
      headerNote: 'Обсудите детали поездки, время и место встречи.',
      isOnline: true,
      relatedDate: request.departureDate,
      messages: [
        ChatMessage(
          text: contextText,
          isIncoming: false,
          timeLabel: 'Сейчас',
          dayLabel: 'Сегодня',
          kind: ChatMessageKind.system,
        ),
        ChatMessage(
          text:
              'Диалог создан. Обсудите детали поездки, время и место встречи.',
          isIncoming: false,
          timeLabel: 'Сейчас',
          dayLabel: 'Сегодня',
          kind: ChatMessageKind.system,
        ),
      ],
    );
    state = state.copyWith(threads: [...state.threads, thread]);
    _pendingDrafts[thread.id] = initialDraft;
    _resort();
    _syncNewThread(
      route: route,
      participantId: request.passenger.backendId,
      passengerRequestId: request.backendId,
      initialMessages: thread.messages,
    );
    return thread.id;
  }

  /// Ported from `ChatStore.openChat(with driver:...)`.
  String openChatWithDriver({
    required UserProfile driver,
    required String route,
    required String openingText,
    DateTime? departureDate,
    String? rideId,
  }) {
    final normalizedRoute = normalizedChatRoute(route);
    final now = DateTime.now();
    final contextText = departureDate == null
        ? null
        : _contextText(
            normalizedRoute,
            DateTextFormatter.dayMonthTime(departureDate),
          );

    final existing = _findThread(
      rideId: rideId,
      name: driver.name,
      route: normalizedRoute,
    );
    if (existing != null) {
      if (contextText != null) {
        existing.appendSystemMessageIfNeeded(
          contextText,
          timeLabel: DateTextFormatter.time(now),
          dayLabel: chatDayLabel(now),
        );
      }
      if (!existing.hasStartedConversation) {
        _pendingDrafts[existing.id] = openingText;
      } else {
        _pendingDrafts.remove(existing.id);
      }
      _resort();
      return existing.id;
    }

    final messages = <ChatMessage>[
      if (contextText != null)
        ChatMessage(
          text: contextText,
          isIncoming: false,
          timeLabel: 'Сейчас',
          dayLabel: 'Сегодня',
          kind: ChatMessageKind.system,
        ),
      ChatMessage(
        text:
            'Диалог создан. Здесь можно обсудить место встречи и детали поездки.',
        isIncoming: false,
        timeLabel: 'Сейчас',
        dayLabel: 'Сегодня',
        kind: ChatMessageKind.system,
      ),
    ];

    final thread = ChatThread(
      id: 'chat-${now.microsecondsSinceEpoch}',
      rideId: rideId,
      participantBackendId: driver.backendId,
      name: driver.name,
      route: normalizedRoute,
      preview: 'Новый диалог',
      timeLabel: 'Сейчас',
      tripStatus: 'Новый контакт',
      tagline: 'Связь по поездке',
      headerNote: 'Обсудите детали поездки, время выезда и место встречи.',
      isOnline: true,
      relatedDate: departureDate,
      messages: messages,
    );
    state = state.copyWith(threads: [...state.threads, thread]);
    _pendingDrafts[thread.id] = openingText;
    _resort();
    _syncNewThread(
      route: normalizedRoute,
      participantId: driver.backendId,
      rideId: rideId,
      initialMessages: thread.messages,
    );
    return thread.id;
  }

  /// Creates (or restores) the backend thread for an optimistically-added local
  /// thread, then reloads so the merge logic adopts the real `backendId`.
  void _syncNewThread({
    required String route,
    required String? participantId,
    String? rideId,
    String? passengerRequestId,
    required List<ChatMessage> initialMessages,
  }) {
    if (participantId == null) return;
    Future(() async {
      try {
        await _service.ensureChatThread(
          route: route,
          participantId: participantId,
          rideId: rideId,
          passengerRequestId: passengerRequestId,
          initialMessages: initialMessages,
        );
        if (_mounted) await loadChats();
      } catch (_) {
        // The optimistic local thread still works for display.
      }
    });
  }

  ChatThread? _findThread({
    String? rideId,
    String? passengerRequestId,
    required String name,
    required String route,
  }) {
    for (final thread in state.threads) {
      if (rideId != null && thread.rideId == rideId) return thread;
      if (passengerRequestId != null &&
          thread.passengerRequestId == passengerRequestId) {
        return thread;
      }
      if (rideId == null &&
          passengerRequestId == null &&
          thread.name == name &&
          thread.route == route) {
        return thread;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Appends an outgoing message optimistically, then persists it and refetches
  /// so the stored message (with its `backendId`) replaces the local one.
  Future<void> sendMessage(String threadId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final thread = threadById(threadId);
    if (thread == null) return;
    // Sending from an archived chat moves it back to active (QA #65).
    if (thread.category == ChatCategory.archive) {
      setArchived(threadId, false);
    }
    final now = DateTime.now();
    thread.messages = [
      ...thread.messages,
      ChatMessage(
        text: trimmed,
        isIncoming: false,
        timeLabel: DateTextFormatter.time(now),
        dayLabel: chatDayLabel(now),
        deliveryStatus: ChatMessageDeliveryStatus.sent,
      ),
    ];
    thread.preview = trimmed;
    thread.timeLabel = DateTextFormatter.time(now);
    _resort();

    final backendId = thread.backendId;
    if (backendId == null) return;
    try {
      await _service.sendChatMessage(threadId: backendId, text: trimmed);
      if (_mounted) await loadThread(threadId);
    } catch (_) {
      // The optimistic message stays visible even if the write failed.
    }
  }

  /// Ported from `ChatDetailView.handleSelectedPhoto`. Validates the payload,
  /// uploads it to Supabase Storage and sends an attachment message. Returns
  /// an error string (Russian, suitable for a SnackBar) or null on success.
  Future<String?> sendPhotoAttachment(
    String threadId, {
    required Uint8List data,
    required String fileName,
    required String contentType,
  }) async {
    const allowed = {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    };
    const maxSize = 10 * 1024 * 1024;
    if (!allowed.contains(contentType)) {
      return 'Можно отправлять только фотографии.';
    }
    if (data.isEmpty) return 'Не удалось подготовить фото.';
    if (data.length > maxSize) {
      return 'Фото больше 10 МБ. Выберите файл поменьше.';
    }

    final thread = threadById(threadId);
    if (thread == null) return 'Чат больше недоступен.';
    final backendId = thread.backendId;
    if (backendId == null) return 'Чат ещё не синхронизирован, попробуйте позже.';
    // Sending from an archived chat moves it back to active (QA #65).
    if (thread.category == ChatCategory.archive) {
      setArchived(threadId, false);
    }

    try {
      final attachment = await _service.uploadChatAttachment(
        threadId: backendId,
        fileName: fileName,
        data: data,
        contentType: contentType,
        kind: ChatAttachmentKind.photo,
      );

      final now = DateTime.now();
      thread.messages = [
        ...thread.messages,
        ChatMessage(
          text: attachment.previewText,
          isIncoming: false,
          timeLabel: DateTextFormatter.time(now),
          dayLabel: chatDayLabel(now),
          kind: ChatMessageKind.attachment,
          attachment: attachment,
          deliveryStatus: ChatMessageDeliveryStatus.sent,
        ),
      ];
      thread.preview = attachment.previewText;
      thread.timeLabel = DateTextFormatter.time(now);
      _resort();

      await _service.sendChatMessage(
        threadId: backendId,
        text: attachment.previewText,
        kind: ChatMessageKind.attachment,
        attachment: attachment,
      );
      if (_mounted) await loadThread(threadId);
      return null;
    } catch (_) {
      return 'Не удалось отправить вложение.';
    }
  }

  /// Resolves a viewable URL for a chat attachment so it can be opened/previewed
  /// (QA #77). Prefers the stored public URL, otherwise mints a short-lived
  /// signed URL from the attachment's storage path. Returns null if neither is
  /// available or the request fails.
  Future<String?> attachmentUrl(ChatAttachment attachment) async {
    final public = attachment.publicUrl;
    if (public != null && public.isNotEmpty) return public;
    final path = attachment.storagePath;
    if (path == null || path.isEmpty) return null;
    try {
      return await _service.createSignedChatAttachmentUrl(path);
    } catch (_) {
      return null;
    }
  }

  /// Ported from `ChatDetailActionsDomain.updatePendingBooking`. Updates the
  /// booking status, posts a system message into the chat and refreshes the
  /// banner.
  Future<void> updatePendingBooking({
    required String threadId,
    required String status,
  }) async {
    final context = state.pendingBooking;
    if (context == null) return;
    final thread = threadById(threadId);
    final backendThreadId = thread?.backendId;
    state = state.copyWith(pendingBooking: null);
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': status}).eq('id', context.bookingId);
      if (backendThreadId != null) {
        final systemText = status == 'confirmed'
            ? 'Система: заявка на поездку ${context.route} подтверждена.'
            : 'Система: заявка на поездку ${context.route} отклонена.';
        await _service.ensureSystemChatMessage(
          threadId: backendThreadId,
          text: systemText,
        );
        if (_mounted) await loadThread(threadId);
      }
    } catch (_) {
      // On failure, re-refresh the banner so it reappears if still pending.
      if (_mounted) await _refreshPendingBooking(threadId);
    }
  }

  /// Ensures a thread with [passenger] exists and posts the system message that
  /// tells them their booking was confirmed/declined. Mirrors the Swift
  /// `MatchingPassengersForRideView.updateBooking` notification side
  /// (`ensureChatThread` + `ensureSystemChatMessage`). Best-effort: a failure
  /// here must not block the booking-status update that already succeeded.
  Future<void> notifyBookingDecision({
    required UserProfile passenger,
    required String route,
    required DateTime departureDate,
    String? rideId,
    required bool confirmed,
  }) async {
    final participantId = passenger.backendId;
    if (participantId == null) return;
    try {
      final threadId = await _service.ensureChatThread(
        route: route,
        participantId: participantId,
        rideId: rideId,
      );
      final systemText = confirmed
          ? 'Система: заявка на поездку $route подтверждена.'
          : 'Система: заявка на поездку $route отклонена.';
      await _service.ensureSystemChatMessage(
        threadId: threadId,
        text: systemText,
      );
      if (_mounted) await loadChats();
    } catch (_) {
      // Best-effort, mirrors `_syncNewThread`.
    }
  }

  /// Marks the thread read locally and on the backend.
  void markRead(String threadId) {
    final thread = threadById(threadId);
    if (thread == null) return;
    if (thread.unreadCount != 0) {
      thread.unreadCount = 0;
      state = state.copyWith(threads: [...state.threads]);
    }
    final backendId = thread.backendId;
    if (backendId != null) {
      _service.markChatRead(backendId).ignore();
    }
  }

  /// Ported from `toggleArchive` — moves a thread in/out of the archive.
  void setArchived(String threadId, bool archived) {
    final thread = threadById(threadId);
    if (thread == null) return;
    thread.category = archived ? ChatCategory.archive : ChatCategory.active;
    state = state.copyWith(threads: [...state.threads]);
    final backendId = thread.backendId;
    if (backendId != null) {
      _service
          .setChatHidden(threadId: backendId, isHidden: archived)
          .ignore();
    }
  }

  /// Deletes the thread for the current user — a real removal that, unlike
  /// archiving, does not reappear in the archive on the next fetch (QA #68).
  void deleteThread(String threadId) {
    final thread = threadById(threadId);
    final backendId = thread?.backendId;
    if (backendId != null) {
      _service.setChatDeleted(backendId).ignore();
    }
    state = state.copyWith(
      threads: state.threads.where((t) => t.id != threadId).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Reconciliation (ported from the ChatStore merge/dedup helpers)
  // ---------------------------------------------------------------------------

  /// Ported from `ChatStore.mergeChats`.
  void _mergeChats(List<ChatThread> fetched) {
    final normalized = _deduplicatedThreads(fetched);
    final current = state.threads;
    final merged = <ChatThread>[];

    for (final f in normalized) {
      final index = _matchingChatIndex(current, f);
      if (index != null) {
        final existing = current[index];
        merged.add(
          f.copyWith(
            id: existing.id,
            unreadCount: _activeThreadId == existing.id ? 0 : f.unreadCount,
            category: _mergedCategory(existing, f),
            messages: f.messages.isEmpty
                ? existing.messages
                : _mergeMessages(existing.messages, f.messages),
          ),
        );
      } else {
        merged.add(f);
      }
    }

    final provisional = current.where((existing) {
      if (existing.backendId != null) return false;
      return !merged.any((incoming) {
        if (existing.participantBackendId != null &&
            incoming.participantBackendId != null) {
          return existing.route == incoming.route &&
              existing.participantBackendId == incoming.participantBackendId;
        }
        return existing.name == incoming.name &&
            existing.route == incoming.route;
      });
    }).toList();

    final combined = _deduplicatedThreads([...provisional, ...merged])
      ..sort((a, b) => b.latestActivityDate.compareTo(a.latestActivityDate));
    state = state.copyWith(threads: combined);
  }

  /// Ported from `ChatStore.mergeChat`.
  void _mergeChat(ChatThread fetched) {
    final current = [...state.threads];
    final index = _matchingChatIndex(current, fetched);
    if (index != null) {
      final existing = current[index];
      current[index] = fetched.copyWith(
        id: existing.id,
        unreadCount: _activeThreadId == existing.id ? 0 : fetched.unreadCount,
        category: _mergedCategory(existing, fetched),
        messages: fetched.messages.isEmpty
            ? existing.messages
            : _mergeMessages(existing.messages, fetched.messages),
      );
    } else {
      current.add(fetched);
    }
    final deduped = _deduplicatedThreads(current)
      ..sort((a, b) => b.latestActivityDate.compareTo(a.latestActivityDate));
    state = state.copyWith(threads: deduped);
  }

  /// Ported from `ChatStore.matchingChatIndex`.
  int? _matchingChatIndex(List<ChatThread> threads, ChatThread fetched) {
    for (var i = 0; i < threads.length; i++) {
      final existing = threads[i];
      if (fetched.backendId != null && existing.backendId != null) {
        if (fetched.backendId == existing.backendId) return i;
        continue;
      }
      if (fetched.rideId != null && existing.rideId != null) {
        if (fetched.rideId == existing.rideId) return i;
        continue;
      }
      if (fetched.passengerRequestId != null &&
          existing.passengerRequestId != null) {
        if (fetched.passengerRequestId == existing.passengerRequestId) return i;
        continue;
      }
      if (fetched.participantBackendId != null &&
          existing.participantBackendId != null) {
        if (fetched.route == existing.route &&
            fetched.participantBackendId == existing.participantBackendId) {
          return i;
        }
        continue;
      }
      if (fetched.name == existing.name && fetched.route == existing.route) {
        return i;
      }
    }
    return null;
  }

  /// Ported from `ChatStore.chatsMatch`.
  bool _chatsMatch(ChatThread lhs, ChatThread rhs) {
    if (lhs.backendId != null && rhs.backendId != null) {
      return lhs.backendId == rhs.backendId;
    }
    if (lhs.rideId != null && rhs.rideId != null) {
      return lhs.rideId == rhs.rideId;
    }
    if (lhs.passengerRequestId != null && rhs.passengerRequestId != null) {
      return lhs.passengerRequestId == rhs.passengerRequestId;
    }
    if (lhs.participantBackendId != null && rhs.participantBackendId != null) {
      return lhs.route == rhs.route &&
          lhs.participantBackendId == rhs.participantBackendId;
    }
    return lhs.name == rhs.name && lhs.route == rhs.route;
  }

  /// Ported from `ChatStore.mergeMessages` — keeps a stable local message `id`
  /// when a fetched message corresponds to one already shown.
  List<ChatMessage> _mergeMessages(
    List<ChatMessage> existing,
    List<ChatMessage> fetched,
  ) {
    return fetched.map((f) {
      if (f.backendId != null) {
        for (final e in existing) {
          if (e.backendId == f.backendId) return f.copyWith(id: e.id);
        }
      }
      for (final e in existing) {
        if (e.backendId == null &&
            e.text == f.text &&
            e.dayLabel == f.dayLabel &&
            e.kind == f.kind &&
            _attachmentsEqual(e.attachment, f.attachment) &&
            e.isIncoming == f.isIncoming) {
          return f.copyWith(id: e.id);
        }
      }
      return f;
    }).toList();
  }

  bool _attachmentsEqual(ChatAttachment? a, ChatAttachment? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.sameAs(b);
  }

  /// Ported from `ChatStore.deduplicatedThreads`.
  List<ChatThread> _deduplicatedThreads(List<ChatThread> threads) {
    final result = <ChatThread>[];
    for (final thread in threads) {
      final index = result.indexWhere((e) => _chatsMatch(e, thread));
      if (index < 0) {
        result.add(thread);
        continue;
      }
      final existing = result[index];
      final shouldReplace = !thread.latestActivityDate
          .isBefore(existing.latestActivityDate);
      if (shouldReplace) {
        result[index] = thread.copyWith(
          id: existing.id,
          unreadCount:
              _activeThreadId == existing.id ? 0 : thread.unreadCount,
          category: _mergedCategory(existing, thread),
          messages: thread.messages.isEmpty
              ? existing.messages
              : _mergeMessages(existing.messages, thread.messages),
        );
      }
    }
    return result;
  }

  /// Ported from `ChatStore.mergedCategory` — keeps a thread in the archive
  /// while the user is actively viewing it, even if a fetch says it is active.
  ChatCategory _mergedCategory(ChatThread existing, ChatThread incoming) {
    final keepArchive = existing.category == ChatCategory.archive &&
        incoming.category == ChatCategory.active &&
        _activeThreadId == existing.id;
    return keepArchive ? ChatCategory.archive : incoming.category;
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
