import 'package:flutter/material.dart';

import '../../../models/ride_search.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/common.dart';

/// Ported from `HomeRecentSearchesSection` / `SearchHistoryRow` in
/// `HomeSearchComponents.swift`.
class RecentSearchesSection extends StatelessWidget {
  const RecentSearchesSection({
    super.key,
    required this.items,
    required this.onSelect,
  });

  final List<LocationSearchHistoryItem> items;
  final ValueChanged<LocationSearchHistoryItem> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'История поиска'),
        const SizedBox(height: HSSpacing.compact),
        for (final item in items)
          GestureDetector(
            onTap: () => onSelect(item),
            behavior: HitTestBehavior.opaque,
            child: _SearchHistoryRow(item: item),
          ),
      ],
    );
  }
}

class _SearchHistoryRow extends StatelessWidget {
  const _SearchHistoryRow({required this.item});

  final LocationSearchHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hs.secondarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 18, color: hs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.from} → ${item.to}',
                  style: HSText.subheadlineSemibold,
                ),
                const SizedBox(height: 3),
                Text(
                  'Быстрый повтор поиска',
                  style: HSText.caption.copyWith(color: context.secondaryText),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 14, color: context.secondaryText),
        ],
      ),
    );
  }
}
