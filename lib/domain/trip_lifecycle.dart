import '../core/i18n/l10n.dart';
import '../core/supabase/supabase_chat_service.dart';
import '../models/booked_trip.dart';
import '../models/chat.dart';
import '../models/trip_enums.dart';
import 'date_formatter.dart';

/// Ported from `ContentCoordinatorTripLifecycle.syncTripLifecycleMessages` in
/// `ContentCoordinatorTripLifecycle.swift`. After each booked-trips refresh,
/// posts a one-time system message into every chat thread whose route matches
/// the trip when:
///   * the trip just transitioned into `isInProgress` (started), or
///   * the trip just transitioned into `isCompleted` within the last 12h, or
///   * the user is a passenger on a completed trip 10min–7d ago (review
///     reminder, only when no review yet exists — gated by [hasOwnReview]).
class TripLifecycleDomain {
  TripLifecycleDomain._();

  static String _routeTextFor(BookedTrip trip) =>
      '${trip.ride.fromCity} — ${trip.ride.toCity}';

  static String _tripKey(BookedTrip trip) {
    final backend = trip.backendId;
    if (backend != null) return '${trip.role.name}-$backend';
    final rideBackend = trip.ride.backendId;
    if (rideBackend != null) return '${trip.role.name}-ride-$rideBackend';
    return '${trip.role.name}-local-${trip.id}';
  }

  /// Compares [previous] to [current] and emits one system message per matched
  /// thread for each transition. [matchingThreadBackendIds] resolves the trip's
  /// route to the set of chat thread ids to post into. [hasOwnReview] is asked
  /// only for the review-reminder case so we don't re-prompt after a review.
  static Future<void> sync({
    required List<BookedTrip> previous,
    required List<BookedTrip> current,
    required SupabaseChatService chatService,
    required List<String> Function(BookedTrip trip)
        matchingThreadBackendIds,
    required Future<bool> Function(BookedTrip trip) hasOwnReview,
  }) async {
    final prevByKey = {for (final t in previous) _tripKey(t): t};
    final now = DateTime.now();

    for (final trip in current) {
      final prev = prevByKey[_tripKey(trip)];
      final completionAge =
          now.difference(trip.ride.estimatedArrivalDate);
      final completionAgeSeconds = completionAge.inSeconds;

      final shouldSendStart =
          trip.isInProgress && !(prev?.isInProgress ?? false);
      final shouldSendCompleted =
          trip.isCompleted &&
              !(prev?.isCompleted ?? false) &&
              completionAgeSeconds <= 12 * 60 * 60;
      final shouldSendReviewReminder = trip.role == TripRole.passenger &&
          trip.isCompleted &&
          completionAgeSeconds >= 10 * 60 &&
          completionAgeSeconds <= 7 * 24 * 60 * 60;

      Future<void> post(String text) async {
        final ids = matchingThreadBackendIds(trip);
        for (final threadId in ids) {
          try {
            await chatService.ensureSystemChatMessage(
              threadId: threadId,
              text: text,
            );
          } catch (_) {
            // Each thread is best-effort; one failure shouldn't block others.
          }
        }
      }

      if (shouldSendStart) {
        await post(
          trf(
            'Система: поездка {route} от {datetime} началась.',
            {
              'route': _routeTextFor(trip),
              'datetime':
                  DateTextFormatter.dayMonthTime(trip.ride.departureDate),
            },
          ),
        );
      }
      if (shouldSendCompleted) {
        await post(
          trf(
            'Система: поездка {route} завершена.',
            {'route': _routeTextFor(trip)},
          ),
        );
      }
      if (shouldSendReviewReminder) {
        final hasReview = await hasOwnReview(trip);
        if (!hasReview) {
          await post(
            tr(
              'Система: поездка завершена. Оставьте отзыв о поездке, это '
              'поможет другим пассажирам и водителям.',
            ),
          );
        }
      }
    }
  }

  /// Ported helper used by the chat-detail review-prompt banner: builds the
  /// list of thread backend ids whose route matches the given trip.
  static List<String> matchingThreadBackendIds({
    required BookedTrip trip,
    required List<ChatThread> threads,
  }) {
    final routeKey = normalizedChatRoute(_routeTextFor(trip));
    final seen = <String>{};
    for (final thread in threads) {
      if (normalizedChatRoute(thread.route) != routeKey) continue;
      final id = thread.backendId;
      if (id != null) seen.add(id);
    }
    return seen.toList();
  }
}
