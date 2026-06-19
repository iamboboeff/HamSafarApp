import 'package:hamsafar/core/i18n/l10n.dart';

import '../models/residence_country.dart';
import '../models/ride.dart';
import '../models/ride_passenger_booking.dart';
import 'date_formatter.dart';

/// Ported from `RideDetailSeatState` in `RideDetailBookingDomain.swift`.
class RideSeatState {
  const RideSeatState({
    required this.confirmedRidePassengers,
    required this.currentSeatsLeft,
  });

  final List<RidePassengerBooking> confirmedRidePassengers;
  final int currentSeatsLeft;
}

/// Ported from `RideDetailBookingDomain` in `RideDetailBookingDomain.swift`.
abstract final class RideBookingDomain {
  static RideSeatState seatState({
    required Ride ride,
    required List<RidePassengerBooking> ridePassengers,
  }) {
    final totalAvailableSeats = [
      ride.effectiveAvailableSeatLabels.length,
      ride.seatsLeft,
    ].reduce((a, b) => a > b ? a : b);
    final occupiedSeats = ridePassengers
        .where((b) => !b.status.toLowerCase().contains('отмен'))
        .fold<int>(0, (sum, b) => sum + b.seatsCount);
    final currentSeatsLeft = totalAvailableSeats > 0
        ? (totalAvailableSeats - occupiedSeats).clamp(0, totalAvailableSeats)
        : 0;
    return RideSeatState(
      confirmedRidePassengers: ridePassengers
          .where((b) => b.isConfirmed)
          .toList(),
      currentSeatsLeft: currentSeatsLeft,
    );
  }

  static int automaticBookingSeatCount({
    required int currentSeatsLeft,
    required int requestedPassengers,
  }) {
    if (currentSeatsLeft <= 0) return 0;
    final requested = requestedPassengers < 1 ? 1 : requestedPassengers;
    return requested < currentSeatsLeft ? requested : currentSeatsLeft;
  }

  static String bookingCostText({
    required int pricePerSeat,
    required ResidenceCountry pricingCountry,
    required int seatsCount,
  }) {
    return pricingCountry.formatAmount(pricePerSeat * seatsCount);
  }

  static String arrivalTimeText(Ride ride) =>
      DateTextFormatter.time(ride.departureDate.add(ride.travelDuration));

  static String bookingActionTitle(Ride ride) =>
      ride.instantBookingEnabled
      ? tr('Забронировать сразу')
      : tr('Отправить заявку');

  static String rideDriverSeatsText(Ride ride) =>
      '${ride.effectiveAvailableSeatLabels.length}';
}
