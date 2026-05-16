import 'package:flutter/material.dart';

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
  });

  final PassengerRequest request;
  final int matchingCount;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final isInactive = request.isCompleted || request.isCancelled;
    final statusAccent = isInactive ? context.secondaryText : hs.warm;
    final seats = request.seatsNeeded;

    return GestureDetector(
      onTap: onOpenDetails,
      behavior: HitTestBehavior.opaque,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.departureClockText,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• ${request.departureDayText}',
                  style: HSText.subheadlineMedium.copyWith(
                    color: context.secondaryText,
                  ),
                ),
                const Spacer(),
                Text(
                  request.isCompleted
                      ? request.displayStatus
                      : 'Нужно $seats ${seats == 1 ? 'место' : 'места'}',
                  style: HSText.captionSemibold.copyWith(color: statusAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: statusAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Запрос водителям',
                style: HSText.caption2Bold.copyWith(color: statusAccent),
              ),
            ),
            const SizedBox(height: 8),
            CompactRoutePoint(city: request.fromCity, color: hs.warm),
            const SizedBox(height: 8),
            CompactRoutePoint(city: request.toCity, color: hs.warm),
            if (!request.isCompleted && !request.isCancelled) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onOpenMatches,
                behavior: HitTestBehavior.opaque,
                child: Container(
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
                              'Подходящие водители ($matchingCount)',
                              style: HSText.subheadlineSemibold,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Отклики по вашему запросу',
                              style: HSText.caption2.copyWith(
                                color: context.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: context.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
