import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamsafar/core/i18n/l10n.dart';

import '../../domain/date_formatter.dart';
import '../../domain/search_date_options.dart';
import '../../domain/trips_domain.dart';
import '../../models/app_tab.dart';
import '../../models/passenger_request.dart';
import '../../models/ride.dart';
import '../../models/ride_alert.dart';
import '../../models/telegram_ride_lead.dart';
import '../../state/app_state.dart';
import '../../state/telegram_leads_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/passenger_request_card.dart';
import '../../widgets/ride_card.dart';
import '../../widgets/telegram_ride_card.dart';
import '../auth/auth_screen.dart';
import '../home/widgets/date_picker_sheet.dart';
import '../home/widgets/search_card.dart' show showPassengersPickerSheet;
import '../ride_detail/passenger_request_detail_screen.dart';
import '../ride_detail/ride_detail_screen.dart';
import 'widgets/search_filter_bar.dart';
import 'widgets/search_mode_tabs.dart';
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
  // Collapsing-banner extents; the fold consumes the first
  // (_bannerMaxExtent - _bannerMinExtent) px of scroll.
  static const double _bannerMaxExtent = 250;
  static const double _bannerMinExtent = 74;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // When a scroll settles with the banner folded part-way, snap it fully open
  // or fully closed (whichever edge is nearer).
  bool _snapHeader(ScrollEndNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    const range = _bannerMaxExtent - _bannerMinExtent;
    final offset = notification.metrics.pixels;
    if (offset > 0 && offset < range) {
      final target = offset < range / 2 ? 0.0 : range;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(homeSearchProvider);
    final search = searchState.search;
    final hasSelectedDate = searchState.hasSelectedDate;
    final marketplace = ref.watch(marketplaceProvider);
    final telegramState = ref.watch(telegramLeadsProvider);
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
    final filteredRides = hasSelectedDate
        ? displayedRides
              .where((r) => DateUtilsX.isSameDay(r.departureDate, search.date))
              .toList()
        : displayedRides;

    final displayedRequests = [...passengerMatches]
      ..sort((a, b) => a.departureDate.compareTo(b.departureDate));
    final filteredRequests = hasSelectedDate
        ? displayedRequests
              .where((r) => DateUtilsX.isSameDay(r.departureDate, search.date))
              .toList()
        : displayedRequests;

    final telegramMatches = (from == null || to == null)
        ? telegramState.items
        : telegramState.items
              .where((lead) => lead.matchesRoute(from, to))
              .toList();
    final filteredTelegram = hasSelectedDate
        ? telegramMatches
              .where(
                (lead) => DateUtilsX.isSameDay(lead.groupingDate, search.date),
              )
              .toList()
        : telegramMatches;

    final dateSourceDates = switch (section) {
      HomeListingSection.rides =>
        rideMatches.map((r) => r.departureDate).toList(),
      HomeListingSection.passengers =>
        passengerMatches.map((r) => r.departureDate).toList(),
      HomeListingSection.telegram =>
        telegramMatches.map((lead) => lead.groupingDate).toList(),
    };
    final dateOptions = groupedDateOptions(
      dates: dateSourceDates,
      selectedDate: search.date,
      includeSelectedDateIfMissing: hasSelectedDate,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Поиск'))),
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
              Expanded(
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: _snapHeader,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.wait([
                        ref.read(marketplaceProvider.notifier).refresh(),
                        ref.read(telegramLeadsProvider.notifier).refresh(),
                      ]);
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      slivers: [
                        // Collapsing route banner. It IS a scroll header, so its
                        // height tracks the drag 1:1 — it folds under the finger
                        // as you scroll down and unfolds as you scroll back up.
                        // Pinned, so the compact route bar stays when fully
                        // folded; tapping it scrolls back to the top to reopen.
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _RouteBannerDelegate(
                            maxExtent: _bannerMaxExtent,
                            minExtent: _bannerMinExtent,
                            expanded: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                14,
                                20,
                                12,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SearchRouteSummary(
                                    onTapDate: () async {
                                      final notifier = ref.read(
                                        homeSearchProvider.notifier,
                                      );
                                      final result = await showDatePickerSheet(
                                        context,
                                        initialDate: search.date,
                                      );
                                      // setDate flips hasSelectedDate → results
                                      // filter to the picked day.
                                      if (result != null) {
                                        notifier.setDate(result);
                                      }
                                    },
                                    onTapPassengers: () async {
                                      final notifier = ref.read(
                                        homeSearchProvider.notifier,
                                      );
                                      final result =
                                          await showPassengersPickerSheet(
                                            context,
                                            initialCount: search.passengers,
                                          );
                                      if (result != null) {
                                        notifier.setPassengers(result);
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SearchFilterBar(
                                    dateOptions: dateOptions,
                                    isAllDatesSelected: !hasSelectedDate,
                                    selectedDate: search.date,
                                    onSelectDateOption: (option) {
                                      final notifier = ref.read(
                                        homeSearchProvider.notifier,
                                      );
                                      if (option.isAllDates) {
                                        notifier.clearDate();
                                      } else {
                                        notifier.setDate(option.date);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            collapsed: Padding(
                              // Same top gap as the expanded card so the folded
                              // bar isn't crowded against the tab underline.
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                              child: _CollapsedRouteBar(
                                from: from ?? tr('Откуда'),
                                to: to ?? tr('Куда'),
                                onTap: () => _scrollController.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              ...switch (section) {
                                HomeListingSection.rides => _buildRideResults(
                                  filteredRides,
                                ),
                                HomeListingSection.passengers =>
                                  _buildRequestResults(filteredRequests),
                                HomeListingSection.telegram =>
                                  _buildTelegramResults(
                                    filteredTelegram,
                                    telegramState,
                                  ),
                              },
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
        _emptyText(tr('По этому маршруту пока нет доступных поездок.')),
        if (from != null && to != null) ...[
          const SizedBox(height: 16),
          _RideAlertCard(fromCity: from, toCity: to),
        ],
      ];
    }
    final groups = _groupByDay(rides, (r) => r.departureDate);
    return [
      for (final group in groups) ...[
        _DaySectionHeader(date: group.date),
        for (final ride in group.items) ...[
          RideCard(
            ride: ride,
            onTap: () => Navigator.of(
              context,
            ).push(HSRoute<void>(builder: (_) => RideDetailScreen(ride: ride))),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  List<Widget> _buildRequestResults(List<PassengerRequest> requests) {
    if (requests.isEmpty) {
      return [_emptyText(tr('По этому маршруту пока нет запросов пассажиров.'))];
    }
    final groups = _groupByDay(requests, (r) => r.departureDate);
    return [
      for (final group in groups) ...[
        _DaySectionHeader(date: group.date),
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

  List<Widget> _buildTelegramResults(
    List<TelegramRideLead> leads,
    TelegramLeadsState telegramState,
  ) {
    if (leads.isEmpty) {
      if (telegramState.hasLoadFailed) {
        return [
          _telegramSafetyBanner(),
          const SizedBox(height: 12),
          _emptyText(
            tr(
              'Не удалось загрузить объявления из Telegram. Проверьте подключение к интернету.',
            ),
          ),
          const SizedBox(height: 16),
          PrimaryFilledButton(
            label: tr('Повторить'),
            isLoading: telegramState.isLoading,
            onPressed: () => ref.read(telegramLeadsProvider.notifier).refresh(),
          ),
        ];
      }
      return [
        _telegramSafetyBanner(),
        const SizedBox(height: 12),
        _emptyText(tr('По этому маршруту пока нет объявлений из Telegram.')),
      ];
    }
    final groups = _groupByDay(leads, (lead) => lead.groupingDate);
    return [
      _telegramSafetyBanner(),
      const SizedBox(height: 14),
      for (final group in groups) ...[
        _DaySectionHeader(date: group.date),
        for (final lead in group.items) ...[
          TelegramRideCard(lead: lead),
          const SizedBox(height: 12),
        ],
      ],
    ];
  }

  Widget _telegramSafetyBanner() {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hs.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hs.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: hs.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(
                'Объявления из открытых источников. HamSafar их не проверяет, бронирование недоступно — связывайтесь напрямую.',
              ),
              style: HSText.caption.copyWith(
                color: context.secondaryText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
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
/// Scroll-linked collapsing header. Lays the full banner and the compact bar
/// at the top of a fixed [maxExtent] box and cross-fades between them as the
/// header shrinks — so the fold tracks the scroll offset (and the finger) 1:1.
class _RouteBannerDelegate extends SliverPersistentHeaderDelegate {
  _RouteBannerDelegate({
    required this.expanded,
    required this.collapsed,
    required this.maxExtent,
    required this.minExtent,
  });

  final Widget expanded;
  final Widget collapsed;

  @override
  final double maxExtent;

  @override
  final double minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 0.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    return ClipRect(
      child: SizedBox(
        height: maxExtent,
        // Flat opaque base matching the page background, so results scroll
        // cleanly UNDER the pinned header.
        child: ColoredBox(
          color: context.hs.background,
          child: Stack(
            children: [
              // Full banner — fades out over the first ~70% of the fold.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: t > 0.5,
                  child: Opacity(
                    opacity: (1 - t / 0.7).clamp(0.0, 1.0),
                    child: expanded,
                  ),
                ),
              ),
              // Compact bar — fades in over the last ~45%.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: t < 0.55,
                  child: Opacity(
                    opacity: ((t - 0.55) / 0.45).clamp(0.0, 1.0),
                    child: collapsed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _RouteBannerDelegate oldDelegate) => true;
}

/// Compact route bar shown when the banner is collapsed. Tapping it expands
/// the full editable route card again.
class _CollapsedRouteBar extends StatelessWidget {
  const _CollapsedRouteBar({
    required this.from,
    required this.to,
    required this.onTap,
  });

  final String from;
  final String to;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: hs.cardBackground,
          borderRadius: BorderRadius.circular(HSRadius.large),
          border: Border.all(color: hs.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.alt_route, size: 16, color: hs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$from → $to',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HSText.subheadlineSemibold,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: context.secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySectionHeader extends StatelessWidget {
  const _DaySectionHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 1, 2, 11),
      child: Text(
        DateTextFormatter.resultsSectionTitle(date),
        style: HSText.subheadlineSemibold.copyWith(
          color: context.secondaryText,
        ),
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
                      ? tr('Оповещение включено')
                      : tr('Сообщить, когда появится поездка'),
                  style: HSText.subheadlineSemibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subscribed
                ? trf(
                    'Пришлём пуш, как только кто-то опубликует поездку '
                    '{from} → {to}.',
                    {'from': fromCity, 'to': toCity},
                  )
                : trf(
                    'Подпишитесь на маршрут {from} → {to} — пришлём '
                    'уведомление, как только появится поездка.',
                    {'from': fromCity, 'to': toCity},
                  ),
            style: HSText.subheadline.copyWith(color: context.secondaryText),
          ),
          const SizedBox(height: 14),
          if (!isAuth) ...[
            PrimaryFilledButton(
              label: tr('Создать оповещение'),
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
                    tr('Войдите в аккаунт, чтобы подписаться на оповещения.'),
                    style: HSText.caption.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (subscribed)
            DestructiveOutlineButton(
              label: tr('Отключить оповещение'),
              onPressed: () => _remove(context, ref, existing!.id),
            )
          else
            PrimaryFilledButton(
              label: tr('Создать оповещение'),
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
        title: Text(tr('Нужен вход')),
        content: Text(
          tr(
            'Чтобы подписаться на оповещения о поездках по этому маршруту, '
            'сначала войдите в аккаунт.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Войти')),
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
        SnackBar(
          content: Text(
            tr('Оповещение создано — пришлём пуш по этому маршруту.'),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Не удалось создать оповещение.'))),
      );
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(rideAlertsProvider.notifier).remove(id);
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Оповещение отключено.'))),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Не удалось отключить оповещение.'))),
      );
    }
  }
}
