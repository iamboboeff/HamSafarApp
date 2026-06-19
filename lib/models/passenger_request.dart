import 'package:hamsafar/core/i18n/l10n.dart';

import '../domain/date_formatter.dart';
import 'residence_country.dart';
import 'trip_enums.dart';
import 'user_profile.dart';

/// Ported from `PassengerRequest` in `Models.swift`.
class PassengerRequest {
  const PassengerRequest({
    required this.id,
    this.backendId,
    required this.passenger,
    required this.fromCity,
    required this.toCity,
    required this.departureDate,
    required this.seatsNeeded,
    this.budget = 0,
    this.note = '',
    this.status = 'Активно',
    this.budgetCountry = ResidenceCountry.tajikistan,
  });

  final String id;
  final String? backendId;
  final UserProfile passenger;
  final String fromCity;
  final String toCity;
  final DateTime departureDate;
  final int seatsNeeded;
  final int budget;
  final String note;
  final String status;
  final ResidenceCountry budgetCountry;

  String get budgetText => budgetCountry.formatAmount(budget);

  String get departureText => DateTextFormatter.dayMonthTime(departureDate);

  String get departureClockText => DateTextFormatter.time(departureDate);

  String get departureDayText {
    if (DateUtilsX.isToday(departureDate)) return tr('Сегодня');
    if (DateUtilsX.isTomorrow(departureDate)) return tr('Завтра');
    return DateTextFormatter.dayMonthYear(departureDate);
  }

  bool get isCancelled => status.toLowerCase().contains('отмен');

  bool get isCompleted =>
      status.toLowerCase().contains('заверш') ||
      departureDate.isBefore(DateTime.now());

  String get displayStatus {
    if (isCancelled) return tr('Отменён');
    if (isCompleted) return tr('Водитель не найден');
    return tr('Активно');
  }

  TripCategory get effectiveCategory =>
      (isCancelled || isCompleted) ? TripCategory.history : TripCategory.active;
}
