import 'package:intl/intl.dart';

import 'package:hamsafar/core/i18n/l10n.dart';

/// Ported from `DateTextFormatter` in `Models.swift`.
///
/// All output uses the Russian locale; [_normalized] mirrors the Swift helper
/// that strips the trailing `г.` year marker and capitalizes the first letter.
abstract final class DateTextFormatter {
  static const _locale = 'ru_RU';

  static String _normalized(String value) {
    var result = value
        .replaceAll(' г.', '')
        .replaceAll(' г.', '')
        .replaceAll(' г.', '')
        .replaceAll('.', '')
        .replaceAll(' г', '')
        .trim();
    if (result.isEmpty) return result;
    return result[0].toUpperCase() + result.substring(1);
  }

  static String dayMonth(DateTime date) =>
      _normalized(DateFormat('d MMM', _locale).format(date));

  static String dayMonthShort(DateTime date) => dayMonth(date);

  static String dayMonthYear(DateTime date) =>
      _normalized(DateFormat('d MMM y', _locale).format(date));

  static String monthYear(DateTime date) =>
      _normalized(DateFormat('MMM y', _locale).format(date));

  static String time(DateTime date) => DateFormat.Hm(_locale).format(date);

  static String dayMonthTime(DateTime date) =>
      _normalized(DateFormat('d MMM, HH:mm', _locale).format(date));

  /// "EEEE, d MMMM" capitalized — used for ride-detail headers.
  static String weekdayDayMonth(DateTime date) {
    final formatted = DateFormat('EEEE, d MMMM', _locale).format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Section headers in search results: "Сегодня, понедельник" etc.
  static String resultsSectionTitle(DateTime date) {
    final weekday = DateFormat('EEEE', _locale).format(date).toLowerCase();
    if (DateUtilsX.isToday(date)) {
      return trf('Сегодня, {weekday}', {'weekday': weekday});
    }
    if (DateUtilsX.isTomorrow(date)) {
      return trf('Завтра, {weekday}', {'weekday': weekday});
    }
    final full = DateFormat('d MMM, EEEE', _locale).format(date);
    return _normalized(full);
  }
}

/// Small calendar helpers equivalent to `Calendar.current.isDateInToday` etc.
abstract final class DateUtilsX {
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isTomorrow(DateTime date) =>
      isSameDay(date, DateTime.now().add(const Duration(days: 1)));

  static bool isYesterday(DateTime date) =>
      isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));
}
