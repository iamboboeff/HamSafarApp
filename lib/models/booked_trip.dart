import '../domain/date_formatter.dart';
import 'ride.dart';
import 'trip_enums.dart';

/// Ported from `BookedTrip` in `Models.swift`.
class BookedTrip {
  const BookedTrip({
    required this.id,
    this.backendId,
    required this.ride,
    required this.seatsBooked,
    required this.status,
    required this.category,
    required this.role,
    this.matchingCount = 0,
    this.searchPassengersEnabled = false,
    this.confirmedPassengerCount = 0,
    this.pendingPassengerCount = 0,
    this.cancelReason,
  });

  final String id;
  final String? backendId;
  final Ride ride;
  final int seatsBooked;
  final String status;
  final TripCategory category;
  final TripRole role;
  final int matchingCount;
  final bool searchPassengersEnabled;
  final int confirmedPassengerCount;
  final int pendingPassengerCount;

  /// Reason a booking was cancelled, as set server-side. `'expired'` marks an
  /// auto-expired pending request so the UI can say "Истекла" rather than
  /// "Отменена". Null for ordinary cancellations.
  final String? cancelReason;

  BookedTrip copyWith({
    String? status,
    TripCategory? category,
    bool? searchPassengersEnabled,
    int? confirmedPassengerCount,
    int? pendingPassengerCount,
  }) {
    return BookedTrip(
      id: id,
      backendId: backendId,
      ride: ride,
      seatsBooked: seatsBooked,
      status: status ?? this.status,
      category: category ?? this.category,
      role: role,
      matchingCount: matchingCount,
      searchPassengersEnabled:
          searchPassengersEnabled ?? this.searchPassengersEnabled,
      confirmedPassengerCount:
          confirmedPassengerCount ?? this.confirmedPassengerCount,
      pendingPassengerCount:
          pendingPassengerCount ?? this.pendingPassengerCount,
      cancelReason: cancelReason,
    );
  }

  bool get isCancelled => status.toLowerCase().contains('отмен');

  /// True when this booking was auto-expired (a pending request the driver
  /// never answered within the window), as opposed to a manual cancellation.
  bool get isExpired => isCancelled && cancelReason == 'expired';

  bool get noPassengerFound {
    if (role != TripRole.driver || isCancelled || !ride.hasFinished) {
      return false;
    }
    return confirmedPassengerCount == 0;
  }

  bool get isCompleted {
    if (isCancelled) return false;
    return noPassengerFound ||
        status.toLowerCase().contains('заверш') ||
        ride.hasFinished;
  }

  bool get isPendingConfirmation {
    final lower = status.toLowerCase();
    return lower.contains('ожида') ||
        lower.contains('ждёт') ||
        lower.contains('ждет');
  }

  bool get isConfirmed => status.toLowerCase().contains('подтверж');

  bool get isInProgress {
    if (isCancelled || !ride.isInProgress) return false;
    return switch (role) {
      TripRole.driver => confirmedPassengerCount > 0,
      TripRole.passenger => isConfirmed,
    };
  }

  String get displayStatus {
    if (isCancelled) return isExpired ? 'Истекла' : 'Отменена';
    if (noPassengerFound) return 'Пассажир не найден';
    if (isCompleted) return 'Завершена';
    if (isInProgress) return 'В пути';
    return switch (role) {
      TripRole.driver => 'Опубликована',
      TripRole.passenger =>
        isPendingConfirmation
            ? 'Ждёт подтверждения'
            : (isConfirmed ? 'Подтверждена' : status),
    };
  }

  TripCategory get effectiveCategory =>
      (isCancelled || isCompleted) ? TripCategory.history : TripCategory.active;

  String get departureClockText => DateTextFormatter.time(ride.departureDate);

  String get departureDayText {
    if (DateUtilsX.isToday(ride.departureDate)) return 'Сегодня';
    if (DateUtilsX.isTomorrow(ride.departureDate)) return 'Завтра';
    return DateTextFormatter.dayMonthYear(ride.departureDate);
  }
}
