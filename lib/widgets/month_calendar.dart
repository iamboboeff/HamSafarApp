import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/date_formatter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Shared scrollable 12-month calendar, ported from `HomeSearchCalendarView`
/// (`HomeSearchComponents.swift`) and `CreateCalendarView`
/// (`CreateRidePassengerComponents.swift`) — they were near-identical.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.selectedDate,
    required this.earliestDate,
    required this.onSelect,
    this.scrollHeight = 560,
  });

  final DateTime selectedDate;
  final DateTime earliestDate;
  final ValueChanged<DateTime> onSelect;

  /// Fixed height for the scrollable months area, or `null` to fill the
  /// available vertical space (the parent must provide bounded height).
  final double? scrollHeight;

  static const _weekdaySymbols = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final months = List.generate(
      12,
      (offset) => DateTime(earliestDate.year, earliestDate.month + offset),
    );
    final list = ListView.separated(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      itemCount: months.length,
      separatorBuilder: (_, _) => const SizedBox(height: 22),
      itemBuilder: (context, index) => _MonthSection(
        month: months[index],
        selected: selectedDate,
        earliest: earliestDate,
        onSelect: onSelect,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final symbol in _weekdaySymbols)
                Expanded(
                  child: Text(
                    symbol,
                    textAlign: TextAlign.center,
                    style: HSText.subheadlineSemibold.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // A non-finite height (e.g. double.infinity) would give the inner
        // ListView an unbounded viewport and render nothing, so treat it the
        // same as null and fill the available space instead.
        if (scrollHeight == null || !scrollHeight!.isFinite)
          Expanded(child: list)
        else
          SizedBox(height: scrollHeight, child: list),
      ],
    );
  }
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.selected,
    required this.earliest,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime earliest;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = firstOfMonth.weekday - 1; // Mon=1..Sun=7

    final cells = <Widget>[];
    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isEnabled = !date.isBefore(DateUtilsX.startOfDay(earliest));
      final isSelected = DateUtilsX.isSameDay(date, selected);
      final isToday = DateUtilsX.isToday(date);

      cells.add(
        GestureDetector(
          onTap: isEnabled ? () => onSelect(date) : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? hs.primary : Colors.transparent,
              border: isToday && !isSelected
                  ? Border.all(color: hs.primary, width: 1.5)
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: !isEnabled
                    ? context.secondaryText.withValues(alpha: 0.4)
                    : isSelected
                    ? Colors.white
                    : context.primaryText,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('LLLL', 'ru_RU').format(month).toLowerCase(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 8,
          children: cells,
        ),
      ],
    );
  }
}
