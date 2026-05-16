import '../models/ride_search.dart';
import 'date_formatter.dart';

/// Ported from `groupedDateOptions` / `searchDateLabel` in
/// `SearchUIComponents.swift`.
List<SearchDateOption> groupedDateOptions({
  required List<DateTime> dates,
  required DateTime selectedDate,
  bool includeSelectedDateIfMissing = true,
}) {
  final grouped = <DateTime, int>{};
  for (final date in dates) {
    final day = DateUtilsX.startOfDay(date);
    grouped[day] = (grouped[day] ?? 0) + 1;
  }

  final days = grouped.keys.toList()..sort();
  final selectedDay = DateUtilsX.startOfDay(selectedDate);
  if (includeSelectedDateIfMissing && !grouped.containsKey(selectedDay)) {
    days.insert(0, selectedDay);
  }

  // De-duplicate while keeping order.
  final orderedDays = <DateTime>[];
  for (final day in days) {
    if (!orderedDays.contains(day)) orderedDays.add(day);
  }

  final allDates = SearchDateOption(
    key: 'all_dates',
    date: selectedDay,
    title: 'Все даты',
    count: dates.length,
    isAllDates: true,
  );

  final dayOptions = orderedDays.map((day) {
    return SearchDateOption(
      key: day.toIso8601String(),
      date: day,
      title: _searchDateLabel(day),
      count: grouped[day] ?? 0,
      isAllDates: false,
    );
  });

  return [allDates, ...dayOptions];
}

String _searchDateLabel(DateTime date) {
  if (DateUtilsX.isToday(date)) return 'Сегодня';
  if (DateUtilsX.isTomorrow(date)) return 'Завтра';
  return DateTextFormatter.dayMonthShort(date);
}
