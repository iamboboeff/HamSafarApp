import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      // Transparent so every Scaffold (including the AppBar area) shows the
      // global backdrop painted in HamSafarApp.builder.
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      extensions: [hs],
      // Manrope mirrors SwiftUI's `Font.system(design: .rounded)` — soft
      // geometric letterforms, strong Cyrillic coverage. Bundled locally
      // (assets/fonts/Manrope.ttf) so it loads offline on first launch.
      fontFamily: 'Manrope',
      // iOS gets the native slide-from-right transition with the
      // interactive swipe-back gesture. Android/macOS/etc. keep the
      // platform default (Material zoom on Android).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    // Status-bar icons must stay readable on screens that have an AppBar (the
    // root AnnotatedRegion only covers AppBar-less screens) — dark icons on the
    // light theme, light icons on the dark theme (QA #18).
    final overlayStyle = (brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light)
        .copyWith(
      statusBarColor: Colors.transparent,
      statusBarBrightness:
          brightness == Brightness.light ? Brightness.light : Brightness.dark,
      statusBarIconBrightness:
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlayStyle,
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
