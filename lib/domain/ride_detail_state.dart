import 'package:hamsafar/core/i18n/l10n.dart';

import '../models/booked_trip.dart';
import '../models/ride.dart';
import '../models/residence_country.dart';
import '../models/trip_enums.dart';
import 'date_formatter.dart';

/// Ported from `RideDetailAccentToken` in `RideDetailDomain.swift`.
enum RideDetailAccent { primary, warm, passenger }

/// Ported from `RideDetailCondition`.
class RideDetailCondition {
  const RideDetailCondition({
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String iconKey;
  final RideDetailAccent accent;
}

/// Ported from `RideDetailInfoRow`.
class RideDetailInfoRow {
  const RideDetailInfoRow({
    required this.title,
    required this.iconKey,
    required this.accent,
  });

  final String title;
  final String iconKey;
  final RideDetailAccent accent;
}

/// Ported from `RideDetailDerivedState` in `RideDetailDomain.swift`.
class RideDetailDerivedState {
  const RideDetailDerivedState({
    required this.currentRide,
    required this.displayedPricePerSeat,
    required this.displayedPricingCountry,
    required this.isRideConfirmed,
    required this.isViewingOwnedTrip,
    required this.isDriverManagingRide,
    required this.isPassengerBookingPreview,
    required this.usesPassengerRideDetailLayout,
    required this.shouldShowBookingCTA,
    required this.displayedSeatsLeft,
    required this.canLeaveReview,
  });

  final Ride currentRide;
  final int displayedPricePerSeat;
  final ResidenceCountry displayedPricingCountry;
  final bool isRideConfirmed;
  final bool isViewingOwnedTrip;
  final bool isDriverManagingRide;
  final bool isPassengerBookingPreview;
  final bool usesPassengerRideDetailLayout;
  final bool shouldShowBookingCTA;
  final int displayedSeatsLeft;
  final bool canLeaveReview;

  String get displayedPriceText =>
      displayedPricingCountry.formatAmount(displayedPricePerSeat);

  String get rideCarModelText {
    final trimmed = currentRide.carModel.trim();
    return trimmed.isEmpty ? tr('Автомобиль не указан') : trimmed;
  }

  /// Colour + plate of the car for the detail block, e.g.
  /// "Белый • номер 01A123AA". Falls back to a route line for legacy rides
  /// that were published before vehicle colour/plate were carried through.
  String get rideCarDetailText {
    final color = currentRide.carColor.trim();
    final plate = currentRide.carPlate.trim();
    final parts = <String>[
      if (color.isNotEmpty) color,
      if (plate.isNotEmpty) trf('номер {plate}', {'plate': plate}),
    ];
    if (parts.isEmpty) {
      return trf('Комфортная поездка по маршруту {from} — {to}', {
        'from': currentRide.fromCity,
        'to': currentRide.toCity,
      });
    }
    return parts.join(' • ');
  }

  String get passengerDetailDateTitle =>
      DateTextFormatter.weekdayDayMonth(currentRide.departureDate);

  List<RideDetailCondition> get tripConditions {
    final conditions = <RideDetailCondition>[];
    if (currentRide.instantBookingEnabled) {
      conditions.add(
        RideDetailCondition(
          title: tr('Мгновенное бронирование'),
          subtitle: tr('Место подтверждается сразу, без ожидания водителя'),
          iconKey: 'bolt',
          accent: RideDetailAccent.primary,
        ),
      );
    } else {
      conditions.add(
        RideDetailCondition(
          title: tr('Бронирование по запросу'),
          subtitle: tr('Место подтвердит водитель после вашей заявки'),
          iconKey: 'calendar_clock',
          accent: RideDetailAccent.primary,
        ),
      );
    }
    if (currentRide.maxTwoPassengersInBackEnabled) {
      conditions.add(
        RideDetailCondition(
          title: tr('Максимум двое сзади'),
          subtitle: tr('В поездке включена комфортная рассадка для пассажиров'),
          iconKey: 'people',
          accent: RideDetailAccent.warm,
        ),
      );
    }
    return conditions;
  }

  List<RideDetailInfoRow> get passengerInfoRows {
    final rows = <RideDetailInfoRow>[
      RideDetailInfoRow(
        title: currentRide.instantBookingEnabled
            ? tr('Ваше бронирование подтвердится сразу')
            : tr(
                'Ваше бронирование будет подтверждено только после одобрения водителя',
              ),
        iconKey: currentRide.instantBookingEnabled ? 'bolt' : 'calendar_clock',
        accent: RideDetailAccent.primary,
      ),
    ];
    if (currentRide.maxTwoPassengersInBackEnabled) {
      rows.add(
        RideDetailInfoRow(
          title: tr('Максимум двое сзади'),
          iconKey: 'people',
          accent: RideDetailAccent.warm,
        ),
      );
    }
    rows.add(
      RideDetailInfoRow(
        title: rideCarModelText,
        iconKey: 'car',
        accent: RideDetailAccent.primary,
      ),
    );
    return rows;
  }

  /// Ported from `RideDetailDerivedState.build`.
  static RideDetailDerivedState build({
    required Ride ride,
    BookedTrip? bookedTrip,
    bool isManagingBookedTrip = false,
    required bool isOwnRide,
    required bool activePassengerBookedTripExists,
    required int currentSeatsLeft,
    int? liveAvailableSeatsCount,
  }) {
    final resolvedRide = bookedTrip?.ride ?? ride;
    final displayedPricePerSeat = [
      resolvedRide.pricePerSeat,
      ride.pricePerSeat,
      bookedTrip?.ride.pricePerSeat ?? 0,
    ].reduce((a, b) => a > b ? a : b);

    final ResidenceCountry displayedPricingCountry;
    if (resolvedRide.pricePerSeat > 0) {
      displayedPricingCountry = resolvedRide.pricingCountry;
    } else if ((bookedTrip?.ride.pricePerSeat ?? 0) > 0) {
      displayedPricingCountry = bookedTrip!.ride.pricingCountry;
    } else {
      displayedPricingCountry = ride.pricingCountry;
    }

    final isViewingOwnedTrip =
        (isManagingBookedTrip || isOwnRide) && bookedTrip != null;
    final isDriverManagingRide =
        bookedTrip?.role == TripRole.driver && isViewingOwnedTrip;
    final isPassengerBookingPreview = !isViewingOwnedTrip && !isOwnRide;
    final usesPassengerRideDetailLayout =
        isPassengerBookingPreview || bookedTrip?.role == TripRole.passenger;
    final shouldShowBookingCTA =
        isPassengerBookingPreview && !activePassengerBookedTripExists;
    final displayedSeatsLeft = isViewingOwnedTrip
        ? currentSeatsLeft
        : (liveAvailableSeatsCount ?? resolvedRide.availableSeatsCount);

    return RideDetailDerivedState(
      currentRide: resolvedRide,
      displayedPricePerSeat: displayedPricePerSeat,
      displayedPricingCountry: displayedPricingCountry,
      isRideConfirmed: bookedTrip != null,
      isViewingOwnedTrip: isViewingOwnedTrip,
      isDriverManagingRide: isDriverManagingRide,
      isPassengerBookingPreview: isPassengerBookingPreview,
      usesPassengerRideDetailLayout: usesPassengerRideDetailLayout,
      shouldShowBookingCTA: shouldShowBookingCTA,
      displayedSeatsLeft: displayedSeatsLeft,
      canLeaveReview: _canLeaveReview(bookedTrip),
    );
  }

  static bool _canLeaveReview(BookedTrip? bookedTrip) {
    if (bookedTrip == null) return false;
    const reviewWindow = Duration(days: 7);
    final completionAge = DateTime.now().difference(
      bookedTrip.ride.estimatedArrivalDate,
    );
    return bookedTrip.role == TripRole.passenger &&
        bookedTrip.isCompleted &&
        !bookedTrip.isCancelled &&
        !completionAge.isNegative &&
        completionAge <= reviewWindow;
  }
}
