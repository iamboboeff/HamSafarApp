/// A user's subscription to be notified when a ride is published on a route
/// (the "оповещение о поездке" / ride-alert feature). Backed by the
/// `ride_alerts` table.
class RideAlert {
  const RideAlert({
    required this.id,
    required this.fromCity,
    required this.toCity,
  });

  final String id;
  final String fromCity;
  final String toCity;

  factory RideAlert.fromRow(Map<String, dynamic> row) => RideAlert(
        id: row['id'] as String,
        fromCity: (row['from_city'] as String?) ?? '',
        toCity: (row['to_city'] as String?) ?? '',
      );
}
