import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hamsafar/core/i18n/l10n.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_text.dart';
import '../../../widgets/glass_card.dart';
import '../widgets/profile_widgets.dart';

/// Ported from `NotificationSettingsView` in `ProfileViews.swift`.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Уведомления'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            // Left/right safe-area insets for landscape notch / Island (QA #93).
            padding: EdgeInsets.fromLTRB(
              8 + MediaQuery.paddingOf(context).left,
              20,
              8 + MediaQuery.paddingOf(context).right,
              20,
            ),
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Уведомления'), style: HSText.headline),
                      const SizedBox(height: 10),
                      Text(
                        tr(
                          'Выберите, какие события приложение будет показывать '
                          'в первую очередь.',
                        ),
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Master switch — lets the user turn off all notifications
                // (QA #34). The contextual permission prompt on create/booking
                // stays, but no-ops while this is off.
                SettingsGroupCard(
                  children: [
                    ToggleRow(
                      title: tr('Push-уведомления'),
                      subtitle: tr(
                        'Главный переключатель. Когда выключен, '
                        'приложение не присылает уведомления и не '
                        'запрашивает разрешение.',
                      ),
                      value: settings.pushEnabled,
                      onChanged: (v) async {
                        // Confirm before silencing notifications — turning this
                        // off stops chat + booking notifications entirely.
                        if (!v) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(tr('Отключить уведомления?')),
                              content: Text(
                                tr(
                                  'Сообщения от водителей и пассажиров и '
                                  'подтверждения брони больше не будут '
                                  'приходить.',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: Text(tr('Отмена')),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: Text(tr('Отключить')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                        }
                        notifier.update(settings.copyWith(pushEnabled: v));
                        ref.read(sessionProvider.notifier).setPushEnabled(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsGroupCard(
                  children: [
                    ToggleRow(
                      title: tr('Сообщения'),
                      subtitle: tr('Новые чаты и ответы в переписке'),
                      value: settings.messages,
                      onChanged: (v) =>
                          notifier.update(settings.copyWith(messages: v)),
                    ),
                    const SettingsDivider(),
                    ToggleRow(
                      title: tr('Подтверждение брони'),
                      subtitle: tr('Статусы заявок и подтверждённых мест'),
                      value: settings.bookingConfirmations,
                      onChanged: (v) => notifier.update(
                        settings.copyWith(bookingConfirmations: v),
                      ),
                    ),
                    const SettingsDivider(),
                    ToggleRow(
                      title: tr('Напоминания о поездке'),
                      subtitle: tr('Выезд, время встречи и изменения'),
                      value: settings.tripReminders,
                      onChanged: (v) =>
                          notifier.update(settings.copyWith(tripReminders: v)),
                    ),
                    const SettingsDivider(),
                    ToggleRow(
                      title: tr('Акции и новости'),
                      subtitle: tr('Подборки маршрутов и обновления сервиса'),
                      value: settings.promotions,
                      onChanged: (v) =>
                          notifier.update(settings.copyWith(promotions: v)),
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
