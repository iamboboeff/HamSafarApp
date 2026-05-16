import '../models/car_profile.dart';
import '../models/ride.dart';

/// Ported from `CreateRidePresentationDomain` in
/// `CreateRidePresentationDomain.swift`.
abstract final class CreateRidePresentation {
  static RidePoint departurePoint({
    required RidePoint? selection,
    required String customText,
    required bool isCustomSelected,
    required String cityName,
  }) {
    if (isCustomSelected) {
      final trimmed = customText.trim();
      if (trimmed.isNotEmpty) return RidePoint.custom(cityName, trimmed);
    }
    return selection ?? RidePoint.meeting(cityName);
  }

  static RidePoint arrivalPoint({
    required RidePoint? selection,
    required String customText,
    required bool isCustomSelected,
    required String cityName,
  }) {
    if (isCustomSelected) {
      final trimmed = customText.trim();
      if (trimmed.isNotEmpty) return RidePoint.custom(cityName, trimmed);
    }
    return selection ?? RidePoint.destination(cityName);
  }

  static List<RidePoint> meetingOptions(String cityName, RidePointKind kind) =>
      RidePoint.popularPlaces(cityName, kind);

  static int maxDriverSeats(CarProfile carProfile) {
    final parsed = int.tryParse(carProfile.seats) ?? 4;
    return parsed.clamp(1, 4);
  }

  static int driverSeatLimit(
    CarProfile carProfile, {
    required bool maxTwoPassengersInBack,
  }) {
    final maxSeats = maxDriverSeats(carProfile);
    return maxTwoPassengersInBack ? (maxSeats < 3 ? maxSeats : 3) : maxSeats;
  }

  /// Combines the picked day and the picked time-of-day into one [DateTime].
  static DateTime mergedDepartureDate({
    required DateTime departureDate,
    required DateTime departureTime,
  }) {
    return DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
      departureTime.hour,
      departureTime.minute,
    );
  }

  /// Mirrors `syncDriverSeatSelection` — clamps the seat count and rebuilds the
  /// available seat labels list.
  static ({int seats, List<String> labels}) syncDriverSeatSelection({
    required int seats,
    required CarProfile carProfile,
    required bool maxTwoPassengersInBack,
  }) {
    final limit = driverSeatLimit(
      carProfile,
      maxTwoPassengersInBack: maxTwoPassengersInBack,
    );
    final available = SeatLayout.allSeatLabels.take(limit).toList();
    final clamped = seats.clamp(1, available.length);
    return (seats: clamped, labels: available.take(clamped).toList());
  }
}
