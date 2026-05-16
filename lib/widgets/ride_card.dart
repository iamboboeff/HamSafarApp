import 'package:flutter/material.dart';

import '../domain/date_formatter.dart';
import '../models/ride.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';
import 'common.dart';
import 'glass_card.dart';

/// Ported from `RideCardView` in `RideUIComponents.swift`.
class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.ride, this.onTap});

  final Ride ride;
  final VoidCallback? onTap;

  bool get _isSoldOut => ride.availableSeatsCount <= 0;

  String get _departureDayLabel {
    if (DateUtilsX.isToday(ride.departureDate)) return 'Сегодня';
    if (DateUtilsX.isTomorrow(ride.departureDate)) return 'Завтра';
    return DateTextFormatter.dayMonthShort(ride.departureDate);
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final seats = ride.availableSeatsCount;

    return HSPressable(
      onTap: onTap,
      pressedScale: 0.99,
      child: Opacity(
        opacity: _isSoldOut ? 0.58 : 1,
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateTextFormatter.time(ride.departureDate),
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
                  if (_isSoldOut)
                    Text('Мест нет', style: HSText.captionBold)
                  else
                    Text(
                      'Свободно $seats ${seats == 1 ? 'место' : 'места'}',
                      style: HSText.captionSemibold.copyWith(color: hs.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TripRoutePoint(city: ride.fromCity, color: hs.primary),
                        const SizedBox(height: 10),
                        TripRoutePoint(city: ride.toCity, color: hs.primary),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ride.formattedPrice(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'за место',
                        style: HSText.caption.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  ProfileAvatar(
                    initials: ride.driver.initials,
                    avatarBytes: ride.driver.avatarBytes,
                    size: 42,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.driver.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (ride.carModel.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            ride.carModel.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HSText.caption.copyWith(
                              color: context.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  RatingPill(
                    rating: ride.driver.ratingText,
                    leading: [
                      if (ride.instantBookingEnabled)
                        Icon(Icons.bolt, size: 13, color: hs.primary),
                      if (ride.maxTwoPassengersInBackEnabled)
                        Icon(Icons.people, size: 13, color: hs.warm),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
