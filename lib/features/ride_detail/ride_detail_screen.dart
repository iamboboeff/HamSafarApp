import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/l10n.dart';
import '../../core/net_status.dart';
import '../../domain/date_formatter.dart';
import '../../domain/ride_booking.dart';
import '../../domain/ride_detail_state.dart';
import '../../models/booked_trip.dart';
import '../../models/ride.dart';
import '../../models/ride_passenger_booking.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../state/chat_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../auth/auth_screen.dart';
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
class RideDetailScreen extends ConsumerStatefulWidget {
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
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen> {
  /// Live bookings on this ride, used to render the confirmed-passengers
  /// section. Only fetched for the driver's own ride. NB: these are NOT fed
  /// back into the seat-count math — the [Ride] handed to this screen already
  /// has its availability reduced by occupied seats, so counting them again
  /// would double-subtract.
  List<RidePassengerBooking> _passengers = const [];
  bool _isLoadingPassengers = false;

  Ride get ride => widget.ride;
  BookedTrip? get bookedTrip => widget.bookedTrip;
  bool get isManagingBookedTrip => widget.isManagingBookedTrip;

  /// Guests can browse a ride but must sign in to book or message the driver
  /// (QA #16). Returns true (and opens the auth screen) when the user is a
  /// guest, so callers can early-return.
  bool _gateGuest() {
    if (ref.read(isAuthenticatedProvider)) return false;
    Navigator.of(context).push(
      HSRoute<void>(
        builder: (_) => const AuthScreen(),
        fullscreenDialog: true,
      ),
    );
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(isCurrentUserProvider)(ride.driver)) {
      // Show a loader for the passenger list while it's fetched, so the section
      // doesn't flash "Пока нет активных заявок" before the data lands.
      _isLoadingPassengers = true;
      _loadPassengers();
    }
  }

  Future<void> _loadPassengers() async {
    final rideId = ride.backendId;
    if (rideId == null) {
      if (mounted) setState(() => _isLoadingPassengers = false);
      return;
    }
    try {
      final passengers = await ref
          .read(supabaseServiceProvider)
          .fetchRidePassengerBookings(rideId);
      if (!mounted) return;
      setState(() => _passengers = passengers);
    } catch (_) {
      // Best-effort; the screen still renders without the live passenger list.
    } finally {
      if (mounted) setState(() => _isLoadingPassengers = false);
    }
  }

  void _openPassengerChat(RidePassengerBooking booking) {
    final threadId = ref.read(chatProvider.notifier).openChatWithDriver(
          driver: booking.passenger,
          route: '${ride.fromCity} - ${ride.toCity}',
          openingText: trf(
            'Здравствуйте! По вашей брони на поездку {route}.',
            {'route': '${ride.fromCity} — ${ride.toCity}'},
          ),
          departureDate: ride.departureDate,
          rideId: ride.backendId,
        );
    Navigator.of(context).push(
      HSRoute<void>(builder: (_) => ChatDetailScreen(threadId: threadId)),
    );
  }

  void _openPassengerProfile(RidePassengerBooking booking) {
    final id = booking.passenger.backendId;
    if (id == null) return;
    Navigator.of(context).push(
      HSRoute<void>(
        builder: (_) => UserPublicProfileScreen(
          userId: id,
          fallback: booking.passenger,
        ),
      ),
    );
  }

