import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../domain/date_formatter.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/buttons.dart';
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

    Future<void> pickDate() async {
      final result = await showDatePickerSheet(
        context,
        initialDate: search.date,
      );
      if (result != null) notifier.setDate(result);
    }

    Future<void> pickPassengers() async {
      final result = await showPassengersPickerSheet(
        context,
        initialCount: search.passengers,
      );
      if (result != null) notifier.setPassengers(result);
    }

    // Flat card — single solid `hs.cardBackground` fill. The primary rim is
    // painted as a `foregroundDecoration` (over the children), NOT as a
    // `decoration` border (under them). The card clips its content to the
    // rounded rect — including the flush submit button — and the stroke is
    // then drawn on top as one continuous line all the way around. Drawing it
    // as an ordinary border let the antialiased clip and the seam where the
    // stroke crossed the bright submit button read as an uneven/ragged rim;
    // the foreground stroke is crisp and even. A 1.5px width stays sharp.
    final cardRadius = BorderRadius.circular(HSRadius.large);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hs.cardBackground,
        borderRadius: cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: cardRadius,
        border: Border.all(
          color: hs.primary.withValues(alpha: 0.6),
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
                // Icons mirror SF Symbols used by `HomeSearchRouteRow` in
                // `HomeSearchComponents.swift`:
                // `smallcircle.filled.circle.fill` → radio_button_checked,
                // `location.fill` → navigation_rounded,
                // `calendar` → calendar_today.
                _FieldButton(
                  icon: Icons.radio_button_checked,
                  iconColor: hs.primary,
                  title: tr('Откуда'),
                  value: searchState.hasSelectedFrom
                      ? search.fromLocation?.city.name
                      : null,
                  onTap: pickFrom,
                ),
                const _CardDivider(),
                _FieldButton(
                  icon: Icons.navigation_rounded,
                  iconColor: hs.orange,
                  title: tr('Куда'),
                  value: searchState.hasSelectedTo
                      ? search.toLocation?.city.name
                      : null,
                  onTap: pickTo,
                ),
                const _CardDivider(),
                _FieldButton(
                  icon: Icons.calendar_today,
                  iconColor: hs.primary,
                  title: tr('Когда'),
                  // Defaults to "Все даты" until the rider picks a concrete day.
                  value: searchState.hasSelectedDate
                      ? _dateValue(search.date)
                      : tr('Все даты'),
                  onTap: pickDate,
                ),
                const _CardDivider(),
                // Passenger count, mirroring the reference search card — lets
                // riders ask for several seats up front. Always has a value
                // (defaults to 1), so it renders in primary text.
                _FieldButton(
                  icon: Icons.person_outline,
                  iconColor: hs.primary,
                  title: tr('Пассажиры'),
                  value: _passengersValue(search.passengers),
                  onTap: pickPassengers,
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
    if (DateUtilsX.isToday(date)) return tr('Сегодня');
    if (DateUtilsX.isTomorrow(date)) return tr('Завтра');
    return DateTextFormatter.dayMonthYear(date);
  }

  // Count is clamped to 1..4, so only the singular ("пассажир") and the 2–4
  // genitive-singular ("пассажира") Russian forms can occur. Tajik has no such
  // count agreement — both templates map to the single «{count} мусофир» form.
  static String _passengersValue(int count) {
    return count == 1
        ? trf('{count} пассажир', {'count': count})
        : trf('{count} пассажира', {'count': count});
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
                  tr('Поиск'),
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

/// A compact bottom sheet for choosing the passenger count (clamped 1..4) with
/// a − N + stepper, matching the date/location pickers' presentation.
Future<int?> showPassengersPickerSheet(
  BuildContext context, {
  required int initialCount,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PassengersPickerSheet(initialCount: initialCount),
  );
}

class _PassengersPickerSheet extends StatefulWidget {
  const _PassengersPickerSheet({required this.initialCount});

  final int initialCount;

  @override
  State<_PassengersPickerSheet> createState() => _PassengersPickerSheetState();
}

class _PassengersPickerSheetState extends State<_PassengersPickerSheet> {
  static const int _min = 1;
  static const int _max = 4;
  late int _count = widget.initialCount.clamp(_min, _max);

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      decoration: BoxDecoration(
        color: hs.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: hs.stroke,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Text(tr('Сколько пассажиров?'), style: HSText.headline),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepperButton(
                icon: Icons.remove,
                enabled: _count > _min,
                onTap: () => setState(() => _count--),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '$_count',
                  textAlign: TextAlign.center,
                  style: HSText.largeTitle,
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                enabled: _count < _max,
                onTap: () => setState(() => _count++),
              ),
            ],
          ),
          const SizedBox(height: 28),
          PrimaryFilledButton(
            label: tr('Готово'),
            onPressed: () => Navigator.of(context).pop(_count),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: hs.primary, width: 1.5),
          ),
          child: Icon(icon, size: 24, color: hs.primary),
        ),
      ),
    );
  }
}
