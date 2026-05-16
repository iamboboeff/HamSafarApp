import 'package:flutter/material.dart';
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
      home: const LaunchGate(child: MainTabScaffold()),
    );
  }
}
