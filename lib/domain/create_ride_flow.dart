import '../models/app_tab.dart';
import '../models/car_profile.dart';
import '../models/create_flow.dart';
import '../models/location.dart';
import '../models/passenger_request.dart';
import '../models/residence_country.dart';
import '../models/ride.dart';
import '../models/user_profile.dart';

/// Ported from `CreateRideFlowDomain` in `CreateRideFlowDomain.swift`.
abstract final class CreateRideFlow {
  static CreateFlowState advance(CreateFlowState state) {
    return switch (state.phase) {
      CreateFlowPhase.roleSelection => state,
      CreateFlowPhase.driver => CreateFlowState(
        CreateFlowPhase.driver,
        state.step.next,
      ),
      CreateFlowPhase.passenger => CreateFlowState(
        CreateFlowPhase.passenger,
        passengerNextStep(state.step),
      ),
    };
  }

  static CreateFlowState back(CreateWizardStep step, TravelMode mode) {
    if (step == CreateWizardStep.from) {
      return const CreateFlowState.roleSelection();
    }
    return switch (mode) {
      TravelMode.driver => CreateFlowState(
        CreateFlowPhase.driver,
        step.previous,
      ),
      TravelMode.passenger => CreateFlowState(
        CreateFlowPhase.passenger,
        passengerPreviousStep(step),
      ),
    };
  }

  /// The passenger flow skips the price step.
  static CreateWizardStep passengerNextStep(CreateWizardStep step) {
    if (step == CreateWizardStep.seats) return CreateWizardStep.notes;
    return step.next;
  }

  static CreateWizardStep passengerPreviousStep(CreateWizardStep step) {
    if (step == CreateWizardStep.notes) return CreateWizardStep.seats;
    return step.previous;
  }

  /// Ported from `sanitizedAmount` — digits only, clamped to 0...1000.
  static int sanitizedAmount(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(digits) ?? 0;
    return amount.clamp(0, 1000);
  }
}

/// Ported from `CreateRidePublishContext` in `CreateRideFlowDomain.swift`.
class CreateRidePublishContext {
  const CreateRidePublishContext({
    required this.mode,
    required this.departureLocation,
    required this.destinationLocation,
    required this.departurePoint,
    required this.arrivalPoint,
    required this.mergedDepartureDate,
    required this.priceValue,
    required this.availableSeatLabels,
    required this.seats,
    required this.notes,
    required this.instantBookingEnabled,
    required this.maxTwoPassengersInBack,
    required this.driverProfile,
    required this.carProfile,
  });

  final TravelMode mode;
  final LocationSelection departureLocation;
  final LocationSelection destinationLocation;
  final RidePoint departurePoint;
  final RidePoint arrivalPoint;
  final DateTime mergedDepartureDate;
  final int priceValue;
  final List<String> availableSeatLabels;
  final int seats;
  final String notes;
  final bool instantBookingEnabled;
  final bool maxTwoPassengersInBack;
  final UserProfile driverProfile;
  final CarProfile carProfile;
}

/// Ported from `CreateRidePublishResult`.
class CreateRidePublishResult {
  const CreateRidePublishResult.driver(this.ride, this.seatsCount)
    : request = null;
  const CreateRidePublishResult.passenger(this.request)
    : ride = null,
      seatsCount = 0;

  final Ride? ride;
  final int seatsCount;
  final PassengerRequest? request;

  bool get isDriver => ride != null;
}

/// Ported from `CreateRidePublishingDomain`.
///
/// The Swift app routes publishing through `SupabaseService`; until that
/// backend layer is ported, [publish] builds the model locally so it shows up
/// in the marketplace immediately.
abstract final class CreateRidePublishing {
  static String? validate(CreateRidePublishContext context, DateTime now) {
    if (context.mode == TravelMode.driver && context.priceValue < 1) {
      return 'Сумма должна быть от 1 до 1000.';
    }
    if (context.mergedDepartureDate.isBefore(now)) {
      return 'Нельзя создать поездку на прошедшие дату или время.';
    }
    return null;
  }

  static CreateRidePublishResult publish(CreateRidePublishContext context) {
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final pricingCountry =
        context.driverProfile.countryOfResidence ?? ResidenceCountry.tajikistan;

    switch (context.mode) {
      case TravelMode.driver:
        final ride = Ride(
          id: id,
          backendId: id,
          fromCity: context.departureLocation.city.name,
          toCity: context.destinationLocation.city.name,
          meetingPoint: context.departurePoint,
          destinationPoint: context.arrivalPoint,
          departureDate: context.mergedDepartureDate,
          pricePerSeat: context.priceValue,
          seatsLeft: context.availableSeatLabels.length,
          carModel: context.carProfile.model,
          routeSummary:
              'Маршрут между ${context.departureLocation.city.name} и '
              '${context.destinationLocation.city.name}',
          notes: Ride.encodedNotes(
            context.notes,
            instantBookingEnabled: context.instantBookingEnabled,
            maxTwoPassengersInBackEnabled: context.maxTwoPassengersInBack,
          ),
          driver: context.driverProfile,
          availableSeatLabels: context.availableSeatLabels,
          pricingCountry: pricingCountry,
        );
        return CreateRidePublishResult.driver(
          ride,
          context.availableSeatLabels.length,
        );
      case TravelMode.passenger:
        final request = PassengerRequest(
          id: id,
          backendId: id,
          passenger: context.driverProfile,
          fromCity: context.departureLocation.city.name,
          toCity: context.destinationLocation.city.name,
          departureDate: context.mergedDepartureDate,
          seatsNeeded: context.seats,
          note: context.notes,
          budgetCountry: pricingCountry,
        );
        return CreateRidePublishResult.passenger(request);
    }
  }
}
