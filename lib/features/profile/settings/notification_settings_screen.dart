import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('Уведомления')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Уведомления', style: HSText.headline),
                      const SizedBox(height: 10),
                      Text(
                        'Выберите, какие события приложение будет показывать '
                        'в первую очередь.',
                        style: HSText.subheadline.copyWith(
                          color: context.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SettingsGroupCard(
                  children: [
                    ToggleRow(
                      title: 'Сообщения',
                      subtitle: 'Новые чаты и ответы в переписке',
                      value: settings.messages,
                      onChanged: (v) =>
                          notifier.update(settings.copyWith(messages: v)),
                    ),
                    const SettingsDivider(),
                    ToggleRow(
                      title: 'Подтверждение брони',
                      subtitle: 'Статусы заявок и подтверждённых мест',
                      value: settings.bookingConfirmations,
                      onChanged: (v) => notifier.update(
                        settings.copyWith(bookingConfirmations: v),
                      ),
                    ),
                    const SettingsDivider(),
                    ToggleRow(
                      title: 'Напоминания о поездке',
                      subtitle: 'Выезд, время встречи и изменения',
                      value: settings.tripReminders,
                      onChanged: (v) =>
                          notifier.update(settings.copyWith(tripReminders: v)),
                    ),
                    const SettingsDivider(),
                    ToggleRow(
                      title: 'Акции и новости',
                      subtitle: 'Подборки маршрутов и обновления сервиса',
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
