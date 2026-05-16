import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/date_formatter.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';
import 'date_picker_sheet.dart';
import 'location_picker_sheet.dart';

/// Ported from `SearchCardView` in `HomeSearchComponents.swift`.
class SearchCard extends ConsumerWidget {
  const SearchCard({
    super.key,
    required this.isLoading,
    required this.onSearch,
  });

  final bool isLoading;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    final searchState = ref.watch(homeSearchProvider);
    final notifier = ref.read(homeSearchProvider.notifier);
    final countries = ref.watch(availableTravelCountriesProvider);
    final search = searchState.search;
    final canSearch = searchState.hasSelectedFrom && searchState.hasSelectedTo;

    Future<void> pickFrom() async {
      final result = await showLocationPicker(
        context,
        title: 'Откуда',
        availableCountries: countries,
      );
      if (result != null) notifier.setFrom(result);
    }

    Future<void> pickTo() async {
      final result = await showLocationPicker(
        context,
        title: 'Куда',
        availableCountries: countries,
      );
      if (result != null) notifier.setTo(result);
    }

    Future<void> pickDate() async {
      final result = await showDatePickerSheet(
        context,
        initialDate: search.date,
      );
      if (result != null) notifier.setDate(result);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(HSRadius.card),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hs.cardBackground.withValues(alpha: 0.96),
              hs.cardBackground.withValues(alpha: 0.90),
              hs.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(HSRadius.card),
          border: Border.all(
            color: hs.primary.withValues(alpha: 0.9),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HSSpacing.cardPadding,
                14,
                HSSpacing.cardPadding,
                12,
              ),
              child: Column(
                children: [
                  _FieldButton(
                    icon: Icons.trip_origin,
                    iconColor: hs.primary,
                    title: 'Откуда',
                    value: searchState.hasSelectedFrom
                        ? search.fromLocation?.city.name
                        : null,
                    onTap: pickFrom,
                  ),
                  const _CardDivider(),
                  _FieldButton(
                    icon: Icons.location_on,
                    iconColor: hs.orange,
                    title: 'Куда',
                    value: searchState.hasSelectedTo
                        ? search.toLocation?.city.name
                        : null,
                    onTap: pickTo,
                  ),
                  const _CardDivider(),
                  _FieldButton(
                    icon: Icons.calendar_today,
                    iconColor: hs.primary,
                    title: 'Когда',
                    value: _dateValue(search.date),
                    onTap: pickDate,
                  ),
                ],
              ),
            ),
            _SubmitButton(
              isLoading: isLoading,
              isEnabled: canSearch,
              onTap: onSearch,
            ),
          ],
        ),
      ),
    );
  }

  static String _dateValue(DateTime date) {
    if (DateUtilsX.isToday(date)) return 'Сегодня';
    if (DateUtilsX.isTomorrow(date)) return 'Завтра';
    return DateTextFormatter.dayMonthYear(date);
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 44),
      child: Container(height: 1, color: context.hs.stroke),
    );
  }
}

/// Ported from `HomeSearchFieldButton` in `HomeSearchComponents.swift`.
class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: HSControlSize.searchRowHeight,
        child: Row(
          children: [
            SizedBox(width: 22, child: Icon(icon, size: 18, color: iconColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HSText.headline.copyWith(
                  color: hasValue ? context.primaryText : context.secondaryText,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: context.secondaryText),
          ],
        ),
      ),
    );
  }
}

/// Ported from `HomeSearchSubmitButton` in `HomeSearchComponents.swift`.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onTap,
  });

  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final active = isEnabled && !isLoading;
    return GestureDetector(
      onTap: active ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: active ? 1 : 0.6,
        child: Container(
          height: HSControlSize.searchButtonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [hs.primary, hs.primary.withValues(alpha: 0.82)],
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Поиск',
                  style: HSText.headline.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
