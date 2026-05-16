import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_settings.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/app_backdrop.dart';
import '../widgets/profile_widgets.dart';

/// Ported from `AppearanceSettingsView` in `ProfileViews.swift`.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    final appearance = ref.watch(appearanceSettingsProvider);
    final notifier = ref.read(appearanceSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Язык и тема')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                SettingsGroupCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Язык', style: HSText.headline),
                          const SizedBox(height: 14),
                          // Only Russian is available, matching the Swift app.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: hs.cardBackground,
                              borderRadius: BorderRadius.circular(
                                HSRadius.small,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  AppLanguage.russian.title,
                                  style: HSText.subheadlineSemibold,
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: context.secondaryText,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroupCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Оформление', style: HSText.headline),
                          const SizedBox(height: 14),
                          HSSegmentedControl<AppThemePreference>(
                            items: AppThemePreference.values,
                            selected: appearance.theme,
                            titleOf: (t) => t.title,
                            onSelect: (theme) => notifier.update(
                              appearance.copyWith(theme: theme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
