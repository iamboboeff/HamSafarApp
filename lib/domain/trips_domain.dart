import '../models/booked_trip.dart';
import '../models/passenger_request.dart';
import '../models/ride.dart';
import '../models/trip_enums.dart';
import '../models/user_profile.dart';

/// Ported from `AppTripsDomain` in `AppTripsDomain.swift`.
abstract final class TripsDomain {
  /// A ride is hidden from passengers if the owning driver-trip is no longer
  /// active or has search disabled.
  static bool isRideVisibleToPassengers(
    Ride ride,
    List<BookedTrip> bookedTrips,
  ) {
    BookedTrip? driverTrip;
    for (final trip in bookedTrips) {
      if (trip.role == TripRole.driver && trip.ride.id == ride.id) {
        driverTrip = trip;
        break;
      }
    }
    if (driverTrip == null) return true;
    return driverTrip.effectiveCategory == TripCategory.active &&
        driverTrip.searchPassengersEnabled;
  }

  static List<Ride> matchingVisibleRides({
    required List<Ride> rides,
    required List<BookedTrip> bookedTrips,
    required String fromCity,
    required String toCity,
    int minimumSeats = 1,
    required bool Function(UserProfile) isCurrentUser,
  }) {
    return rides.where((ride) {
      return ride.fromCity == fromCity &&
          ride.toCity == toCity &&
          !ride.hasFinished &&
          !isCurrentUser(ride.driver) &&
          isRideVisibleToPassengers(ride, bookedTrips) &&
          // A fully-booked ride (0 free seats) must not appear in passenger
          // search results (QA #32).
          ride.availableSeatsCount >= minimumSeats;
    }).toList();
  }

  static List<PassengerRequest> matchingVisiblePassengerRequests({
    required List<PassengerRequest> passengerRequests,
    required String fromCity,
    required String toCity,
    required bool Function(UserProfile) isCurrentUser,
  }) {
    final from = fromCity.toLowerCase();
    final to = toCity.toLowerCase();
    return passengerRequests.where((request) {
      return request.effectiveCategory == TripCategory.active &&
          request.fromCity.toLowerCase().contains(from) &&
          request.toCity.toLowerCase().contains(to) &&
          !isCurrentUser(request.passenger);
    }).toList();
  }

  /// Ported from `matchingPassengerRequests(for ride:)` — passenger requests
  /// that fit a given ride's route and seat availability.
  static List<PassengerRequest> matchingPassengerRequestsForRide({
    required List<PassengerRequest> passengerRequests,
    required Ride ride,
    required bool Function(UserProfile) isCurrentUser,
  }) {
    return passengerRequests.where((request) {
      return request.effectiveCategory == TripCategory.active &&
          request.fromCity == ride.fromCity &&
          request.toCity == ride.toCity &&
          request.seatsNeeded <= ride.availableSeatsCount &&
          !isCurrentUser(request.passenger);
    }).toList();
  }
}
