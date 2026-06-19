import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
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
      appBar: AppBar(title: Text(tr('Язык и тема'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            // Left/right safe-area insets for landscape notch / Island (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Language ─────────────────────────────────────────────
                SettingsGroupCard(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showLanguagePicker(
                        context,
                        appearance,
                        notifier,
                      ),
                      child: Padding(
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
                            Text(tr('Язык'), style: HSText.subheadlineSemibold),
                            const Spacer(),
                            Text(
                              appearance.language.title,
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
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Theme header ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    tr('Оформление'),
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

  /// Bottom sheet listing the available languages (each shown in its own native
  /// name). Picking one updates the appearance setting, which re-runs the app
  /// build and re-renders the whole tree in the chosen language.
  void _showLanguagePicker(
    BuildContext context,
    AppearanceSettings appearance,
    AppearanceSettingsNotifier notifier,
  ) {
    final hs = context.hs;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: hs.cardBackground,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(tr('Выберите язык'), style: HSText.headline),
              ),
              for (final lang in AppLanguage.values)
                ListTile(
                  title: Text(
                    lang.title,
                    style: HSText.subheadlineSemibold,
                  ),
                  trailing: appearance.language == lang
                      ? Icon(Icons.check, color: hs.primary)
                      : null,
                  onTap: () {
                    if (appearance.language != lang) {
                      notifier.update(appearance.copyWith(language: lang));
                    }
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
              tr(preference.title),
              style: HSText.captionSemibold.copyWith(color: labelColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
