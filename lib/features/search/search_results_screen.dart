import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_formatter.dart';
import '../../domain/search_date_options.dart';
import '../../domain/trips_domain.dart';
import '../../models/app_tab.dart';
import '../../models/passenger_request.dart';
import '../../models/ride.dart';
import '../../models/ride_alert.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/passenger_request_card.dart';
import '../../widgets/ride_card.dart';
import '../auth/auth_screen.dart';
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
              // Route + date are a FIXED header — the pull-to-refresh spinner
              // appears below this, with the results, not over the city/date
              // block.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
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
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(marketplaceProvider.notifier).refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (section == HomeListingSection.rides)
                          ..._buildRideResults(filteredRides)
                        else
                          ..._buildRequestResults(filteredRequests),
                      ],
                    ),
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
      final search = ref.read(homeSearchProvider).search;
      final from = search.fromLocation?.city.name;
      final to = search.toLocation?.city.name;
      return [
        _emptyText('По этому маршруту пока нет доступных поездок.'),
        if (from != null && to != null) ...[
          const SizedBox(height: 16),
          _RideAlertCard(fromCity: from, toCity: to),
        ],
      ];
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
              HSRoute<void>(
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
              HSRoute<void>(
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

/// "Создать оповещение о поездке" card shown on an empty rides search — lets
/// the user subscribe to be pushed when a ride appears on this route.
class _RideAlertCard extends ConsumerWidget {
  const _RideAlertCard({required this.fromCity, required this.toCity});

  final String fromCity;
  final String toCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    final isAuth = ref.watch(isAuthenticatedProvider);
    final alerts = ref.watch(rideAlertsProvider);
    RideAlert? existing;
    for (final a in alerts) {
      if (a.fromCity == fromCity && a.toCity == toCity) {
        existing = a;
        break;
      }
    }
    final subscribed = existing != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hs.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                subscribed
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: hs.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subscribed
                      ? 'Оповещение включено'
                      : 'Сообщить, когда появится поездка',
                  style: HSText.subheadlineSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subscribed
                ? 'Пришлём пуш, как только кто-то опубликует поездку '
                    '$fromCity → $toCity.'
                : 'Подпишитесь на маршрут $fromCity → $toCity — пришлём '
                    'уведомление, как только появится поездка.',
            style: HSText.subheadline.copyWith(color: context.secondaryText),
          ),
          const SizedBox(height: 14),
          if (!isAuth) ...[
            PrimaryFilledButton(
              label: 'Создать оповещение',
              onPressed: () => _promptLogin(context),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: context.secondaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Войдите в аккаунт, чтобы подписаться на оповещения.',
                    style: HSText.caption.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (subscribed)
            DestructiveOutlineButton(
              label: 'Отключить оповещение',
              onPressed: () => _remove(context, ref, existing!.id),
            )
          else
            PrimaryFilledButton(
              label: 'Создать оповещение',
              onPressed: () => _create(context, ref),
            ),
        ],
      ),
    );
  }

  /// Guests can see the alert card but must sign in to subscribe — prompt them
  /// and open the auth screen if they accept.
  Future<void> _promptLogin(BuildContext context) async {
    final goToLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Нужен вход'),
        content: const Text(
          'Чтобы подписаться на оповещения о поездках по этому маршруту, '
          'сначала войдите в аккаунт.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Войти'),
          ),
        ],
      ),
    );
    if (goToLogin == true && context.mounted) {
      Navigator.of(context).push(
        HSRoute<void>(
          builder: (_) => const AuthScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(rideAlertsProvider.notifier).create(fromCity, toCity);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Оповещение создано — пришлём пуш по этому маршруту.'),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось создать оповещение.')),
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(rideAlertsProvider.notifier).remove(id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Оповещение отключено.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось отключить оповещение.')),
      );
    }
  }
}
