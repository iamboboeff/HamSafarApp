import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/app_backdrop.dart';
import '../widgets/profile_widgets.dart';

/// Ported from `PrivacySettingsView` in `ProfileViews.swift`.
///
/// The password-change card depends on `SupabaseService` auth and is omitted
/// until the backend is ported.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Приватность')),
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
                    ToggleRow(
                      title: 'Публичный профиль',
                      subtitle:
                          'Водители и пассажиры смогут открыть ваш профиль',
                      value: settings.allowPublicProfile,
                      onChanged: (v) => ref
                          .read(sessionProvider.notifier)
                          .setAllowPublicProfile(v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.hs.secondarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.hs.stroke),
                  ),
                  child: Text(
                    'Смена пароля станет доступна после подключения '
                    'авторизации.',
                    style: HSText.subheadline.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
