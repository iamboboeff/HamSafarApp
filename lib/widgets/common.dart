import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'buttons.dart';

/// Ported from `SectionHeader` in `SharedUIComponents.swift`.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionTitle});

  final String title;
  final String? actionTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: HSText.headline),
        const Spacer(),
        if (actionTitle != null)
          Text(
            actionTitle!,
            style: HSText.subheadlineSemibold.copyWith(
              color: context.hs.primary,
            ),
          ),
      ],
    );
  }
}

/// Ported from `ToolbarIconButton` in `SharedUIComponents.swift`.
class ToolbarIconButton extends StatelessWidget {
  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badgeText,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return HSPressable(
      onTap: onTap,
      child: SizedBox(
        width: HSControlSize.toolbarButton + 14,
        height: HSControlSize.toolbarButton + 14,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: HSControlSize.toolbarButton,
              height: HSControlSize.toolbarButton,
              decoration: BoxDecoration(
                color: hs.cardBackground,
                borderRadius: BorderRadius.circular(HSRadius.small),
                border: Border.all(color: hs.stroke),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: hs.primary),
            ),
            if (badgeText != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hs.passenger,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    badgeText!,
                    style: HSText.caption2Bold.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ported from `TripRoutePoint` in `RideUIComponents.swift`.
class TripRoutePoint extends StatelessWidget {
  const TripRoutePoint({super.key, required this.city, required this.color});

  final String city;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(city, style: HSText.headline)),
      ],
    );
  }
}

/// Ported from `CompactBookedTripRoutePoint` in `RideUIComponents.swift`.
class CompactRoutePoint extends StatelessWidget {
  const CompactRoutePoint({super.key, required this.city, required this.color});

  final String city;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Ported from `ProfileAvatar` in `RideUIComponents.swift`. When [avatarBytes]
/// is non-null the photo is rendered as a clipped circle; otherwise the
/// gradient/initials fallback matches the Swift design.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    this.avatarBytes,
    this.size = 56,
  });

  final String initials;
  final Uint8List? avatarBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final bytes = avatarBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hs.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: hs.primary,
        ),
      ),
    );
  }
}

/// A star + rating value inside a pill — the recurring rating badge in cards.
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.rating, this.leading = const []});

  final String rating;

  /// Extra icons shown before the star (e.g. instant-booking bolt).
  final List<Widget> leading;

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
          for (final widget in leading) ...[widget, const SizedBox(width: 8)],
          Icon(Icons.star, size: 13, color: hs.warm),
          const SizedBox(width: 4),
          Text(rating, style: HSText.captionSemibold),
        ],
      ),
    );
  }
}

/// Ported from `RideMetaPill` in `RideUIComponents.swift`.
class RideMetaPill extends StatelessWidget {
  const RideMetaPill({super.key, required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hs.tint,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 6),
          Text(text, style: HSText.captionSemibold),
        ],
      ),
    );
  }
}

/// Ported from `CounterButton` in `SearchUIComponents.swift`.
class CounterButton extends StatelessWidget {
  const CounterButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return HSPressable(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hs.cardBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: hs.primary),
      ),
    );
  }
}

/// A hairline divider used to separate ride-detail sections.
///
/// The SwiftUI original bleeds past the screen padding
/// (`Divider().padding(.horizontal, -20)`); the Flutter port keeps it within
/// the content width for a predictable layout.
class BleedDivider extends StatelessWidget {
  const BleedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: context.hs.stroke.withValues(alpha: 0.85),
    );
  }
}

/// Ported from `TripFactRow` in `RideUIComponents.swift`.
class TripFactRow extends StatelessWidget {
  const TripFactRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: HSText.body.copyWith(color: context.secondaryText),
          ),
          const Spacer(),
          Text(value, style: HSText.body.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
