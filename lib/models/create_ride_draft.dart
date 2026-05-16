import 'location.dart';
import 'residence_country.dart';
import 'ride.dart';

/// Ported from `CreateRideDraft` in `CreateRideDraft.swift`.
///
/// Held as mutable state inside the Create Ride screen (the SwiftUI original
/// is a `@State` struct mutated through bindings).
class CreateRideDraft {
  CreateRideDraft()
    : departureLocation = LocationDirectory.cityNamed('Ташкент'),
      destinationLocation = LocationDirectory.cityNamed('Бухара'),
      departureDate = DateTime.now().add(const Duration(days: 1)),
      departureTime = DateTime.now().add(const Duration(days: 1, hours: 5)),
      seats = 1,
      availableSeatLabels = SeatLayout.seatLabels(4);

  LocationSelection departureLocation;
  LocationSelection destinationLocation;
  RidePoint? selectedDepartureMeetingPoint;
  RidePoint? selectedArrivalMeetingPoint;
  String customDepartureMeetingText = '';
  String customArrivalMeetingText = '';
  bool isCustomDepartureMeetingSelected = false;
  bool isCustomArrivalMeetingSelected = false;
  DateTime departureDate;
  DateTime departureTime;
  int seats;
  List<String> availableSeatLabels;
  bool maxTwoPassengersInBack = false;
  bool instantBookingEnabled = false;
  String priceInput = '';
  String notes = '';
  bool hasSelectedPassengerFrom = false;
  bool hasSelectedPassengerTo = false;
  bool hasSelectedDriverFrom = false;
  bool hasSelectedDriverTo = false;

  bool get isUsingDefaultRouteSelection =>
      !hasSelectedPassengerFrom &&
      !hasSelectedPassengerTo &&
      !hasSelectedDriverFrom &&
      !hasSelectedDriverTo &&
      selectedDepartureMeetingPoint == null &&
      selectedArrivalMeetingPoint == null &&
      customDepartureMeetingText.trim().isEmpty &&
      customArrivalMeetingText.trim().isEmpty;

  /// Mirrors `applyPreferredCountryDefaultsIfNeeded` — seeds the route from the
  /// user's residence country, but only if nothing has been picked yet.
  void applyPreferredCountryDefaultsIfNeeded(ResidenceCountry country) {
    if (!isUsingDefaultRouteSelection) return;
    departureLocation = country.defaultFromLocation;
    destinationLocation = country.defaultToLocation;
  }
}
