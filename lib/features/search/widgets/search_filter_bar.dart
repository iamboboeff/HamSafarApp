import 'package:flutter/material.dart';

import '../../../domain/date_formatter.dart';
import '../../../models/ride_search.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';

/// Ported from `DateCountChip` in `SearchUIComponents.swift`.
class DateCountChip extends StatelessWidget {
  const DateCountChip({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final SearchDateOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? hs.primary : hs.cardBackground,
          borderRadius: BorderRadius.circular(HSRadius.small),
          border: Border.all(
            color: isSelected ? hs.primary.withValues(alpha: 0.5) : hs.stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.title,
              style: HSText.subheadlineSemibold.copyWith(
                color: isSelected ? Colors.white : context.primaryText,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: HSText.subheadlineSemibold.copyWith(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.82)
                    : context.secondaryText,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${option.count}',
              style: HSText.subheadlineSemibold.copyWith(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.88)
                    : hs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ported from `SearchResultsFilterBar` in `SearchUIComponents.swift`.
///
/// Just the horizontal date chips now — the date is picked from the route
/// summary card above, so the leading calendar icon and the trailing filter
/// button were removed.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.dateOptions,
    required this.isAllDatesSelected,
    required this.selectedDate,
    required this.onSelectDateOption,
  });

  final List<SearchDateOption> dateOptions;
  final bool isAllDatesSelected;
  final DateTime selectedDate;
  final ValueChanged<SearchDateOption> onSelectDateOption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: dateOptions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final option = dateOptions[index];
          final selected = option.isAllDates
              ? isAllDatesSelected
              : (!isAllDatesSelected &&
                    DateUtilsX.isSameDay(option.date, selectedDate));
          return DateCountChip(
            option: option,
            isSelected: selected,
            onTap: () => onSelectDateOption(option),
          );
        },
      ),
    );
  }
}
