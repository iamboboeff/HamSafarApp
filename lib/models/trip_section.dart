import 'booked_trip.dart';
import 'passenger_request.dart';

/// Ported from `TripSection` in `MyTripsViews.swift`.
enum TripSection {
  active('Активные'),
  requests('Запросы'),
  history('История');

  const TripSection(this.title);
  final String title;
}

/// Ported from `MyTripsDisplayItem` in `MyTripsViews.swift` — a row in the My
/// Trips list is either a booked trip or a passenger request.
sealed class MyTripsDisplayItem {
  const MyTripsDisplayItem();

  String get id;
  DateTime get departureDate;
}

class TripDisplayItem extends MyTripsDisplayItem {
  const TripDisplayItem(this.trip);
  final BookedTrip trip;

  @override
  String get id => 'trip-${trip.role}-${trip.backendId ?? trip.id}';

  @override
  DateTime get departureDate => trip.ride.departureDate;
}

class RequestDisplayItem extends MyTripsDisplayItem {
  const RequestDisplayItem(this.request);
  final PassengerRequest request;

  @override
  String get id => 'request-${request.backendId ?? request.id}';

  @override
  DateTime get departureDate => request.departureDate;
}
