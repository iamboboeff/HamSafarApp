import 'package:flutter/material.dart';

import '../../../domain/ride_detail_state.dart';
import '../../../models/user_profile.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/common.dart';

/// Resolves a [RideDetailAccent] token to a palette color.
Color rideDetailAccentColor(BuildContext context, RideDetailAccent accent) {
  final hs = context.hs;
  return switch (accent) {
    RideDetailAccent.primary => hs.primary,
    RideDetailAccent.warm => hs.warm,
    RideDetailAccent.passenger => hs.passenger,
  };
}

/// Maps the string icon keys used by [RideDetailDerivedState] to icons.
IconData rideDetailIcon(String key) => switch (key) {
  'bolt' => Icons.bolt,
  'people' => Icons.people,
  'car' => Icons.directions_car,
  'calendar_clock' => Icons.event_available,
  _ => Icons.info_outline,
};

/// Ported from `RideLocationRow` in `RideDetailViews.swift`.
class RideLocationRow extends StatelessWidget {
  const RideLocationRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.showsConnector,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final bool showsConnector;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            if (showsConnector) ...[
              const SizedBox(height: 4),
              Container(
                width: 2,
                height: 26,
                color: accent.withValues(alpha: 0.18),
              ),
            ],
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HSText.headline,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: HSText.caption.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ported from `RideDetailPriceSeatsSummary` in `RideDetailComponents.swift`.
class RideDetailPriceSeatsSummary extends StatelessWidget {
  const RideDetailPriceSeatsSummary({
    super.key,
    required this.priceText,
    required this.seatsLeft,
  });

  final String priceText;
  final int seatsLeft;

  @override
  Widget build(BuildContext context) {
    Widget column(String value, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: HSText.caption.copyWith(color: context.secondaryText),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(priceText, 'за место'),
        const SizedBox(width: 16),
        column('$seatsLeft', 'свободно мест'),
      ],
    );
  }
}

/// Ported from `RideConditionRow` in `RideDetailViews.swift`.
class RideConditionRow extends StatelessWidget {
  const RideConditionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HSText.subheadlineSemibold),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: HSText.caption.copyWith(color: context.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ported from `RidePassengerDriverRow` in `RideDetailSections.swift`.
class RidePassengerDriverRow extends StatelessWidget {
  const RidePassengerDriverRow({
    super.key,
    required this.driver,
    required this.showsChevron,
    this.onTap,
  });

  final UserProfile driver;
  final bool showsChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final reviewCount = driver.completedTrips < 5 ? 5 : driver.completedTrips;
    final row = Row(
      children: [
        ProfileAvatar(
          initials: driver.initials,
          avatarBytes: driver.avatarBytes,
          size: 52,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name, style: HSText.headline),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.star, size: 13, color: hs.warm),
                  const SizedBox(width: 6),
                  Text(
                    '${driver.ratingText} • $reviewCount отзывов',
                    style: HSText.subheadline.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showsChevron)
          Icon(Icons.chevron_right, size: 16, color: context.secondaryText),
      ],
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

/// Ported from `RideDetailPlainSection` in `RideDetailSections.swift`.
class RideDetailPlainSection extends StatelessWidget {
  const RideDetailPlainSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BleedDivider(),
        const SizedBox(height: 14),
        Text(title, style: HSText.headline),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// Ported from `RideDetailSurfaceSection` in `RideDetailSections.swift`.
class RideDetailSurfaceSection extends StatelessWidget {
  const RideDetailSurfaceSection({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hs.cardBackground.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hs.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: HSText.headline),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
