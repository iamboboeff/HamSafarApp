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
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.dateOptions,
    required this.isAllDatesSelected,
    required this.selectedDate,
    required this.onOpenCalendar,
    required this.onSelectDateOption,
    this.onOpenFilters,
    this.showsFilterButton = true,
  });

  final List<SearchDateOption> dateOptions;
  final bool isAllDatesSelected;
  final DateTime selectedDate;
  final VoidCallback onOpenCalendar;
  final ValueChanged<SearchDateOption> onSelectDateOption;
  final VoidCallback? onOpenFilters;
  final bool showsFilterButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconButton(icon: Icons.calendar_today, onTap: onOpenCalendar),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 12),
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
          ),
        ),
        if (showsFilterButton && onOpenFilters != null) ...[
          const SizedBox(width: 8),
          _IconButton(icon: Icons.tune, onTap: onOpenFilters!),
        ],
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hs.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hs.stroke),
        ),
        child: Icon(icon, size: 18, color: hs.primary),
      ),
    );
  }
}
