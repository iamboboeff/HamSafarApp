import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the light/dark [ThemeData] for HamSafar.
///
/// The SwiftUI app leans on a small set of brand colors plus brightness-aware
/// surfaces; those live in [AppColors] (a [ThemeExtension]). This file wires
/// that palette into a Material 3 theme.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColors.light());
  static ThemeData dark() => _build(Brightness.dark, AppColors.dark());

  static ThemeData _build(Brightness brightness, AppColors hs) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: hs.primary,
      brightness: brightness,
      primary: hs.primary,
      surface: hs.background,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: hs.background,
      splashFactory: InkRipple.splashFactory,
      extensions: [hs],
      // Manrope mirrors SwiftUI's `Font.system(design: .rounded)` — soft
      // geometric letterforms, strong Cyrillic coverage. Bundled locally
      // (assets/fonts/Manrope.ttf) so it loads offline on first launch.
      fontFamily: 'Manrope',
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: hs.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: hs.cardBackground,
        indicatorColor: hs.primary.withValues(alpha: 0.14),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? hs.primary
                : colorScheme.onSurface.withValues(alpha: 0.6),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? hs.primary
                : colorScheme.onSurface.withValues(alpha: 0.6),
          );
        }),
      ),
      dividerTheme: DividerThemeData(color: hs.stroke, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: hs.background,
        surfaceTintColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: hs.primary),
    );
  }
}
