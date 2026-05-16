import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../domain/date_formatter.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';

/// Ported from `wizardHeader` in `CreateRideViews.swift` — a circular back
/// button, title/subtitle, and a progress bar.
class WizardHeader extends StatelessWidget {
  const WizardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final double progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hs.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: HSText.subheadline.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: hs.stroke,
            color: hs.primary,
          ),
        ),
      ],
    );
  }
}

/// Ported from `PassengerRequestRouteRow` / `PassengerRequestDateRow` /
/// `PassengerRequestTimeRow` — a tappable field row used across the create
/// flow (route endpoints, date and time).
class WizardFieldRow extends StatelessWidget {
  const WizardFieldRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: hs.background,
          borderRadius: BorderRadius.circular(HSRadius.medium),
        ),
        child: Row(
          children: [
            SizedBox(width: 22, child: Icon(icon, size: 18, color: iconColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? placeholder,
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

/// Ported from `CreateCounterSelector` in `CreateRidePassengerComponents.swift`.
class CreateCounterSelector extends StatelessWidget {
  const CreateCounterSelector({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 28),
      child: Row(
        children: [
          _circleButton(
            context,
            icon: Icons.remove,
            enabled: value > min,
            onTap: () => onChanged((value - 1).clamp(min, max)),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _circleButton(
            context,
            icon: Icons.add,
            enabled: value < max,
            onTap: () => onChanged((value + 1).clamp(min, max)),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final hs = context.hs;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: hs.primary.withValues(alpha: 0.55)),
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? hs.primary : context.secondaryText,
        ),
      ),
    );
  }
}

/// Ported from `CreateCheckboxOptionCard` in `CreateRideWizardComponents.swift`.
class CreateCheckboxOptionCard extends StatelessWidget {
  const CreateCheckboxOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.trailingIcon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final IconData trailingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isSelected ? hs.primary : Colors.transparent,
                border: Border.all(
                  color: hs.primary.withValues(alpha: isSelected ? 1 : 0.85),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HSText.subheadlineSemibold),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: HSText.footnote.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(trailingIcon, size: 16, color: context.secondaryText),
          ],
        ),
      ),
    );
  }
}

/// Ported from `AmountEntryCard` in `CreateRideWizardComponents.swift`.
class AmountEntryCard extends StatelessWidget {
  const AmountEntryCard({
    super.key,
    required this.title,
    required this.placeholder,
    required this.currencyCode,
    required this.controller,
    required this.onChanged,
  });

  final String title;
  final String placeholder;
  final String currencyCode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: HSText.subheadlineSemibold.copyWith(
            color: context.secondaryText,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hs.secondarySurface,
            borderRadius: BorderRadius.circular(HSRadius.medium),
            border: Border.all(color: hs.stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: hs.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      onChanged: onChanged,
                      keyboardType: TextInputType.number,
                      style: HSText.title3,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: placeholder,
                        hintStyle: HSText.title3.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ),
                    Text(
                      currencyCode,
                      style: HSText.captionSemibold.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ported from `SearchInfoTile` in `SearchUIComponents.swift`.
class SearchInfoTile extends StatelessWidget {
  const SearchInfoTile({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hs.background,
        borderRadius: BorderRadius.circular(HSRadius.medium),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: hs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: HSText.caption.copyWith(color: context.secondaryText),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HSText.subheadlineSemibold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from `CreateTimeSelectionCard` in
/// `CreateRidePassengerComponents.swift` — a pill that opens a wheel time
/// picker.
class CreateTimeSelectionCard extends StatelessWidget {
  const CreateTimeSelectionCard({
    super.key,
    required this.title,
    required this.time,
    required this.onChanged,
  });

  final String title;
  final DateTime time;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: () => showWizardTimePicker(
        context,
        title: title,
        initial: time,
        onChanged: onChanged,
      ),
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: hs.secondarySurface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: hs.stroke),
        ),
        child: Row(
          children: [
            const Spacer(),
            Text(
              DateTextFormatter.time(time),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, color: hs.primary),
          ],
        ),
      ),
    );
  }
}

/// Shared wheel time picker bottom sheet (Cupertino wheel, matching the iOS
/// `.wheel` `DatePicker`).
Future<void> showWizardTimePicker(
  BuildContext context, {
  required String title,
  required DateTime initial,
  required ValueChanged<DateTime> onChanged,
}) {
  var picked = initial;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.hs.background,
    builder: (sheetContext) {
      return SizedBox(
        height: 320,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(title, style: HSText.headline),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: initial,
                onDateTimeChanged: (value) {
                  picked = value;
                  onChanged(value);
                },
              ),
            ),
          ],
        ),
      );
    },
  ).then((_) => onChanged(picked));
}
