import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../../domain/date_formatter.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';
import '../../home/widgets/location_picker_sheet.dart';

/// Ported from `SearchResultsRouteSummary` in `SearchResultsViews.swift`.
///
/// A single editable summary of the active search: the route (with a swap
/// button) on top, and a bottom row carrying the date (left) and the passenger
/// count (right). Tapping the date or passenger cell calls back to the host
/// screen, which owns the pickers and the "specific day vs all dates" state.
class SearchRouteSummary extends ConsumerWidget {
  const SearchRouteSummary({
    super.key,
    required this.onTapDate,
    required this.onTapPassengers,
  });

  final VoidCallback onTapDate;
  final VoidCallback onTapPassengers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    final searchState = ref.watch(homeSearchProvider);
    final search = searchState.search;
    final notifier = ref.read(homeSearchProvider.notifier);
    final countries = ref.watch(availableTravelCountriesProvider);

    Future<void> pickFrom() async {
      final result = await showLocationPicker(
        context,
        title: tr('Откуда'),
        availableCountries: countries,
      );
      if (result != null) notifier.setFrom(result);
    }

    Future<void> pickTo() async {
      final result = await showLocationPicker(
        context,
        title: tr('Куда'),
        availableCountries: countries,
      );
      if (result != null) notifier.setTo(result);
    }

    return Container(
      decoration: BoxDecoration(
        color: hs.cardBackground,
        borderRadius: BorderRadius.circular(HSRadius.large),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          // Route block + swap button. The swap stays vertically centred
          // between the two city rows, so it lives in a Stack scoped to just
          // those rows (not the date/passenger row below).
          Stack(
            children: [
              Column(
                children: [
                  _routeRow(
                    context,
                    title: search.fromLocation?.city.name ?? tr('Откуда'),
                    icon: Icons.trip_origin,
                    color: hs.primary,
                    onTap: pickFrom,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Container(height: 1, color: hs.stroke),
                  ),
                  _routeRow(
                    context,
                    title: search.toLocation?.city.name ?? tr('Куда'),
                    icon: Icons.location_on,
                    color: hs.orange,
                    onTap: pickTo,
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
          Container(height: 1, color: hs.stroke),
          // Date (left, fills) + passenger count (right), split by a hairline.
          Row(
            children: [
              Expanded(
                child: _bottomCell(
                  context,
                  icon: Icons.calendar_today,
                  label: searchState.hasSelectedDate
                      ? _dateLabel(search.date)
                      : tr('Все даты'),
                  onTap: onTapDate,
                ),
              ),
              Container(width: 1, height: 26, color: hs.stroke),
              _bottomCell(
                context,
                icon: Icons.person_outline,
                label: '${search.passengers}',
                onTap: onTapPassengers,
                leadingGap: 16,
              ),
            ],
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 18, right: 46),
        child: Row(
          children: [
            SizedBox(width: 22, child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: HSText.subheadlineSemibold)),
          ],
        ),
      ),
    );
  }

  Widget _bottomCell(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    double leadingGap = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.only(top: 16, bottom: 16, left: leadingGap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              child: Icon(icon, size: 16, color: context.hs.primary),
            ),
            const SizedBox(width: 10),
            Text(label, style: HSText.subheadlineSemibold),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    if (DateUtilsX.isToday(date)) return tr('Сегодня');
    if (DateUtilsX.isTomorrow(date)) return tr('Завтра');
    return DateTextFormatter.dayMonthYear(date);
  }
}
