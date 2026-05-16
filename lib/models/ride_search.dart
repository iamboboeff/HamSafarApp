import 'location.dart';

/// Ported from `RideSearch` in `SearchDomain.swift`.
class RideSearch {
  const RideSearch({
    this.fromLocation,
    this.toLocation,
    required this.date,
    this.passengers = 1,
  });

  final LocationSelection? fromLocation;
  final LocationSelection? toLocation;
  final DateTime date;
  final int passengers;

  RideSearch copyWith({
    LocationSelection? fromLocation,
    LocationSelection? toLocation,
    DateTime? date,
    int? passengers,
  }) {
    return RideSearch(
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      date: date ?? this.date,
      passengers: passengers ?? this.passengers,
    );
  }
}

/// Ported from `HomeSearchState` in `SearchDomain.swift`.
class HomeSearchState {
  HomeSearchState({
    RideSearch? search,
    this.hasSelectedFrom = false,
    this.hasSelectedTo = false,
  }) : search = search ?? RideSearch(date: DateTime.now());

  final RideSearch search;
  final bool hasSelectedFrom;
  final bool hasSelectedTo;

  ({LocationSelection from, LocationSelection to})? get selectedRoute {
    final from = search.fromLocation;
    final to = search.toLocation;
    if (!hasSelectedFrom || !hasSelectedTo || from == null || to == null) {
      return null;
    }
    return (from: from, to: to);
  }

  bool get canSearch => selectedRoute != null;

  HomeSearchState copyWith({
    RideSearch? search,
    bool? hasSelectedFrom,
    bool? hasSelectedTo,
  }) {
    return HomeSearchState(
      search: search ?? this.search,
      hasSelectedFrom: hasSelectedFrom ?? this.hasSelectedFrom,
      hasSelectedTo: hasSelectedTo ?? this.hasSelectedTo,
    );
  }

  HomeSearchState applyRoute(LocationSelection from, LocationSelection to) {
    return HomeSearchState(
      search: search.copyWith(fromLocation: from, toLocation: to),
      hasSelectedFrom: true,
      hasSelectedTo: true,
    );
  }

  HomeSearchState swapLocations() {
    final route = selectedRoute;
    if (route == null) return this;
    return copyWith(
      search: search.copyWith(fromLocation: route.to, toLocation: route.from),
    );
  }

  LocationSearchHistoryItem? makeHistoryItem() {
    final route = selectedRoute;
    if (route == null) return null;
    return LocationSearchHistoryItem(
      from: route.from.city.name,
      to: route.to.city.name,
      fromCountry: route.from.country.name,
      toCountry: route.to.country.name,
    );
  }
}

/// Ported from `LocationSearchHistoryItem` in `SearchDomain.swift`.
class LocationSearchHistoryItem {
  LocationSearchHistoryItem({
    String? id,
    required this.from,
    required this.to,
    this.fromCountry,
    this.toCountry,
  }) : id = id ?? '$from→$to';

  final String id;
  final String from;
  final String to;
  final String? fromCountry;
  final String? toCountry;
}

/// Ported from `SearchDateOption` in `SearchUIComponents.swift`.
class SearchDateOption {
  const SearchDateOption({
    required this.key,
    required this.date,
    required this.title,
    required this.count,
    required this.isAllDates,
  });

  final String key;
  final DateTime date;
  final String title;
  final int count;
  final bool isAllDates;
}
