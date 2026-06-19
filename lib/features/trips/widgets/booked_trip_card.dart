import 'package:flutter/material.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../../models/booked_trip.dart';
import '../../../models/trip_enums.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/common.dart';
import '../../../widgets/glass_card.dart';

/// Ported from `BookedTripCard` in `RideUIComponents.swift`.
class BookedTripCard extends StatelessWidget {
  const BookedTripCard({
    super.key,
    required this.trip,
    required this.matchingCount,
    required this.searchPassengers,
    required this.onSearchPassengersChanged,
    required this.onOpenMatches,
    required this.onOpenPassengerRequests,
    required this.onOpenDetails,
    required this.onRepeat,
  });

  final BookedTrip trip;
  final int matchingCount;
  final bool searchPassengers;
  final ValueChanged<bool> onSearchPassengersChanged;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenPassengerRequests;
  final VoidCallback onOpenDetails;
  final VoidCallback onRepeat;

  bool get _isRealPassengerBooking =>
      trip.role == TripRole.passenger && trip.backendId != null;

  Color _passengerStatusAccent(BuildContext context) {
    final hs = context.hs;
    final status = trip.displayStatus.toLowerCase();
    if (status.contains('ожида')) return hs.warm;
    if (status.contains('подтверж')) return hs.mint;
    return hs.primary;
  }

  String get _tripTypeBadgeTitle {
    // Role-first wording so the card clearly states who you are on this trip.
    if (trip.role == TripRole.driver) return tr('Вы водитель');
    return _isRealPassengerBooking ? tr('Вы пассажир') : tr('Ваш запрос');
  }

  Color _tripTypeBadgeColor(BuildContext context) {
    final hs = context.hs;
    if (trip.role == TripRole.driver) return hs.primary;
    // Passenger role is consistently coral; booking vs request is told apart by
    // the badge text + status, not a separate hue.
    return _isRealPassengerBooking ? hs.purple : hs.passenger;
  }

  bool get _shouldShowBottomDivider {
    if (trip.role == TripRole.driver) return true;
    return !_isRealPassengerBooking;
  }

  @override
  Widget build(BuildContext context) {
    // All My Trips cards share the same GlassCard surface (border + shadow) so
    // active / request / history cards look consistent.
    return GestureDetector(
      onTap: onOpenDetails,
      behavior: HitTestBehavior.opaque,
      child: GlassCard(
        child: trip.isCancelled
            ? _cancelledBody(context)
            : trip.isCompleted
            ? _completedBody(context)
            : _activeBody(context),
      ),
    );
  }

  Widget _timeRow(BuildContext context, Widget trailing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time + date in their own row so the smaller date sits vertically
        // centred against the time, while the (taller) price trailing still
        // top-aligns with the time.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                trip.departureClockText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '• ${trip.departureDayText}',
                  style: HSText.subheadlineMedium.copyWith(
                    color: context.secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }

  Widget _routePoints(BuildContext context, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompactRoutePoint(city: trip.ride.fromCity, color: accent),
        const SizedBox(height: 8),
        CompactRoutePoint(city: trip.ride.toCity, color: accent),
      ],
    );
  }

  Widget _badge(BuildContext context) {
    final color = _tripTypeBadgeColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        _tripTypeBadgeTitle,
        style: HSText.caption2Bold.copyWith(color: color),
      ),
    );
  }

  Widget _activeBody(BuildContext context) {
    final hs = context.hs;
    final isDriver = trip.role == TripRole.driver;

    final Widget trailing;
    if (!isDriver) {
      if (_isRealPassengerBooking) {
        trailing = Text(
          trip.displayStatus,
          style: HSText.captionSemibold.copyWith(
            color: _passengerStatusAccent(context),
          ),
        );
      } else {
        trailing = Text(
          trf('Нужно {seats} место', {'seats': trip.seatsBooked}),
          style: HSText.captionSemibold.copyWith(color: context.secondaryText),
        );
      }
    } else {
      trailing = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            trip.ride.formattedPrice(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            tr('за место'),
            style: HSText.caption2.copyWith(color: context.secondaryText),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _timeRow(context, trailing),
        const SizedBox(height: 10),
        // Route on the left, role badge on the right (fills the empty space
        // and keeps the "who am I on this trip" tag next to the route).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _routePoints(context, _tripTypeBadgeColor(context)),
            ),
            const SizedBox(width: 8),
            _badge(context),
          ],
        ),
        if (_shouldShowBottomDivider) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 8),
        if (!isDriver)
          if (_isRealPassengerBooking)
            const SizedBox.shrink()
          else
            _surfaceButton(
              context,
              title: trf('Подходящие водители ({count})', {
                'count': matchingCount,
              }),
              subtitle: tr('Отклики по вашему запросу'),
              onTap: onOpenMatches,
            )
        else
          Column(
            children: [
              if (trip.pendingPassengerCount > 0) ...[
                _surfaceButton(
                  context,
                  title: trf('Входящие заявки ({count})', {
                    'count': trip.pendingPassengerCount,
                  }),
                  subtitle: tr('Пассажиры, которые хотят занять места'),
                  onTap: onOpenPassengerRequests,
                ),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: hs.secondarySurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Ищу пассажиров'),
                            style: HSText.subheadlineSemibold,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr('Отключите, если свободные места закончились'),
                            style: HSText.caption2.copyWith(
                              color: context.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: searchPassengers,
                      activeTrackColor: hs.primary,
                      onChanged: onSearchPassengersChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _surfaceButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: hs.secondarySurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HSText.subheadlineSemibold),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: HSText.caption2.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: context.secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _statusHeaderRow(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text, style: HSText.subheadlineSemibold.copyWith(color: color)),
      ],
    );
  }

  Widget _historyBody(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusHeaderRow(context, icon, label, color),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        _timeRow(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trip.ride.formattedPrice(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tr('за место'),
                style: HSText.caption.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _routePoints(context, context.hs.primary),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onRepeat,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Text(
              tr('Повторить поездку'),
              style: HSText.subheadlineMedium.copyWith(
                color: context.hs.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cancelledBody(BuildContext context) {
    final expired = trip.isExpired;
    return _historyBody(
      context,
      icon: expired ? Icons.timer_off_outlined : Icons.cancel,
      label: expired ? tr('Заявка истекла') : tr('Поездка отменена'),
      color: expired ? context.secondaryText : context.hs.danger,
    );
  }

  Widget _completedBody(BuildContext context) {
    final noPassenger = trip.noPassengerFound;
    return _historyBody(
      context,
      icon: noPassenger ? Icons.person_off_outlined : Icons.check_circle,
      label: noPassenger ? tr('Пассажир не найден') : tr('Поездка завершена'),
      color: noPassenger ? context.secondaryText : context.hs.mint,
    );
  }
}