  Future<void> _removePassenger(RidePassengerBooking booking) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Отменить бронь пассажира?')),
        content: Text(
          tr('Пассажир будет удалён из подтверждённых бронирований этой поездки.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              tr('Отменить бронь'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(supabaseServiceProvider).updateBookingStatus(
            bookingId: booking.backendId,
            status: 'cancelled',
          );
      await ref.read(chatProvider.notifier).notifyBookingDecision(
            passenger: booking.passenger,
            route: '${ride.fromCity} — ${ride.toCity}',
            departureDate: ride.departureDate,
            rideId: ride.backendId,
            confirmed: false,
          );
      ref.read(bookedTripsProvider.notifier).refresh();
      await _loadPassengers();
    } catch (_) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Не удалось выполнить действие')),
          content: Text(tr('Попробуйте ещё раз.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('Ок')),
            ),
          ],
        ),
      );
    }
  }

  /// Cancels the managed booked trip. The driver cancels the whole ride
  /// (QA #58); the passenger cancels their own booking/request (QA #61).
  Future<void> _cancelTrip({required bool asDriver}) async {
    final trip = bookedTrip;
    if (trip == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          asDriver ? tr('Отменить поездку?') : tr('Отменить бронь?'),
        ),
        content: Text(
          asDriver
              ? tr(
                  'Поездка будет отменена, а подтверждённые пассажиры получат '
                  'уведомление об отмене.',
                )
              : tr('Ваша заявка на эту поездку будет отменена.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Назад')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              asDriver ? tr('Отменить поездку') : tr('Отменить бронь'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(supabaseServiceProvider).cancelBookedTrip(trip);
      ref.read(bookedTripsProvider.notifier).refresh();
      ref.read(marketplaceProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            asDriver
                ? tr('Не удалось отменить поездку')
                : tr('Не удалось отменить бронь'),
          ),
          content: Text(
            isOfflineError(e) ? offlineMessage : tr('Попробуйте ещё раз.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('Ок')),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = ref.watch(isCurrentUserProvider);
    final requestedPassengers = ref.watch(homeSearchProvider).search.passengers;

    final isOwnRide = isCurrentUser(ride.driver);
    final seatState = RideBookingDomain.seatState(
      ride: ride,
      ridePassengers: const [],
    );
    final confirmedPassengers = [
      for (final booking in _passengers)
        if (booking.isConfirmed) booking,
    ];
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
      appBar: AppBar(title: Text(tr('Детали поездки'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
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
                    seatCount: automaticBookingSeatCount,
                    // The passenger can call off their own active booking
                    // from My Trips (QA #61).
                    canCancelBooking: isManagingBookedTrip &&
                        bookedTrip != null &&
                        !bookedTrip!.isCancelled &&
                        !bookedTrip!.isCompleted,
                    onCancelBooking: () => _cancelTrip(asDriver: false),
                    onMessageDriver: () {
                      if (_gateGuest()) return;
                      final currentRide = detailState.currentRide;
                      final threadId = ref
                          .read(chatProvider.notifier)
                          .openChatWithDriver(
                            driver: currentRide.driver,
                            route:
                                '${currentRide.fromCity} - ${currentRide.toCity}',
                            openingText: trf(
                              'Здравствуйте! Интересует поездка {route}.',
                              {
                                'route':
                                    '${currentRide.fromCity} — ${currentRide.toCity}',
                              },
                            ),
                            departureDate: currentRide.departureDate,
                            rideId: currentRide.backendId,
                          );
                      Navigator.of(context).push(
                        HSRoute<void>(
                          builder: (_) => ChatDetailScreen(threadId: threadId),
                        ),
                      );
                    },
                  )
                : _DriverRideDetail(
                    ride: ride,
                    detailState: detailState,
                    confirmedPassengers: confirmedPassengers,
                    isLoadingPassengers: _isLoadingPassengers,
                    // Can't cancel passengers' bookings once the ride is over —
                    // hide the action on finished trips (keeps «Написать»).
                    canRemovePassengers: detailState.isDriverManagingRide &&
                        !detailState.currentRide.hasFinished,
                    // The driver can call off an active trip they're managing
                    // (QA #58) — not one already finished or cancelled.
                    canCancelRide: isManagingBookedTrip &&
                        isOwnRide &&
                        bookedTrip != null &&
                        !bookedTrip!.isCancelled &&
                        !bookedTrip!.isCompleted,
                    onCancelRide: () => _cancelTrip(asDriver: true),
                    onOpenChat: _openPassengerChat,
                    onRemovePassenger: _removePassenger,
                    onOpenProfile: _openPassengerProfile,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: detailState.shouldShowBookingCTA
          ? _BookingContinueBar(
              seatCount: automaticBookingSeatCount,
              onContinue: () {
                if (_gateGuest()) return;
                Navigator.of(context).push(
                  HSRoute<void>(
                    builder: (_) => RideBookingCheckoutScreen(
                      ride: ride,
                      passengerCount: automaticBookingSeatCount,
                      totalPriceText: bookingCostText,
                    ),
                  ),
                );
              },
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
    HSRoute<void>(
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
    required this.seatCount,
    required this.canCancelBooking,
    required this.onCancelBooking,
    required this.onMessageDriver,
  });

  final Ride ride;
  final RideDetailDerivedState detailState;
  final String bookingCostText;
  final int seatCount;
  final bool canCancelBooking;
  final VoidCallback onCancelBooking;
  final VoidCallback onMessageDriver;

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
                    subtitle: currentRide.meetingPoint.addressLine ??
                        tr('Уточняется'),
                    accent: hs.primary,
                    showsConnector: true,
                  ),
                  RideLocationRow(
                    title: currentRide.toCity,
                    subtitle: currentRide.destinationPoint.addressLine ??
                        tr('Уточняется'),
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
          // The headline is the TOTAL for the requested number of seats, with
          // a count-aware caption: «944 TJS / за 2 места». For a single seat
          // that's just the per-seat price under «за место». bookingCostText =
          // pricePerSeat × seatCount.
          priceText: bookingCostText,
          priceLabel: seatCount > 1
              ? trf('за {count} места', {'count': seatCount})
              : tr('за место'),
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
        RideDetailPlainSection(
          title: tr('Автомобиль'),
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
                      detailState.rideCarDetailText,
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
            title: tr('Условия поездки'),
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
        const SizedBox(height: 18),
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
                    trf('Есть вопросы? {name} ответит!', {
                      'name': currentRide.driver.name,
                    }),
                    style: HSText.subheadlineSemibold.copyWith(
                      color: hs.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (canCancelBooking) ...[
          const SizedBox(height: 24),
          PrimaryFilledButton(
            label: tr('Отменить бронь'),
            accent: Colors.red.shade600,
            onPressed: onCancelBooking,
          ),
        ],
      ],
    );
  }
}

/// Ported from `DriverRideDetailSection` + the car / conditions sections of
/// `RideDetailView` (the read-only driver layout).
class _DriverRideDetail extends StatelessWidget {
  const _DriverRideDetail({
    required this.ride,
    required this.detailState,
    required this.confirmedPassengers,
    required this.isLoadingPassengers,
    required this.canRemovePassengers,
    required this.canCancelRide,
    required this.onCancelRide,
    required this.onOpenChat,
    required this.onRemovePassenger,
    required this.onOpenProfile,
  });

  final Ride ride;
  final RideDetailDerivedState detailState;
  final List<RidePassengerBooking> confirmedPassengers;
  final bool isLoadingPassengers;
  final bool canRemovePassengers;
  final bool canCancelRide;
  final VoidCallback onCancelRide;
  final void Function(RidePassengerBooking) onOpenChat;
  final void Function(RidePassengerBooking) onRemovePassenger;
  final void Function(RidePassengerBooking) onOpenProfile;

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
                    subtitle: currentRide.meetingPoint.addressLine ??
                        tr('Уточняется'),
                    accent: hs.primary,
                    showsConnector: true,
                  ),
                  RideLocationRow(
                    title: currentRide.toCity,
                    subtitle: currentRide.destinationPoint.addressLine ??
                        tr('Уточняется'),
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
        DriverRidePassengersSection(
          confirmedPassengers: confirmedPassengers,
          isLoading: isLoadingPassengers,
          canRemovePassengers: canRemovePassengers,
          onOpenChat: onOpenChat,
          onRemovePassenger: onRemovePassenger,
          onOpenProfile: onOpenProfile,
        ),
        const SizedBox(height: 18),
        RideDetailPlainSection(
          title: tr('Автомобиль'),
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
                      detailState.rideCarDetailText,
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
            title: tr('Условия поездки'),
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
        if (canCancelRide) ...[
          const SizedBox(height: 24),
          PrimaryFilledButton(
            label: tr('Отменить поездку'),
            accent: Colors.red.shade600,
            onPressed: onCancelRide,
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ColoredBox(
      color: hs.cardBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top hairline to match the checkout screen's action bar.
          Divider(height: 1, color: hs.stroke),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomInset),
            child: PrimaryFilledButton(
              label: seatCount == 0 ? tr('Мест нет') : tr('Продолжить'),
              onPressed: seatCount == 0 ? null : onContinue,
            ),
          ),
        ],
      ),
    );
  }
}
