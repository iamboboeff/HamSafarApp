import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/common.dart';

/// Ported from `TopOverlayScrim` in `SearchUIComponents.swift` — a dimming
/// scrim with content pinned near the top.
class TopOverlayScrim extends StatelessWidget {
  const TopOverlayScrim({
    super.key,
    required this.child,
    required this.onDismiss,
  });

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onDismiss,
            child: Container(color: Colors.black.withValues(alpha: 0.22)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(alignment: Alignment.topCenter, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared card chrome for the search overlays.
class _OverlayCard extends StatelessWidget {
  const _OverlayCard({
    required this.title,
    required this.onClose,
    required this.children,
  });

  final String title;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hs.cardBackground,
        borderRadius: BorderRadius.circular(HSRadius.large),
        border: Border.all(color: hs.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: HSText.headline),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hs.secondarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

/// Ported from `SearchCalendarOverlay` in `SearchUIComponents.swift`.
class SearchCalendarOverlay extends StatefulWidget {
  const SearchCalendarOverlay({
    super.key,
    required this.initialDate,
    required this.onConfirm,
    required this.onClose,
  });

  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;
  final VoidCallback onClose;

  @override
  State<SearchCalendarOverlay> createState() => _SearchCalendarOverlayState();
}

class _SearchCalendarOverlayState extends State<SearchCalendarOverlay> {
  late DateTime _draft = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _OverlayCard(
      title: 'Дата поездки',
      onClose: widget.onClose,
      children: [
        CalendarDatePicker(
          initialDate: _draft,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: DateTime(now.year + 1, now.month, now.day),
          onDateChanged: (date) => setState(() => _draft = date),
        ),
        const SizedBox(height: 8),
        PrimaryFilledButton(
          label: 'Выбрать дату',
          onPressed: () => widget.onConfirm(_draft),
        ),
      ],
    );
  }
}

/// Ported from `SearchFiltersOverlay` + `CompactStepperTile` in
/// `SearchUIComponents.swift`.
class SearchFiltersOverlay extends StatelessWidget {
  const SearchFiltersOverlay({
    super.key,
    required this.passengers,
    required this.onChanged,
    required this.onClose,
  });

  final int passengers;
  final ValueChanged<int> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return _OverlayCard(
      title: 'Фильтры',
      onClose: onClose,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hs.background,
            borderRadius: BorderRadius.circular(HSRadius.medium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, size: 14, color: context.secondaryText),
                  const SizedBox(width: 6),
                  Text(
                    'Пассажиры',
                    style: HSText.caption.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('$passengers', style: HSText.title3),
              const SizedBox(height: 10),
              Row(
                children: [
                  CounterButton(
                    icon: Icons.remove,
                    onTap: () => onChanged((passengers - 1).clamp(1, 4)),
                  ),
                  const SizedBox(width: 10),
                  CounterButton(
                    icon: Icons.add,
                    onTap: () => onChanged((passengers + 1).clamp(1, 4)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryFilledButton(label: 'Показать результаты', onPressed: onClose),
      ],
    );
  }
}
