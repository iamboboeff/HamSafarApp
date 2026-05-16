import 'package:flutter/material.dart';

import '../../../models/app_tab.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';

/// Ported from `createRoleSelectionView` + `CreateRoleCard` /
/// `CreateRoleIllustration` in `CreateRideViews.swift` /
/// `CreateRideRoleComponents.swift`.
class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key, required this.onSelectRole});

  final ValueChanged<TravelMode> onSelectRole;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _RoleCard(
          title: 'Я водитель',
          subtitle: 'У меня есть свободные места',
          asset: 'assets/images/create_driver.png',
          onTap: () => onSelectRole(TravelMode.driver),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 18),
          color: context.hs.stroke,
        ),
        _RoleCard(
          title: 'Я пассажир',
          subtitle: 'Ищу попутную машину',
          asset: 'assets/images/create_passenger.png',
          onTap: () => onSelectRole(TravelMode.passenger),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Column(
              children: [
                SizedBox(
                  height: 208,
                  width: double.infinity,
                  child: Image.asset(asset, fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: HSText.title3.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.secondaryText,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Transform.translate(
                offset: const Offset(0, -6),
                child: const Icon(Icons.chevron_right, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
