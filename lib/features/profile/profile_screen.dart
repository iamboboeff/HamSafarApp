import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/l10n.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/buttons.dart';
import '../auth/auth_screen.dart';
import 'car_settings_screen.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
import 'info_screens.dart';
import 'ride_alerts_screen.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/privacy_settings_screen.dart';
import 'widgets/profile_widgets.dart';

/// Ported from `ProfileView` in `ProfileViews.swift`.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(HSRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    final profile = ref.watch(currentUserProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return BackdropScaffoldBody(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Профиль'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              if (isAuthenticated) ...[
                GestureDetector(
                  onTap: () => _push(context, const EditProfileScreen()),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Column(
                        children: [
                          ProfileAvatarView(
                            initials: profile.initials,
                            avatarBytes: profile.avatarBytes,
                            avatarUrl: profile.avatarUrl,
                            size: 88,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SettingsGroupCard(
                  children: [
                    SettingsRow(
                      title: tr('Редактировать профиль'),
                      icon: Icons.badge_outlined,
                      accent: hs.primary,
                      onTap: () => _push(context, const EditProfileScreen()),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: tr('Автомобиль'),
                      icon: Icons.directions_car_outlined,
                      accent: hs.warm,
                      onTap: () => _push(context, const CarSettingsScreen()),
                    ),
                    const SettingsDivider(),
                    SettingsRow(
                      title: tr('Оповещения о поездках'),
                      icon: Icons.notifications_active_outlined,
                      accent: hs.passenger,
                      onTap: () => _push(context, const RideAlertsScreen()),
                    ),
                  ],
                ),
              ] else
                GuestProfileHeaderCard(
                  onTap: () => Navigator.of(context).push(
                    HSRoute<void>(
                      builder: (_) => const AuthScreen(),
                      fullscreenDialog: true,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SettingsGroupCard(
                children: [
                  SettingsRow(
                    title: tr('Уведомления'),
                    icon: Icons.notifications_none,
                    accent: hs.passenger,
                    onTap: () =>
                        _push(context, const NotificationSettingsScreen()),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    title: tr('Язык и тема'),
                    icon: Icons.language,
                    accent: hs.mint,
                    onTap: () =>
                        _push(context, const AppearanceSettingsScreen()),
                  ),
                  // Privacy & security manage the signed-in account (password,
                  // visibility) — hide it from guests (QA #17).
                  if (isAuthenticated) ...[
                    const SettingsDivider(),
                    SettingsRow(
                      title: tr('Приватность и безопасность'),
                      icon: Icons.lock_outline,
                      accent: hs.warm,
                      onTap: () =>
                          _push(context, const PrivacySettingsScreen()),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              SettingsGroupCard(
                children: [
                  SettingsRow(
                    title: tr('Пассажирам'),
                    icon: Icons.people_outline,
                    accent: hs.passenger,
                    onTap: () =>
                        _push(context, HelpGuideScreen.passengers(context)),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    title: tr('Водителям'),
                    icon: Icons.airline_seat_recline_normal,
                    accent: hs.primary,
                    onTap: () =>
                        _push(context, HelpGuideScreen.drivers(context)),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    title: tr('Написать в поддержку'),
                    icon: Icons.support_agent,
                    accent: hs.warm,
                    onTap: () => _push(
                      context,
                      FeedbackFormScreen(
                        appBarTitle: tr('Поддержка'),
                        cardTitle: tr('Свяжитесь с поддержкой'),
                        cardSubtitle: tr(
                          'Опишите проблему, и мы отправим обращение в '
                          'поддержку.',
                        ),
                        fieldHint:
                            tr('Опишите проблему, чтобы мы быстрее помогли.'),
                        submitLabel: tr('Отправить в поддержку'),
                        successTitle: tr('Обращение отправлено'),
                        successMessage: tr(
                          'Мы получили ваше обращение. Ответ придёт на '
                          'вашу почту.',
                        ),
                        kind: FeedbackKind.support,
                        topics: const [
                          'Бронирование',
                          'Платёж',
                          'Чат',
                          'Профиль',
                          'Другое',
                        ],
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    title: tr('Предложить идею'),
                    icon: Icons.lightbulb_outline,
                    accent: hs.mint,
                    onTap: () => _push(
                      context,
                      FeedbackFormScreen(
                        appBarTitle: tr('Предложить идею'),
                        cardTitle: tr('Поделитесь идеей'),
                        cardSubtitle: tr(
                          'Ваши предложения помогают улучшать поиск, '
                          'публикацию поездок и общение.',
                        ),
                        fieldHint: tr(
                          'Опишите идею: что улучшить и как это должно '
                          'работать.',
                        ),
                        submitLabel: tr('Отправить идею'),
                        successTitle: tr('Спасибо'),
                        successMessage:
                            tr('Идея отправлена продуктовой команде.'),
                        kind: FeedbackKind.idea,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SettingsGroupCard(
                children: [
                  SettingsRow(
                    title: tr('Пользовательское соглашение'),
                    icon: Icons.description_outlined,
                    accent: hs.purple,
                    onTap: () => _push(context, LegalDocumentScreen.terms()),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    title: tr('Политика конфиденциальности'),
                    icon: Icons.shield_outlined,
                    accent: hs.warm,
                    onTap: () => _push(context, LegalDocumentScreen.privacy()),
                  ),
                  const SettingsDivider(),
                  SettingsRow(
                    title: tr('Контакты'),
                    icon: Icons.phone_outlined,
                    accent: hs.primary,
                    onTap: () => _push(context, const ContactsScreen()),
                  ),
                ],
              ),
              if (isAuthenticated) ...[
                const SizedBox(height: 18),
                DestructiveOutlineButton(
                  label: tr('Удалить аккаунт'),
                  onPressed: () => _push(context, const DeleteAccountScreen()),
                ),
                const SizedBox(height: 12),
                DestructiveOutlineButton(
                  label: tr('Выйти из профиля'),
                  onPressed: () => _confirmLogout(context, ref),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Выйти из профиля?')),
        content: Text(tr('Вы сможете войти снова в любой момент.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Выйти')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(sessionProvider.notifier).signOut();
    }
  }
}
