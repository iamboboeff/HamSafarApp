import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location.dart';
import '../models/ride_search.dart';
import '../state/app_state.dart';

/// Ported from `HomeFlowDomain` in `HomeFlowDomain.swift`.
abstract final class HomeFlow {
  /// Resolves a [LocationSelection] from a search-history city name, preferring
  /// the recorded country when present.
  static LocationSelection? _resolve(String cityName, String? countryName) {
    if (countryName != null) {
      final match = LocationDirectory.find(
        countryName: countryName,
        cityName: cityName,
      );
      if (match != null) return match;
    }
    for (final country in LocationDirectory.countries) {
      for (final city in country.routeLocations) {
        if (city.name == cityName) {
          return LocationSelection(
            country: country,
            city: city,
            region: city.name,
          );
        }
      }
    }
    return null;
  }

  /// Applies a recent-search item back into the home search form.
  static void applySearchHistoryItem(
    LocationSearchHistoryItem item,
    WidgetRef ref,
  ) {
    final from = _resolve(item.from, item.fromCountry);
    final to = _resolve(item.to, item.toCountry);
    if (from != null && to != null) {
      ref.read(homeSearchProvider.notifier).applyRoute(from, to);
    }
  }
}
