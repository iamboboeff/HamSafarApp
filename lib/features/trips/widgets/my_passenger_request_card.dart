import 'package:flutter/material.dart';

import 'package:hamsafar/core/i18n/l10n.dart';

import '../../../models/passenger_request.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/common.dart';
import '../../../widgets/glass_card.dart';

/// Ported from `MyPassengerRequestCard` in `MyTripsViews.swift`.
class MyPassengerRequestCard extends StatelessWidget {
  const MyPassengerRequestCard({
    super.key,
    required this.request,
    required this.matchingCount,
    required this.onOpenMatches,
    required this.onOpenDetails,
    required this.onRepeat,
  });

  final PassengerRequest request;
  final int matchingCount;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenDetails;
  final VoidCallback onRepeat;

  bool get _isInactive => request.isCompleted || request.isCancelled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenDetails,
      behavior: HitTestBehavior.opaque,
      child: GlassCard(
        child: _isInactive ? _historyBody(context) : _activeBody(context),
      ),
    );
  }

  Widget _timeRow(BuildContext context, Widget trailing) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          request.departureClockText,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(
          '• ${request.departureDayText}',
          style: HSText.subheadlineMedium.copyWith(color: context.secondaryText),
        ),
        const Spacer(),
        trailing,
      ],
    );
  }

  Widget _seatsTrailing(BuildContext context) {
    final seats = request.seatsNeeded;
    // Seat quantity is neutral info, not a status — keep it secondary so the
    // role/attention colours stay meaningful.
    return Text(
      trf('Нужно {seats} {word}', {
        'seats': '$seats',
        'word': seats == 1 ? tr('место') : tr('места'),
      }),
      style: HSText.captionSemibold.copyWith(color: context.secondaryText),
    );
  }

  Widget _routePoints(BuildContext context, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompactRoutePoint(city: request.fromCity, color: accent),
        const SizedBox(height: 8),
        CompactRoutePoint(city: request.toCity, color: accent),
      ],
    );
  }

  // History card — same shape as the other history cards (booked trips):
  // status header on top, route in the middle, "Повторить поездку" at the
  // bottom.
  Widget _historyBody(BuildContext context) {
    final hs = context.hs;
    final cancelled = request.isCancelled;
    final IconData icon =
        cancelled ? Icons.cancel : Icons.person_off_outlined;
    final String label =
        cancelled ? tr('Запрос отменён') : tr('Водитель не найден');
    final Color color = cancelled ? hs.danger : context.secondaryText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: HSText.subheadlineSemibold.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        _timeRow(context, _seatsTrailing(context)),
        const SizedBox(height: 8),
        _routePoints(context, hs.passenger),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onRepeat,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Text(
              tr('Повторить поездку'),
              style: HSText.subheadlineMedium.copyWith(color: hs.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _activeBody(BuildContext context) {
    final hs = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _timeRow(context, _seatsTrailing(context)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: hs.passenger.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            tr('Запрос водителям'),
            style: HSText.caption2Bold.copyWith(color: hs.passenger),
          ),
        ),
        const SizedBox(height: 8),
        _routePoints(context, hs.passenger),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onOpenMatches,
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
                      Text(
                        trf('Подходящие водители ({count})',
                            {'count': '$matchingCount'}),
                        style: HSText.subheadlineSemibold,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('Отклики по вашему запросу'),
                        style: HSText.caption2
                            .copyWith(color: context.secondaryText),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 14, color: context.secondaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
