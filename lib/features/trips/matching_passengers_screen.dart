import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        _error = 'Не удалось загрузить заявки. Попробуйте ещё раз.';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirm(RidePassengerBooking booking) async {
    final ok = await _showDecisionDialog(
      title: 'Подтвердить заявку?',
      message: 'Пассажир получит подтверждение и увидит обновление в чате.',
      confirmLabel: 'Подтвердить',
      isDestructive: false,
    );
    if (ok == true) await _apply(booking, status: 'confirmed');
  }

  Future<void> _reject(RidePassengerBooking booking) async {
    final ok = await _showDecisionDialog(
      title: 'Отклонить заявку?',
      message: 'Пассажир получит уведомление, что заявка отклонена.',
      confirmLabel: 'Отклонить',
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
        _showError('Не удалось выполнить действие. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _openChat(RidePassengerBooking booking) {
    final threadId = ref.read(chatProvider.notifier).openChatWithDriver(
          driver: booking.passenger,
          route: _hyphenRoute,
          openingText:
              'Здравствуйте! По вашей заявке на поездку $_dashRoute.',
          departureDate: trip.ride.departureDate,
          rideId: trip.ride.backendId,
        );
    Navigator.of(context).push(
      HSRoute<void>(builder: (_) => ChatDetailScreen(threadId: threadId)),
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
            child: const Text('Отмена'),
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
        title: const Text('Не удалось выполнить действие'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ок'),
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
      appBar: AppBar(title: const Text('Заявки')),
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
                  Text('Входящие заявки', style: HSText.largeTitle),
                  const SizedBox(height: 6),
                  Text(
                    '${trip.ride.fromCity} - ${trip.ride.toCity}',
                    style: HSText.subheadline.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 18),
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
                        'Пока нет новых заявок на эту поездку.',
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    )
                  else
                    for (final booking in pending) ...[
                      _IncomingBookingCard(
                        booking: booking,
                        route: _dashRoute,
                        isActing: _isActing,
                        onChat: () => _openChat(booking),
                        onConfirm: () => _confirm(booking),
                        onReject: () => _reject(booking),
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
    required this.route,
    required this.isActing,
    required this.onChat,
    required this.onConfirm,
    required this.onReject,
  });

  final RidePassengerBooking booking;
  final String route;
  final bool isActing;
  final VoidCallback onChat;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final badgeColor =
        booking.requestBadgeTitle == 'Новая' ? hs.primary : hs.warm;
    final sentAt = booking.sentAtText;

    return GlassCard(
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(
                    initials: booking.passenger.initials,
                    avatarBytes: booking.passenger.avatarBytes,
                    avatarUrl: booking.passenger.avatarUrl,
                    size: 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.passenger.name,
                          style: HSText.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            booking.requestBadgeTitle,
                            style: HSText.captionSemibold.copyWith(
                              color: badgeColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          route,
                          style: HSText.subheadline.copyWith(
                            color: context.secondaryText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (sentAt != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 12,
                                color: context.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  sentAt,
                                  style: HSText.caption.copyWith(
                                    color: context.secondaryText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: isActing ? null : onChat,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Написать в чат'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: isActing ? null : onConfirm,
                      child: const Text('Подтвердить'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isActing ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Отклонить'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: _SeatsPill(seats: booking.seatsCount),
          ),
        ],
      ),
    );
  }
}

/// Ported from `BookingFactPill` in `MyTripsViews.swift`.
class _SeatsPill extends StatelessWidget {
  const _SeatsPill({required this.seats});

  final int seats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.hs.secondarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Мест',
            style: HSText.caption2.copyWith(color: context.secondaryText),
          ),
          Text('$seats', style: HSText.subheadlineSemibold),
        ],
      ),
    );
  }
}
