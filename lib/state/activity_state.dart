import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_notification.dart';
import 'app_state.dart';

/// Activity-feed state — ported from `appState.trips.activityNotifications`
/// and `AppActivityDomain`. Loads when the user signs in; rebuilds the list
/// optimistically on `markAllRead`, then writes through to Supabase.
class ActivityState {
  const ActivityState({required this.notifications, required this.isLoading});

  final List<ActivityNotification> notifications;
  final bool isLoading;

  /// Mirrors `AppActivityDomain.unreadCount`.
  int get unreadCount =>
      notifications.where((n) => !n.isRead).length;

  static const empty =
      ActivityState(notifications: [], isLoading: false);

  ActivityState copyWith({
    List<ActivityNotification>? notifications,
    bool? isLoading,
  }) {
    return ActivityState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ActivityNotifier extends Notifier<ActivityState> {
  @override
  ActivityState build() {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (isAuthenticated) Future.microtask(_load);
    return ActivityState.empty;
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final list =
          await ref.read(supabaseServiceProvider).fetchActivityNotifications();
      state = state.copyWith(notifications: list, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() => _load();

  /// Ported from `AppActivityDomain.markAllRead` — flips every row to read
  /// locally and writes through to Supabase.
  void markAllRead() {
    if (state.unreadCount == 0) return;
    state = state.copyWith(
      notifications: [
        for (final n in state.notifications)
          if (n.isRead) n else n.copyWith(isRead: true),
      ],
    );
    ref
        .read(supabaseServiceProvider)
        .markAllActivityNotificationsRead()
        .ignore();
  }
}

final activityProvider =
    NotifierProvider<ActivityNotifier, ActivityState>(ActivityNotifier.new);
