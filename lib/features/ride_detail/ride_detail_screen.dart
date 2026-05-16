import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_formatter.dart';
import '../../domain/ride_booking.dart';
import '../../domain/ride_detail_state.dart';
import '../../models/booked_trip.dart';
import '../../models/ride.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../state/chat_state.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_screen.dart';
import '../profile/public_profile_screen.dart';
import 'ride_booking_checkout_screen.dart';
import 'widgets/ride_detail_sections.dart';

/// Ported from `RideDetailView` in `RideDetailViews.swift`.
///
/// The Flutter port covers the passenger-booking-preview layout (the path
/// reached from search results) and the read-only driver layout. Trip
/// management, reviews and live seat hydration depend on areas not yet
/// ported and are omitted.
class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({
    super.key,
    required this.ride,
    this.bookedTrip,
    this.isManagingBookedTrip = false,
  });

  final Ride ride;

  /// When the screen is opened from My Trips, the owning [BookedTrip] is passed
  /// so the derived state renders the management layout instead of the booking
  /// preview.
  final BookedTrip? bookedTrip;
  final bool isManagingBookedTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrentUser = ref.watch(isCurrentUserProvider);
    final requestedPassengers = ref.watch(homeSearchProvider).search.passengers;

    final isOwnRide = isCurrentUser(ride.driver);
    final seatState = RideBookingDomain.seatState(
      ride: ride,
      ridePassengers: const [],
    );
    final detailState = RideDetailDerivedState.build(
      ride: ride,
      bookedTrip: bookedTrip,
      isManagingBookedTrip: isManagingBookedTrip,
      isOwnRide: isOwnRide,
      activePassengerBookedTripExists: false,
      currentSeatsLeft: seatState.currentSeatsLeft,
    );

    final automaticBookingSeatCount =
        RideBookingDomain.automaticBookingSeatCount(
          currentSeatsLeft: seatState.currentSeatsLeft,
          requestedPassengers: requestedPassengers,
        );
    final bookingCostText = RideBookingDomain.bookingCostText(
      pricePerSeat: detailState.displayedPricePerSeat,
      pricingCountry: detailState.displayedPricingCountry,
      seatsCount: automaticBookingSeatCount,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Детали поездки')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              detailState.shouldShowBookingCTA ? 110 : 28,
            ),
            child: detailState.usesPassengerRideDetailLayout
                ? _PassengerRideDetail(
                    ride: ride,
                    detailState: detailState,
                    bookingCostText: bookingCostText,
                    onMessageDriver: () {
                      final currentRide = detailState.currentRide;
                      final threadId = ref
                          .read(chatProvider.notifier)
                          .openChatWithDriver(
                            driver: currentRide.driver,
                            route:
                                '${currentRide.fromCity} - ${currentRide.toCity}',
                            openingText:
                                'Здравствуйте! Интересует поездка '
                                '${currentRide.fromCity} — ${currentRide.toCity}.',
                            departureDate: currentRide.departureDate,
                            rideId: currentRide.backendId,
                          );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatDetailScreen(threadId: threadId),
                        ),
                      );
                    },
                  )
                : _DriverRideDetail(ride: ride, detailState: detailState),
          ),
        ],
      ),
      bottomNavigationBar: detailState.shouldShowBookingCTA
          ? _BookingContinueBar(
              seatCount: automaticBookingSeatCount,
              onContinue: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RideBookingCheckoutScreen(
                    ride: ride,
                    passengerCount: automaticBookingSeatCount,
                    totalPriceText: bookingCostText,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

/// Pushes the driver's public profile. Skipped when the driver is the
/// signed-in user (Swift hides the chevron in that case too).
void _openDriverProfile(BuildContext context, UserProfile driver) {
  final backendId = driver.backendId;
  if (backendId == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UserPublicProfileScreen(
        userId: backendId,
        fallback: driver,
      ),
    ),
  );
}

/// Ported from `PassengerRideDetailSection` in `RideDetailSections.swift`.
class _PassengerRideDetail extends StatelessWidget {
  const _PassengerRideDetail({
    required this.ride,
    required this.detailState,
    required this.bookingCostText,
    required this.onMessageDriver,
  });

  final Ride ride;
  final RideDetailDerivedState detailState;
  final String bookingCostText;
  final VoidCallback onMessageDriver;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final currentRide = detailState.currentRide;
    final arrivalTimeText = RideBookingDomain.arrivalTimeText(currentRide);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detailState.passengerDetailDateTitle, style: HSText.title2),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateTextFormatter.time(currentRide.departureDate),
                  style: HSText.headline,
                ),
                const SizedBox(height: 26),
                Text(arrivalTimeText, style: HSText.headline),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  RideLocationRow(
                    title: currentRide.fromCity,
                    subtitle:
                        currentRide.meetingPoint.addressLine ?? 'Уточняется',
                    accent: hs.primary,
                    showsConnector: true,
                  ),
                  RideLocationRow(
                    title: currentRide.toCity,
                    subtitle:
                        currentRide.destinationPoint.addressLine ??
                        'Уточняется',
                    accent: hs.passenger,
                    showsConnector: false,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const BleedDivider(),
        const SizedBox(height: 18),
        RideDetailPriceSeatsSummary(
          priceText: bookingCostText,
          seatsLeft: detailState.displayedSeatsLeft,
        ),
        const SizedBox(height: 18),
        const BleedDivider(),
        const SizedBox(height: 18),
        Builder(
          builder: (rowContext) => RidePassengerDriverRow(
            driver: currentRide.driver,
            showsChevron: true,
            onTap: () => _openDriverProfile(rowContext, currentRide.driver),
          ),
        ),
        const SizedBox(height: 18),
        const BleedDivider(),
        const SizedBox(height: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final row in detailState.passengerInfoRows)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Icon(
                        rideDetailIcon(row.iconKey),
                        size: 16,
                        color: rideDetailAccentColor(context, row.accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(row.title, style: HSText.headline)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onMessageDriver,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hs.stroke),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: hs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Есть вопросы? ${currentRide.driver.name} ответит!',
                    style: HSText.subheadlineSemibold.copyWith(
                      color: hs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ported from `DriverRideDetailSection` + the car / conditions sections of
/// `RideDetailView` (the read-only driver layout).
class _DriverRideDetail extends StatelessWidget {
  const _DriverRideDetail({required this.ride, required this.detailState});

  final Ride ride;
  final RideDetailDerivedState detailState;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final currentRide = detailState.currentRide;
    final arrivalTimeText = RideBookingDomain.arrivalTimeText(currentRide);
    final conditions = detailState.tripConditions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detailState.passengerDetailDateTitle, style: HSText.title2),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateTextFormatter.time(currentRide.departureDate),
                  style: HSText.headline,
                ),
                const SizedBox(height: 26),
                Text(arrivalTimeText, style: HSText.headline),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  RideLocationRow(
                    title: currentRide.fromCity,
                    subtitle:
                        currentRide.meetingPoint.addressLine ?? 'Уточняется',
                    accent: hs.primary,
                    showsConnector: true,
                  ),
                  RideLocationRow(
                    title: currentRide.toCity,
                    subtitle:
                        currentRide.destinationPoint.addressLine ??
                        'Уточняется',
                    accent: hs.passenger,
                    showsConnector: false,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const BleedDivider(),
        const SizedBox(height: 18),
        RideDetailPriceSeatsSummary(
          priceText: detailState.displayedPriceText,
          seatsLeft: detailState.displayedSeatsLeft,
        ),
        const SizedBox(height: 18),
        RideDetailPlainSection(
          title: 'Автомобиль',
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hs.secondarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_car, size: 18, color: hs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(detailState.rideCarModelText, style: HSText.headline),
                    const SizedBox(height: 4),
                    Text(
                      'Комфортная поездка по маршруту '
                      '${currentRide.fromCity} — ${currentRide.toCity}',
                      style: HSText.subheadline.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (conditions.isNotEmpty) ...[
          const SizedBox(height: 14),
          RideDetailPlainSection(
            title: 'Условия поездки',
            child: Column(
              children: [
                for (var i = 0; i < conditions.length; i++) ...[
                  RideConditionRow(
                    title: conditions[i].title,
                    subtitle: conditions[i].subtitle,
                    icon: rideDetailIcon(conditions[i].iconKey),
                    accent: rideDetailAccentColor(
                      context,
                      conditions[i].accent,
                    ),
                  ),
                  if (i < conditions.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 14, left: 50),
                      child: Divider(height: 1),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Ported from `bookingContinueBar` in `RideDetailView`.
class _BookingContinueBar extends StatelessWidget {
  const _BookingContinueBar({
    required this.seatCount,
    required this.onContinue,
  });

  final int seatCount;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      color: hs.cardBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: hs.stroke.withValues(alpha: 0.9)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: PrimaryFilledButton(
              label: seatCount == 0 ? 'Мест нет' : 'Продолжить',
              onPressed: seatCount == 0 ? null : onContinue,
            ),
          ),
        ],
      ),
    );
  }
}
