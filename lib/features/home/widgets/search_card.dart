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

    // Flat card — single solid `hs.cardBackground` fill. Previously had a
    // 3-stop diagonal gradient with a `hs.primary @ 0.08` tint in the
    // bottom-right corner that read as a glare on dark theme; user asked to
    // remove it. Keeps the saturated primary stroke (matches iOS), but
    // softens it slightly so the rim doesn't compete with the contents.
    final cardRadius = BorderRadius.circular(HSRadius.large);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hs.cardBackground,
        borderRadius: cardRadius,
        border: Border.all(
          color: hs.primary.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                // Icons mirror SF Symbols used by `HomeSearchRouteRow` in
                // `HomeSearchComponents.swift`:
                // `smallcircle.filled.circle.fill` → radio_button_checked,
                // `location.fill` → navigation_rounded,
                // `calendar` → calendar_today.
                _FieldButton(
                  icon: Icons.radio_button_checked,
                  iconColor: hs.primary,
                  title: 'Откуда',
                  value: searchState.hasSelectedFrom
                      ? search.fromLocation?.city.name
                      : null,
                  onTap: pickFrom,
                ),
                const _CardDivider(),
                _FieldButton(
                  icon: Icons.navigation_rounded,
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
