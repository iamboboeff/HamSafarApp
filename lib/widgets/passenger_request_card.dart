import 'package:flutter/material.dart';
import 'package:hamsafar/core/i18n/l10n.dart';

import '../domain/date_formatter.dart';
import '../models/passenger_request.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';
import 'common.dart';
import 'glass_card.dart';

/// Ported from `PassengerRequestCard` in `RideUIComponents.swift`.
class PassengerRequestCard extends StatelessWidget {
  const PassengerRequestCard({super.key, required this.request, this.onTap});

  final PassengerRequest request;
  final VoidCallback? onTap;

  String get _departureDayLabel {
    if (DateUtilsX.isToday(request.departureDate)) return tr('Сегодня');
    if (DateUtilsX.isTomorrow(request.departureDate)) return tr('Завтра');
    return DateTextFormatter.dayMonthShort(request.departureDate);
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final seats = request.seatsNeeded;

    return HSPressable(
      onTap: onTap,
      pressedScale: 0.99,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  DateTextFormatter.time(request.departureDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• $_departureDayLabel',
                  style: HSText.subheadlineMedium.copyWith(
                    color: context.secondaryText,
                  ),
                ),
                const Spacer(),
                Text(
                  trf('Нужно {n} место', {'n': seats}),
                  style:
                      HSText.captionSemibold.copyWith(color: context.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TripRoutePoint(city: request.fromCity, color: hs.passenger),
                const SizedBox(height: 10),
                TripRoutePoint(city: request.toCity, color: hs.passenger),
              ],
            ),
            const SizedBox(height: 10),
            if (request.note.isNotEmpty) ...[
              Text(
                request.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HSText.caption.copyWith(color: context.secondaryText),
              ),
              const SizedBox(height: 10),
            ],
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                ProfileAvatar(
                  initials: request.passenger.initials,
                  avatarBytes: request.passenger.avatarBytes,
                  avatarUrl: request.passenger.avatarUrl,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    request.passenger.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                RatingPill(
                  rating: request.passenger.ratingText,
                  hasRating: request.passenger.hasRating,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
