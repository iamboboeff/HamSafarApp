import 'package:hamsafar/core/i18n/l10n.dart';

import '../domain/date_formatter.dart';
import 'user_profile.dart';

/// Ported from `RidePassengerBooking` in `Models.swift`.
class RidePassengerBooking {
  const RidePassengerBooking({
    required this.id,
    required this.backendId,
    required this.passenger,
    required this.seatsCount,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String backendId;
  final UserProfile passenger;
  final int seatsCount;
  final String status;
  final DateTime? createdAt;

  bool get isPending {
    final lower = status.toLowerCase();
    return lower.contains('ожида') ||
        lower.contains('ждёт') ||
        lower.contains('ждет');
  }

  bool get isConfirmed {
    final lower = status.toLowerCase();
    return lower.contains('подтверж') ||
        lower.contains('в пути') ||
        lower.contains('заверш');
  }

  String get requestBadgeTitle {
    if (!isPending) return tr('Обновлена');
    final created = createdAt;
    if (created == null) return tr('Ожидает ответа');
    final minutes = DateTime.now().difference(created).inMinutes;
    return minutes <= 15 ? tr('Новая') : tr('Ожидает ответа');
  }

  String? get sentAtText {
    final created = createdAt;
    if (created == null) return null;
    return trf('Отправлено {time}', {
      'time': DateTextFormatter.dayMonthTime(created),
    });
  }
}
