import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/my_trips_domain.dart';
import '../../models/app_tab.dart';
import '../../models/trip_section.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../ride_detail/passenger_request_detail_screen.dart';
import '../ride_detail/ride_detail_screen.dart';
import 'matching_drivers_screen.dart';
import 'matching_passengers_screen.dart';
import 'widgets/booked_trip_card.dart';
import 'widgets/my_passenger_request_card.dart';

/// Ported from `MyTripsView` in `MyTripsViews.swift`.
class MyTripsScreen extends ConsumerStatefulWidget {
  const MyTripsScreen({super.key});

  @override
  ConsumerState<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends ConsumerState<MyTripsScreen> {
  final _pageController = PageController();
  int _sectionIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectSection(int index) {
    setState(() => _sectionIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropScaffoldBody(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Мои поездки', style: HSText.largeTitle),
                  const SizedBox(height: 12),
                  _SectionTabs(
                    selectedIndex: _sectionIndex,
                    onSelect: _selectSection,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _sectionIndex = index),
                children: [
                  for (final section in TripSection.values)
                    _SectionPage(section: section),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionPage extends ConsumerWidget {
  const _SectionPage({required this.section});

  final TripSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookedTrips = ref.watch(bookedTripsProvider);
    final myRequests = ref.watch(myPassengerRequestsProvider);
    final marketplace = ref.watch(marketplaceProvider);
    final isCurrentUser = ref.watch(isCurrentUserProvider);

    final items = MyTripsDomain.displayedItems(
      section: section,
      bookedTrips: bookedTrips,
      passengerRequests: myRequests,
    );

    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.read(bookedTripsProvider.notifier).refresh(),
        ref.read(myPassengerRequestsProvider.notifier).refresh(),
        ref.read(marketplaceProvider.notifier).refresh(),
      ]),
      child: SingleChildScrollView(
        // Clamp the over-scroll so the iOS rubber-band can't drag the short
        // list far down and reveal a blank backdrop — pull-to-refresh still
        // works (the indicator triggers on the clamped over-scroll).
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items) ...[
            switch (item) {
              TripDisplayItem(:final trip) => BookedTripCard(
                trip: trip,
                matchingCount: MyTripsDomain.matchingRideCountForTrip(
                  trip: trip,
                  rides: marketplace.rides,
                  bookedTrips: bookedTrips,
                  isCurrentUser: isCurrentUser,
                ),
                searchPassengers: trip.searchPassengersEnabled,
                onSearchPassengersChanged: (value) => ref
                    .read(bookedTripsProvider.notifier)
                    .setSearchPassengers(trip.id, value),
                onOpenMatches: () => Navigator.of(context).push(
                  HSRoute<void>(
                    builder: (_) => MatchingDriversScreen(
                      fromCity: trip.ride.fromCity,
                      toCity: trip.ride.toCity,
                      minimumSeats: trip.seatsBooked,
                    ),
                  ),
                ),
                onOpenPassengerRequests: () => Navigator.of(context).push(
                  HSRoute<void>(
                    builder: (_) => MatchingPassengersScreen(trip: trip),
                  ),
                ),
                onOpenDetails: () => Navigator.of(context).push(
                  HSRoute<void>(
                    builder: (_) => RideDetailScreen(
                      ride: trip.ride,
                      bookedTrip: trip,
                      isManagingBookedTrip: true,
                    ),
                  ),
                ),
                onRepeat: () => ref
                    .read(selectedTabProvider.notifier)
                    .select(AppTab.create),
              ),
              RequestDisplayItem(:final request) => MyPassengerRequestCard(
                request: request,
                matchingCount: MyTripsDomain.matchingRideCountForRequest(
                  request: request,
                  rides: marketplace.rides,
                  bookedTrips: bookedTrips,
                  isCurrentUser: isCurrentUser,
                ),
                onOpenMatches: () => Navigator.of(context).push(
                  HSRoute<void>(
                    builder: (_) => MatchingDriversScreen(
                      fromCity: request.fromCity,
                      toCity: request.toCity,
                      minimumSeats: request.seatsNeeded,
                    ),
                  ),
                ),
                onOpenDetails: () => Navigator.of(context).push(
                  HSRoute<void>(
                    builder: (_) => PassengerRequestDetailScreen(
                      request: request,
                      isOwnRequest: true,
                    ),
                  ),
                ),
                onRepeat: () => ref
                    .read(selectedTabProvider.notifier)
                    .select(AppTab.create),
              ),
            },
            const SizedBox(height: 16),
          ],
          if (items.isEmpty)
            section == TripSection.active
                ? const _EmptyTripsCard()
                : _EmptyTripsInfo(
                    title: MyTripsDomain.emptyStateTitle(section),
                    subtitle: MyTripsDomain.emptyStateSubtitle(section),
                    asset: section == TripSection.requests
                        ? 'assets/images/empty_trips_requests.png'
                        : 'assets/images/empty_trips_history.png',
                  ),
          ],
        ),
      ),
    );
  }
}

/// Ported from `MyTripsSectionTabs` in `MyTripsViews.swift`.
class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < TripSection.values.length; i++)
          Expanded(
            child: _TabItem(
              title: TripSection.values[i].title,
              isSelected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: HSText.subheadlineSemibold.copyWith(
              color: isSelected ? context.primaryText : context.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: isSelected ? context.hs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from `EmptyTripsStateCard` in `MyTripsViews.swift`.
class _EmptyTripsCard extends StatelessWidget {
  const _EmptyTripsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
      child: Column(
        children: [
          Image.asset(
            'assets/images/empty_trips_active.png',
            height: 255,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 4),
          Text(
            'У вас пока нет предстоящих поездок',
            textAlign: TextAlign.center,
            style: HSText.title3.copyWith(fontSize: 22, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Создайте новую поездку или запрос, и они появятся здесь.',
            textAlign: TextAlign.center,
            style: HSText.body.copyWith(
              fontSize: 16,
              height: 1.4,
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from `EmptyTripsInfoBlock` in `MyTripsViews.swift`.
class _EmptyTripsInfo extends StatelessWidget {
  const _EmptyTripsInfo({
    required this.title,
    required this.subtitle,
    this.asset,
  });

  final String title;
  final String subtitle;
  final String? asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
      child: Column(
        children: [
          if (asset != null) ...[
            Image.asset(asset!, height: 255, fit: BoxFit.contain),
            const SizedBox(height: 4),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: HSText.title3.copyWith(fontSize: 22, height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: HSText.body.copyWith(
              fontSize: 16,
              height: 1.4,
              color: context.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
