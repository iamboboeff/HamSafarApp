import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';

/// Ported from `SearchResultsRouteSummary` in `SearchResultsViews.swift`.
class SearchRouteSummary extends ConsumerWidget {
  const SearchRouteSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    final search = ref.watch(homeSearchProvider).search;
    final notifier = ref.read(homeSearchProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: hs.cardBackground,
        borderRadius: BorderRadius.circular(HSRadius.large),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Stack(
        children: [
          Column(
            children: [
              _routeRow(
                context,
                title: search.fromLocation?.city.name ?? 'Откуда',
                icon: Icons.trip_origin,
                color: hs.primary,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: Container(height: 1, color: hs.stroke),
              ),
              _routeRow(
                context,
                title: search.toLocation?.city.name ?? 'Куда',
                icon: Icons.location_on,
                color: hs.orange,
              ),
            ],
          ),
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: notifier.swapLocations,
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hs.secondarySurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: hs.stroke),
                  ),
                  child: const Icon(Icons.swap_vert, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 18, right: 46),
      child: Row(
        children: [
          SizedBox(width: 22, child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: HSText.subheadlineSemibold)),
        ],
      ),
    );
  }
}
