import 'package:flutter/material.dart';

import '../../../models/location.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';

/// Ported from `HomeLocationPickerSheet` in `HomeSearchComponents.swift`.
///
/// Presents a searchable list of every city in [availableCountries] and
/// resolves with the chosen [LocationSelection] (or `null` if dismissed).
Future<LocationSelection?> showLocationPicker(
  BuildContext context, {
  required String title,
  required List<LocationCountry> availableCountries,
}) {
  return showModalBottomSheet<LocationSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LocationPickerSheet(
      title: title,
      availableCountries: availableCountries,
    ),
  );
}

class _LocationOption {
  _LocationOption({
    required this.selection,
    required this.title,
    required this.subtitle,
    required this.keywords,
  });

  final LocationSelection selection;
  final String title;
  final String subtitle;
  final List<String> keywords;

  bool matches(String query) {
    final normalized = query.toLowerCase().trim();
    return keywords.any((k) => k.toLowerCase().contains(normalized));
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.title,
    required this.availableCountries,
  });

  final String title;
  final List<LocationCountry> availableCountries;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  String _query = '';

  List<_LocationOption> get _allOptions {
    final countries = widget.availableCountries.isEmpty
        ? LocationDirectory.countries
        : widget.availableCountries;
    return [
      for (final country in countries)
        for (final city in country.cities)
          _LocationOption(
            selection: LocationSelection(
              country: country,
              city: city,
              region: city.name,
            ),
            title: city.name,
            subtitle: country.name,
            // Keyword match is per-city: the city's own name plus the country.
            // Previously every city also carried the whole `country.regions`
            // list, so typing a Tajik city that's also a region (Рудаки, Восе…)
            // matched all 32 cities and the list never narrowed (QA #62).
            keywords: [city.name, country.name],
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final query = _query.trim().toLowerCase();
    // Order matches so cities whose name starts with the query come first,
    // then alphabetically — typing a city name now surfaces it at the top
    // instead of leaving results in raw directory order (QA #62).
    final options = query.isEmpty
        ? _allOptions
        : (_allOptions.where((o) => o.matches(_query)).toList()
          ..sort((a, b) {
            final aStarts = a.title.toLowerCase().startsWith(query);
            final bStarts = b.title.toLowerCase().startsWith(query);
            if (aStarts != bStarts) return aStarts ? -1 : 1;
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }));

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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Закрыть'),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: HSText.headline,
                    ),
                  ),
                  const SizedBox(width: 72),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Город, район или страна',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: hs.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: hs.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: hs.stroke),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(option.selection),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: context.secondaryText,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(option.title, style: HSText.headline),
                                const SizedBox(height: 2),
                                Text(
                                  option.subtitle,
                                  style: HSText.subheadline.copyWith(
                                    color: context.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.secondaryText,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
