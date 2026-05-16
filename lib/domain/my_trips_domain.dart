import '../models/booked_trip.dart';
import '../models/passenger_request.dart';
import '../models/ride.dart';
import '../models/trip_enums.dart';
import '../models/trip_section.dart';
import '../models/user_profile.dart';
import 'trips_domain.dart';

/// Ported from `MyTripsDomain` in `MyTripsDomain.swift`.
abstract final class MyTripsDomain {
  static List<MyTripsDisplayItem> displayedItems({
    required TripSection section,
    required List<BookedTrip> bookedTrips,
    required List<PassengerRequest> passengerRequests,
  }) {
    final tripItems = <MyTripsDisplayItem>[];
    final requestItems = <MyTripsDisplayItem>[];

    switch (section) {
      case TripSection.active:
        tripItems.addAll(
          bookedTrips
              .where(
                (t) =>
                    t.role == TripRole.driver &&
                    t.effectiveCategory == TripCategory.active,
              )
              .map(TripDisplayItem.new),
        );
      case TripSection.requests:
        tripItems.addAll(
          bookedTrips
              .where(
                (t) =>
                    t.role == TripRole.passenger &&
                    t.effectiveCategory == TripCategory.active,
              )
              .map(TripDisplayItem.new),
        );
        requestItems.addAll(
          passengerRequests
              .where((r) => r.effectiveCategory == TripCategory.active)
              .map(RequestDisplayItem.new),
        );
      case TripSection.history:
        tripItems.addAll(
          bookedTrips
              .where((t) => t.effectiveCategory == TripCategory.history)
              .map(TripDisplayItem.new),
        );
        requestItems.addAll(
          passengerRequests
              .where((r) => r.effectiveCategory == TripCategory.history)
              .map(RequestDisplayItem.new),
        );
    }

    return [...tripItems, ...requestItems]
      ..sort((a, b) => b.departureDate.compareTo(a.departureDate));
  }

  static String emptyStateTitle(TripSection section) => switch (section) {
    TripSection.active => 'Активных поездок пока нет',
    TripSection.requests => 'Запросов пока нет',
    TripSection.history => 'История поездок пока пуста',
  };

  static String emptyStateSubtitle(TripSection section) => switch (section) {
    TripSection.active => 'Создайте новую поездку, и она появится здесь.',
    TripSection.requests =>
      'Ваши запросы пассажира и отправленные брони появятся здесь.',
    TripSection.history =>
      'Завершённые поездки и старые запросы появятся здесь позже.',
  };

  static int matchingRideCountForTrip({
    required BookedTrip trip,
    required List<Ride> rides,
    required List<BookedTrip> bookedTrips,
    required bool Function(UserProfile) isCurrentUser,
  }) {
    if (trip.role != TripRole.passenger) return trip.matchingCount;
    return TripsDomain.matchingVisibleRides(
      rides: rides,
      bookedTrips: bookedTrips,
      fromCity: trip.ride.fromCity,
      toCity: trip.ride.toCity,
      minimumSeats: trip.seatsBooked,
      isCurrentUser: isCurrentUser,
    ).length;
  }

  static int matchingRideCountForRequest({
    required PassengerRequest request,
    required List<Ride> rides,
    required List<BookedTrip> bookedTrips,
    required bool Function(UserProfile) isCurrentUser,
  }) {
    return TripsDomain.matchingVisibleRides(
      rides: rides,
      bookedTrips: bookedTrips,
      fromCity: request.fromCity,
      toCity: request.toCity,
      minimumSeats: request.seatsNeeded,
      isCurrentUser: isCurrentUser,
    ).length;
  }

  static int passengerRequestCount({
    required BookedTrip trip,
    required List<PassengerRequest> passengerRequests,
    required bool Function(UserProfile) isCurrentUser,
  }) {
    if (trip.role != TripRole.driver || !trip.searchPassengersEnabled) {
      return 0;
    }
    return TripsDomain.matchingPassengerRequestsForRide(
      passengerRequests: passengerRequests,
      ride: trip.ride,
      isCurrentUser: isCurrentUser,
    ).length;
  }
}
