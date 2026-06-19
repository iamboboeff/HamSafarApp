import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/net_status.dart';
import '../../../core/supabase/supabase_service.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/hs_route.dart';
import '../../auth/widgets/auth_field.dart';
import '../blocked_users_screen.dart';
import '../widgets/profile_widgets.dart';

/// Ported from `PrivacySettingsView` in `ProfileViews.swift`.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmNewPassword = TextEditingController();

  bool _isUpdatingPassword = false;
  String? _passwordStatusMessage;
  String? _passwordErrorMessage;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmNewPassword.dispose();
    super.dispose();
  }

  /// Ported from `PrivacySettingsView.updatePassword()` in `ProfileViews.swift`.
  /// Same validation rules and same two-call flow: re-authenticate with the
  /// current password, then call `updatePassword`.
  Future<void> _updatePassword() async {
    setState(() {
      _passwordStatusMessage = null;
      _passwordErrorMessage = null;
    });

    final email = ref.read(currentUserProvider).email.trim();

    if (email.isEmpty) {
      setState(() {
        _passwordErrorMessage = tr('Для смены пароля нужен email аккаунта.');
      });
      return;
    }
    if (_currentPassword.text.isEmpty) {
      setState(() {
        _passwordErrorMessage = tr('Введите текущий пароль.');
      });
      return;
    }
    if (_newPassword.text.length < 6) {
      setState(() {
        _passwordErrorMessage = tr('Пароль должен быть минимум 6 символов.');
      });
      return;
    }
    if (_newPassword.text != _confirmNewPassword.text) {
      setState(() {
        _passwordErrorMessage = tr('Пароли не совпадают.');
      });
      return;
    }

    setState(() => _isUpdatingPassword = true);

    final service = ref.read(supabaseServiceProvider);

    // Re-authenticate with the current password first. A failure here almost
    // always means the entered current password is wrong, so show a message
    // that says exactly that instead of the raw sign-in error (QA #94).
    try {
      await service.signInWithEmailPassword(
        email: email,
        password: _currentPassword.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingPassword = false;
        _passwordErrorMessage =
            isOfflineError(e) ? offlineMessage : tr('Неверный текущий пароль.');
      });
      return;
    }

    try {
      await service.updatePassword(_newPassword.text);
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmNewPassword.clear();
      setState(() {
        _isUpdatingPassword = false;
        _passwordStatusMessage = tr('Пароль обновлён.');
      });
    } on SupabaseServiceError catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingPassword = false;
        _passwordErrorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingPassword = false;
        _passwordErrorMessage = isOfflineError(e)
            ? offlineMessage
            : tr('Не удалось обновить пароль. Попробуйте ещё раз.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(privacySettingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Приватность'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            // Left/right safe-area insets for landscape notch / Island (QA #93).
            padding: EdgeInsets.fromLTRB(
              20 + MediaQuery.paddingOf(context).left,
              20,
              20 + MediaQuery.paddingOf(context).right,
              20,
            ),
            child: Column(
              children: [
                SettingsGroupCard(
                  children: [
                    ToggleRow(
                      title: tr('Публичный профиль'),
                      subtitle: tr(
                        'Водители и пассажиры смогут открыть ваш профиль',
                      ),
                      value: settings.allowPublicProfile,
                      onChanged: (v) => ref
                          .read(sessionProvider.notifier)
                          .setAllowPublicProfile(v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroupCard(
                  children: [
                    SettingsRow(
                      title: tr('Заблокированные пользователи'),
                      icon: Icons.block,
                      accent: context.hs.warm,
                      onTap: () => Navigator.of(context).push(
                        HSRoute<void>(
                          builder: (_) => const BlockedUsersScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroupCard(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Смена пароля'), style: HSText.headline),
                        const SizedBox(height: 14),
                        AuthField(
                          title: tr('Текущий пароль'),
                          controller: _currentPassword,
                          icon: Icons.lock_outline,
                          isSecure: true,
                        ),
                        const SizedBox(height: 12),
                        AuthField(
                          title: tr('Новый пароль'),
                          controller: _newPassword,
                          icon: Icons.lock_outline,
                          isSecure: true,
                        ),
                        const SizedBox(height: 12),
                        AuthField(
                          title: tr('Повторите новый пароль'),
                          controller: _confirmNewPassword,
                          icon: Icons.lock_reset,
                          isSecure: true,
                        ),
                        if (_passwordStatusMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _passwordStatusMessage!,
                            style: HSText.footnote.copyWith(
                              color: Colors.green.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                        if (_passwordErrorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _passwordErrorMessage!,
                            style: HSText.footnote.copyWith(
                              color: Colors.red.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        PrimaryFilledButton(
                          label: tr('Обновить пароль'),
                          isLoading: _isUpdatingPassword,
                          onPressed:
                              _isUpdatingPassword ? null : _updatePassword,
                        ),
                      ],
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
