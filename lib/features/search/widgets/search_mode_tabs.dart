import 'package:flutter/material.dart';

import '../../../models/app_tab.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';

/// Ported from `SearchModeTabs` / `SearchModeTabItem` in
/// `SearchResultsViews.swift`.
class SearchModeTabs extends StatelessWidget {
  const SearchModeTabs({
    super.key,
    required this.selection,
    required this.onSelect,
  });

  final HomeListingSection selection;
  final ValueChanged<HomeListingSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabItem(
          title: 'Водители',
          icon: Icons.airline_seat_recline_normal,
          isSelected: selection == HomeListingSection.rides,
          onTap: () => onSelect(HomeListingSection.rides),
        ),
        const SizedBox(width: 28),
        _TabItem(
          title: 'Пассажиры',
          icon: Icons.people_outline,
          isSelected: selection == HomeListingSection.passengers,
          onTap: () => onSelect(HomeListingSection.passengers),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? context.primaryText : context.secondaryText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: HSText.subheadlineSemibold.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 3,
            width: 64,
            decoration: BoxDecoration(
              color: isSelected ? context.hs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ],
      ),
    );
  }
}
