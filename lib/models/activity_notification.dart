import 'package:hamsafar/core/i18n/l10n.dart';

import '../domain/date_formatter.dart';

/// Ported from `ActivityNotification` in `Models.swift` — one row of the
/// in-app activity feed (booking confirmed, ride published, trip reminder…).
class ActivityNotification {
  ActivityNotification({
    String? id,
    this.backendId,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
  }) : id = id ?? backendId ?? 'activity-${DateTime.now().microsecondsSinceEpoch}';

  final String id;
  final String? backendId;
  final String title;
  final String body;
  final DateTime time;

  /// Free-form type from the backend (`"booking_confirmed"`, `"trip_reminder"`,
  /// …). Used both for the row icon and analytics.
  final String type;
  bool isRead;

  /// Ported from `ActivityNotification.timeText` — `Сегодня` → HH:mm,
  /// `Вчера`, otherwise `D месяц`.
  String get timeText {
    if (DateUtilsX.isToday(time)) return DateTextFormatter.time(time);
    if (DateUtilsX.isYesterday(time)) return tr('Вчера');
    return DateTextFormatter.dayMonthShort(time);
  }

  ActivityNotification copyWith({bool? isRead}) {
    return ActivityNotification(
      id: id,
      backendId: backendId,
      title: title,
      body: body,
      time: time,
      type: type,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Mirrors `DBActivityNotificationRow` decoding in `SupabaseServiceRows`.
  factory ActivityNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    return ActivityNotification(
      id: id,
      backendId: id,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      time: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      type: (json['type'] as String?) ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
