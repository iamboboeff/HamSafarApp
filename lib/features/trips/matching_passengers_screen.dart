import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../models/booked_trip.dart';
import '../../models/ride_passenger_booking.dart';
import '../../state/app_state.dart';
import '../../state/chat_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/hs_route.dart';
import '../chat/chat_detail_screen.dart';
import '../profile/public_profile_screen.dart';

/// Ported from `MatchingPassengersForRideView` in `MyTripsViews.swift`.
///
/// Lists the pending bookings against the driver's ride and lets the driver
/// confirm or decline each one. Confirming sets the booking to `confirmed`,
/// declining sets it to `cancelled` (which frees the seat — `declined` would
/// not, since occupancy only excludes `cancelled`). Either way the passenger is
/// notified through a system message in the chat thread.
class MatchingPassengersScreen extends ConsumerStatefulWidget {
  const MatchingPassengersScreen({super.key, required this.trip});

  final BookedTrip trip;

  @override
  ConsumerState<MatchingPassengersScreen> createState() =>
      _MatchingPassengersScreenState();
}

class _MatchingPassengersScreenState
    extends ConsumerState<MatchingPassengersScreen> {
  List<RidePassengerBooking> _bookings = const [];
  bool _isLoading = true;
  bool _isActing = false;
  String? _error;

  BookedTrip get trip => widget.trip;

  String get _hyphenRoute => '${trip.ride.fromCity} - ${trip.ride.toCity}';
  String get _dashRoute => '${trip.ride.fromCity} — ${trip.ride.toCity}';

  List<RidePassengerBooking> get _pendingBookings =>
      _bookings.where((b) => b.isPending).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rideId = trip.ride.backendId;
    if (rideId == null) {
      setState(() {
        _bookings = const [];
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bookings =
          await ref.read(supabaseServiceProvider).fetchRidePassengerBookings(
                rideId,
              );
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr('Не удалось загрузить заявки. Попробуйте ещё раз.');
        _isLoading = false;
      });
    }
  }

  Future<void> _confirm(RidePassengerBooking booking) async {
    final ok = await _showDecisionDialog(
      title: tr('Подтвердить заявку?'),
      message:
          tr('Пассажир получит подтверждение и увидит обновление в чате.'),
      confirmLabel: tr('Подтвердить'),
      isDestructive: false,
    );
    if (ok == true) await _apply(booking, status: 'confirmed');
  }

  Future<void> _reject(RidePassengerBooking booking) async {
    final ok = await _showDecisionDialog(
      title: tr('Отклонить заявку?'),
      message: tr('Пассажир получит уведомление, что заявка отклонена.'),
      confirmLabel: tr('Отклонить'),
      isDestructive: true,
    );
    if (ok == true) await _apply(booking, status: 'cancelled');
  }

  Future<void> _apply(
    RidePassengerBooking booking, {
    required String status,
  }) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      await ref.read(supabaseServiceProvider).updateBookingStatus(
            bookingId: booking.backendId,
            status: status,
          );
      await ref.read(chatProvider.notifier).notifyBookingDecision(
            passenger: booking.passenger,
            route: _dashRoute,
            departureDate: trip.ride.departureDate,
            rideId: trip.ride.backendId,
            confirmed: status == 'confirmed',
          );
      ref.read(bookedTripsProvider.notifier).refresh();
      await _load();
    } catch (_) {
      if (mounted) {
        _showError(tr('Не удалось выполнить действие. Попробуйте ещё раз.'));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _openChat(RidePassengerBooking booking) {
    final threadId = ref.read(chatProvider.notifier).openChatWithDriver(
          driver: booking.passenger,
          route: _hyphenRoute,
          openingText: trf(
            'Здравствуйте! По вашей заявке на поездку {route}.',
            {'route': _dashRoute},
          ),
          departureDate: trip.ride.departureDate,
          rideId: trip.ride.backendId,
        );
    Navigator.of(context).push(
      HSRoute<void>(builder: (_) => ChatDetailScreen(threadId: threadId)),
    );
  }

  /// Opens the passenger's public profile (tap on their avatar / name).
  void _openProfile(RidePassengerBooking booking) {
    final backendId = booking.passenger.backendId;
    if (backendId == null) return;
    Navigator.of(context).push(
      HSRoute<void>(
        builder: (_) => UserPublicProfileScreen(
          userId: backendId,
          fallback: booking.passenger,
        ),
      ),
    );
  }

  Future<bool?> _showDecisionDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: isDestructive
                  ? const TextStyle(color: Colors.red)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Не удалось выполнить действие')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Ок')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingBookings;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Входящие заявки'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The big duplicate title is dropped (it now lives in the app
                  // bar); a single compact route chip gives context once, instead
                  // of repeating the route on every card below.
                  _RouteChip(from: trip.ride.fromCity, to: trip.ride.toCity),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    GlassCard(
                      child: Text(
                        _error!,
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    )
                  else if (pending.isEmpty)
                    GlassCard(
                      child: Text(
                        tr('Пока нет новых заявок на эту поездку.'),
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    )
                  else
                    for (final booking in pending) ...[
                      _IncomingBookingCard(
                        booking: booking,
                        isActing: _isActing,
                        onChat: () => _openChat(booking),
                        onConfirm: () => _confirm(booking),
                        onReject: () => _reject(booking),
                        onOpenProfile: () => _openProfile(booking),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from `IncomingRideBookingCard` in `MyTripsViews.swift`.
class _IncomingBookingCard extends StatelessWidget {
  const _IncomingBookingCard({
    required this.booking,
    required this.isActing,
    required this.onChat,
    required this.onConfirm,
    required this.onReject,
    required this.onOpenProfile,
  });

  final RidePassengerBooking booking;
  final bool isActing;
  final VoidCallback onChat;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final badgeColor =
        booking.requestBadgeTitle == 'Новая' ? hs.primary : hs.warm;
    final sentAt = booking.sentAtText;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: who + when, with the status badge pinned top-right.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onOpenProfile,
                behavior: HitTestBehavior.opaque,
                child: ProfileAvatar(
                  initials: booking.passenger.initials,
                  avatarBytes: booking.passenger.avatarBytes,
                  avatarUrl: booking.passenger.avatarUrl,
                  size: 48,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onOpenProfile,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        booking.passenger.name,
                        style: HSText.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sentAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        sentAt,
                        style: HSText.caption.copyWith(
                          color: context.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StatusBadge(
                title: tr(booking.requestBadgeTitle),
                color: badgeColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Meta strip: seats requested on the left, chat shortcut on the right.
          Row(
            children: [
              _SeatsPill(seats: booking.seatsCount),
              const Spacer(),
              TextButton.icon(
                onPressed: isActing ? null : onChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: Text(tr('Написать в чат')),
                style: TextButton.styleFrom(
                  foregroundColor: hs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Decision: confirm (primary) vs reject (destructive), equal weight.
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isActing ? null : onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(tr('Подтвердить')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isActing ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(tr('Отклонить')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small coloured status pill ("Новая" / "Ожидает ответа").
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        title,
        style: HSText.captionSemibold.copyWith(color: color),
      ),
    );
  }
}

/// Compact "N seats requested" pill — seat icon + count + the word «место», so
/// it reads clearly (the bare icon + number wasn't obvious enough).
class _SeatsPill extends StatelessWidget {
  const _SeatsPill({required this.seats});

  final int seats;

  String _label() {
    if (seats == 1) return tr('1 место');
    if (seats < 5) return trf('{count} места', {'count': seats});
    return trf('{count} мест', {'count': seats});
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hs.secondarySurface,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_seat_outlined,
            size: 15,
            color: context.secondaryText,
          ),
          const SizedBox(width: 6),
          Text(_label(), style: HSText.captionSemibold),
        ],
      ),
    );
  }
}

/// Compact route chip shown once at the top of the list (instead of repeating
/// the route on every request card).
class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: hs.secondarySurface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: hs.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route, size: 16, color: hs.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$from → $to',
              style: HSText.subheadlineSemibold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
