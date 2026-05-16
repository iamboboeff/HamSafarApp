import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_formatter.dart';
import '../../domain/search_date_options.dart';
import '../../domain/trips_domain.dart';
import '../../models/app_tab.dart';
import '../../models/passenger_request.dart';
import '../../models/ride.dart';
import '../../state/app_state.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/passenger_request_card.dart';
import '../../widgets/ride_card.dart';
import '../ride_detail/passenger_request_detail_screen.dart';
import '../ride_detail/ride_detail_screen.dart';
import 'widgets/search_filter_bar.dart';
import 'widgets/search_mode_tabs.dart';
import 'widgets/search_overlays.dart';
import 'widgets/search_route_summary.dart';

/// A day-grouped bucket of search results.
class _DayGroup<T> {
  _DayGroup(this.date, this.items);
  final DateTime date;
  final List<T> items;
}

List<_DayGroup<T>> _groupByDay<T>(List<T> items, DateTime Function(T) dateOf) {
  final map = <DateTime, List<T>>{};
  for (final item in items) {
    final day = DateUtilsX.startOfDay(dateOf(item));
    map.putIfAbsent(day, () => []).add(item);
  }
  final days = map.keys.toList()..sort();
  return [
    for (final day in days)
      _DayGroup(day, map[day]!..sort((a, b) => dateOf(a).compareTo(dateOf(b)))),
  ];
}

/// Ported from `SearchResultsHubView` in `SearchResultsViews.swift`.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  bool _showDatePicker = false;
  bool _showFilters = false;
  bool _isDateFilterActive = false;

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(homeSearchProvider);
    final search = searchState.search;
    final marketplace = ref.watch(marketplaceProvider);
    final bookedTrips = ref.watch(bookedTripsProvider);
    final isCurrentUser = ref.watch(isCurrentUserProvider);
    final section = ref.watch(selectedHomeSectionProvider);

    final from = search.fromLocation?.city.name;
    final to = search.toLocation?.city.name;

    final rideMatches = (from == null || to == null)
        ? <Ride>[]
        : TripsDomain.matchingVisibleRides(
            rides: marketplace.rides,
            bookedTrips: bookedTrips,
            fromCity: from,
            toCity: to,
            minimumSeats: search.passengers,
            isCurrentUser: isCurrentUser,
          );

    final passengerMatches = (from == null || to == null)
        ? <PassengerRequest>[]
        : TripsDomain.matchingVisiblePassengerRequests(
            passengerRequests: marketplace.passengerRequests,
            fromCity: from,
            toCity: to,
            isCurrentUser: isCurrentUser,
          );

    final displayedRides = [...rideMatches]
      ..sort((a, b) {
        final aSoldOut = a.availableSeatsCount <= 0;
        final bSoldOut = b.availableSeatsCount <= 0;
        if (aSoldOut != bSoldOut) return aSoldOut ? 1 : -1;
        return a.departureDate.compareTo(b.departureDate);
      });
    final filteredRides = _isDateFilterActive
        ? displayedRides
              .where((r) => DateUtilsX.isSameDay(r.departureDate, search.date))
              .toList()
        : displayedRides;

    final displayedRequests = [...passengerMatches]
      ..sort((a, b) => a.departureDate.compareTo(b.departureDate));
    final filteredRequests = _isDateFilterActive
        ? displayedRequests
              .where((r) => DateUtilsX.isSameDay(r.departureDate, search.date))
              .toList()
        : displayedRequests;

    final dateSourceDates = section == HomeListingSection.rides
        ? rideMatches.map((r) => r.departureDate).toList()
        : passengerMatches.map((r) => r.departureDate).toList();
    final dateOptions = groupedDateOptions(
      dates: dateSourceDates,
      selectedDate: search.date,
      includeSelectedDateIfMissing: _isDateFilterActive,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Поиск')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: SearchModeTabs(
                  selection: section,
                  onSelect: (value) => ref
                      .read(selectedHomeSectionProvider.notifier)
                      .select(value),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SearchRouteSummary(),
                      const SizedBox(height: 12),
                      SearchFilterBar(
                        dateOptions: dateOptions,
                        isAllDatesSelected: !_isDateFilterActive,
                        selectedDate: search.date,
                        showsFilterButton: false,
                        onOpenCalendar: () =>
                            setState(() => _showDatePicker = true),
                        onSelectDateOption: (option) {
                          setState(() {
                            if (option.isAllDates) {
                              _isDateFilterActive = false;
                            } else {
                              ref
                                  .read(homeSearchProvider.notifier)
                                  .setDate(option.date);
                              _isDateFilterActive = true;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (section == HomeListingSection.rides)
                        ..._buildRideResults(filteredRides)
                      else
                        ..._buildRequestResults(filteredRequests),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showDatePicker)
            TopOverlayScrim(
              onDismiss: () => setState(() => _showDatePicker = false),
              child: SearchCalendarOverlay(
                initialDate: search.date,
                onConfirm: (date) {
                  ref.read(homeSearchProvider.notifier).setDate(date);
                  setState(() {
                    _isDateFilterActive = true;
                    _showDatePicker = false;
                  });
                },
                onClose: () => setState(() => _showDatePicker = false),
              ),
            ),
          if (_showFilters)
            TopOverlayScrim(
              onDismiss: () => setState(() => _showFilters = false),
              child: SearchFiltersOverlay(
                passengers: search.passengers,
                onChanged: (value) =>
                    ref.read(homeSearchProvider.notifier).setPassengers(value),
                onClose: () => setState(() => _showFilters = false),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildRideResults(List<Ride> rides) {
    if (rides.isEmpty) {
      return [_emptyText('По этому маршруту пока нет доступных поездок.')];
    }
    final groups = _groupByDay(rides, (r) => r.departureDate);
    return [
      for (final group in groups) ...[
        _DaySectionHeader(
          date: group.date,
          onOpenFilters: () => setState(() => _showFilters = true),
        ),
        for (final ride in group.items) ...[
          RideCard(
            ride: ride,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RideDetailScreen(ride: ride),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  List<Widget> _buildRequestResults(List<PassengerRequest> requests) {
    if (requests.isEmpty) {
      return [_emptyText('По этому маршруту пока нет запросов пассажиров.')];
    }
    final groups = _groupByDay(requests, (r) => r.departureDate);
    return [
      for (final group in groups) ...[
        _DaySectionHeader(
          date: group.date,
          onOpenFilters: () => setState(() => _showFilters = true),
        ),
        for (final request in group.items) ...[
          PassengerRequestCard(
            request: request,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PassengerRequestDetailScreen(request: request),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: HSText.subheadline.copyWith(color: context.secondaryText),
      ),
    );
  }
}

/// Ported from `SearchResultsDaySectionHeader` in `SearchResultsViews.swift`.
class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.date, required this.onOpenFilters});

  final DateTime date;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 1, 2, 11),
      child: Row(
        children: [
          Text(
            DateTextFormatter.resultsSectionTitle(date),
            style: HSText.subheadlineSemibold.copyWith(
              color: context.secondaryText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onOpenFilters,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Icon(Icons.tune, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
