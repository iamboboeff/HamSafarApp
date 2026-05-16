import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/shell/launch_splash.dart';
import 'features/shell/main_tab_scaffold.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// Ported from `HamSafarApp` in `HamSafarApp.swift`.
class HamSafarApp extends ConsumerWidget {
  const HamSafarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceSettingsProvider);
    return MaterialApp(
      title: 'HamSafar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appearance.theme.themeMode,
      // Adaptive system overlay (status bar + Android nav bar) — picks
      // dark icons on light theme, light icons on dark theme. Wrapped
      // here at the root so screens without an AppBar (home, profile,
      // chat list) get the correct look without per-screen wiring.
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final overlay = brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                brightness == Brightness.light
                    ? Brightness.dark
                    : Brightness.light,
          ),
          child: child!,
        );
      },
      home: const LaunchGate(child: MainTabScaffold()),
    );
  }
}
