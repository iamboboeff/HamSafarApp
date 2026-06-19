import 'package:flutter/material.dart';

import 'package:hamsafar/core/i18n/l10n.dart';

import '../../../models/app_tab.dart';
import '../../../theme/app_colors.dart';

/// Direct port of `CreateRoleCard` + `CreateRoleIllustration` from
/// `CreateRideRoleComponents.swift`. Two cards stacked with a divider,
/// each: large illustration (208 pt height, full width, with a mode-specific
/// horizontal pad), title (28 pt bold rounded), subtitle (medium).
///
/// On small phones the illustration may not fit at the Swift-fixed 208 pt —
/// here we cap it via [Flexible] so the title + subtitle never get pushed
/// under the floating tab bar.
class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key, required this.onSelectRole});

  final ValueChanged<TravelMode> onSelectRole;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    // Use `Expanded` (not `Flexible`) so each card *always* claims exactly
    // half of the available vertical space. Result: divider sits on the
    // geometric centre of the screen, both cards mirror each other in
    // height, and content inside each card is vertically centred via the
    // inner Column's `mainAxisAlignment: center`.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _RoleCard(
            mode: TravelMode.driver,
            title: tr('Я водитель'),
            subtitle: tr('У меня есть свободные места'),
            asset: 'assets/images/create_driver.png',
            onTap: () => onSelectRole(TravelMode.driver),
          ),
        ),
        Container(height: 1, color: hs.stroke),
        Expanded(
          child: _RoleCard(
            mode: TravelMode.passenger,
            title: tr('Я пассажир'),
            subtitle: tr('Ищу попутную машину'),
            asset: 'assets/images/create_passenger.png',
            onTap: () => onSelectRole(TravelMode.passenger),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onTap,
  });

  final TravelMode mode;
  final String title;
  final String subtitle;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Swift uses `padding(.horizontal, mode == .driver ? 8 : 18)` on the
    // image to balance the artwork. Kept identical here for visual parity.
    final illustrationHPad = mode == TravelMode.driver ? 8.0 : 18.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // Inner column centres the image+text block within the card's
          // half-of-screen slot — keeps both cards visually symmetric
          // around the divider.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: illustrationHPad,
                    vertical: 4,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 208),
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          // Chevron: Swift puts it on the .trailing edge of the ZStack with
          // padding(.trailing, 8) + offset(y: -6).
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Transform.translate(
              offset: const Offset(0, -6),
              child: Center(
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
