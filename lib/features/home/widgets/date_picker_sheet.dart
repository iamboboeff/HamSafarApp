import 'package:flutter/material.dart';

import 'package:hamsafar/core/i18n/l10n.dart';
import '../../../domain/date_formatter.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/month_calendar.dart';

/// Ported from `HomeSearchDatePickerSheet` in `HomeSearchComponents.swift` —
/// a scrollable 12-month calendar in a bottom sheet.
Future<DateTime?> showDatePickerSheet(
  BuildContext context, {
  required DateTime initialDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DatePickerSheet(initialDate: initialDate),
  );
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selected = widget.initialDate;
  late final DateTime _earliest = DateUtilsX.startOfDay(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: hs.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('Закрыть')),
                  ),
                  Expanded(
                    child: Text(
                      tr('Когда вы едете?'),
                      textAlign: TextAlign.center,
                      style: HSText.headline,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(tr('Готово')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MonthCalendar(
                  selectedDate: _selected,
                  earliestDate: _earliest,
                  // null => fill the sheet's bounded Expanded via an inner
                  // Expanded. Passing double.infinity here used to wrap the
                  // ListView in a SizedBox(height: infinity), giving the
                  // viewport unbounded height and rendering an empty calendar.
                  scrollHeight: null,
                  onSelect: (date) {
                    setState(() => _selected = date);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (context.mounted) Navigator.of(context).pop(date);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
