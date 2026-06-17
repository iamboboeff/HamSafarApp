import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/app_settings.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';
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
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Language ─────────────────────────────────────────────
                SettingsGroupCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: hs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.language,
                              size: 18,
                              color: hs.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text('Язык', style: HSText.subheadlineSemibold),
                          const Spacer(),
                          Text(
                            AppLanguage.russian.title,
                            style: HSText.subheadline.copyWith(
                              color: context.secondaryText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Theme header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Оформление',
                    style: HSText.captionSemibold.copyWith(
                      color: context.secondaryText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // ── Theme cards ──────────────────────────────────────────
                Row(
                  children: [
                    for (final t in AppThemePreference.values) ...[
                      if (t != AppThemePreference.values.first)
                        const SizedBox(width: 12),
                      Expanded(
                        child: _ThemeCard(
                          preference: t,
                          isSelected: appearance.theme == t,
                          onTap: () =>
                              notifier.update(appearance.copyWith(theme: t)),
                        ),
                      ),
                    ],
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

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.preference,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemePreference preference;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon => switch (preference) {
    AppThemePreference.system => Icons.brightness_auto,
    AppThemePreference.light  => Icons.light_mode_outlined,
    AppThemePreference.dark   => Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final accent = isSelected ? hs.primary : hs.secondarySurface;
    final iconColor = isSelected ? Colors.white : context.secondaryText;
    final labelColor = isSelected ? hs.primary : context.primaryText;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? hs.primary.withValues(alpha: 0.10)
              : hs.cardBackground,
          borderRadius: BorderRadius.circular(HSRadius.medium),
          border: Border.all(
            color: isSelected ? hs.primary.withValues(alpha: 0.5) : hs.stroke,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: hs.primary.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 20, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              preference.title,
              style: HSText.captionSemibold.copyWith(color: labelColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
