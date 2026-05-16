import 'package:flutter/material.dart';

import '../../../models/ride.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';

/// Ported from `MeetingPlaceChip` in `CreateRideWizardComponents.swift`.
class MeetingPlaceChip extends StatelessWidget {
  const MeetingPlaceChip({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? hs.primary : hs.secondarySurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? hs.primary : hs.stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HSText.subheadlineSemibold.copyWith(
                color: isSelected ? Colors.white : context.primaryText,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: HSText.caption.copyWith(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.76)
                    : context.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ported from `MeetingPlaceSelectorCard` in
/// `CreateRideWizardComponents.swift`.
class MeetingPlaceSelectorCard extends StatelessWidget {
  const MeetingPlaceSelectorCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.places,
    required this.selectedPlace,
    required this.customText,
    required this.isCustomSelected,
    required this.customController,
    required this.onChoose,
    required this.onCustomTextChanged,
  });

  final String title;
  final String subtitle;
  final List<RidePoint> places;
  final RidePoint? selectedPlace;
  final String customText;
  final bool isCustomSelected;
  final TextEditingController customController;

  /// `place == null && custom == false` -> "Без уточнения";
  /// `place != null` -> a popular place; `custom == true` -> "Свой вариант".
  final void Function(RidePoint? place, bool custom) onChoose;
  final ValueChanged<String> onCustomTextChanged;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final displayed = places.take(2).toList();

    final chips = <Widget>[
      MeetingPlaceChip(
        title: 'Без уточнения',
        subtitle: 'Только город',
        isSelected: selectedPlace == null && !isCustomSelected,
        onTap: () => onChoose(null, false),
      ),
      for (final place in displayed)
        MeetingPlaceChip(
          title: place.addressLine ?? place.title,
          subtitle: place.subtitle,
          isSelected: selectedPlace == place,
          onTap: () => onChoose(place, false),
        ),
      MeetingPlaceChip(
        title: 'Свой вариант',
        subtitle: customText.trim().isEmpty ? 'Указать вручную' : customText,
        isSelected: isCustomSelected,
        onTap: () => onChoose(null, true),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: HSText.headline),
            const Spacer(),
            Text(
              subtitle,
              style: HSText.captionSemibold.copyWith(
                color: context.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Можно выбрать популярную точку, если хотите сразу '
          'договориться о месте.',
          style: HSText.footnote.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: chips,
        ),
        if (isCustomSelected) ...[
          const SizedBox(height: 12),
          TextField(
            controller: customController,
            onChanged: onCustomTextChanged,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Например, Чорсу, вход 2',
              filled: true,
              fillColor: hs.secondarySurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: hs.stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: hs.stroke),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Ported from `MeetingPlaceSummaryRow` in `CreateRideWizardComponents.swift`.
class MeetingPlaceSummaryRow extends StatelessWidget {
  const MeetingPlaceSummaryRow({
    super.key,
    required this.title,
    required this.city,
    required this.value,
    required this.accent,
  });

  final String title;
  final String city;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hs.secondarySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hs.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title - $city',
                  style: HSText.captionSemibold.copyWith(
                    color: context.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: HSText.subheadlineSemibold),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ported from `CreateSummaryRouteHero` in `CreateRideWizardComponents.swift`.
class CreateSummaryRouteHero extends StatelessWidget {
  const CreateSummaryRouteHero({
    super.key,
    required this.accent,
    required this.badgeTitle,
    required this.fromCity,
    required this.toCity,
    required this.fromCountry,
    required this.toCountry,
  });

  final Color accent;
  final String badgeTitle;
  final String fromCity;
  final String toCity;
  final String fromCountry;
  final String toCountry;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: hs.secondarySurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: hs.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              badgeTitle,
              style: HSText.captionSemibold.copyWith(color: accent),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _endpoint(context, fromCity, fromCountry)),
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Icon(Icons.arrow_forward, size: 18, color: accent),
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _endpoint(context, toCity, toCountry)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _endpoint(BuildContext context, String city, String country) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          country,
          style: HSText.subheadlineMedium.copyWith(
            color: context.secondaryText,
          ),
        ),
      ],
    );
  }
}

/// Ported from `CreateSummaryMetricCard` in `CreateRideWizardComponents.swift`.
class CreateSummaryMetricCard extends StatelessWidget {
  const CreateSummaryMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hs.secondarySurface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hs.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: HSText.captionMedium.copyWith(color: context.secondaryText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HSText.headline,
          ),
        ],
      ),
    );
  }
}
