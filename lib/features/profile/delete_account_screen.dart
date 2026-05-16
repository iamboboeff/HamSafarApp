import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass_card.dart';
import 'widgets/profile_widgets.dart';

/// Ported from `DeleteAccountReason` in `ProfileViews.swift`.
enum DeleteAccountReason {
  notUseful('Сервис мне не подходит'),
  fewRides('Мало подходящих поездок'),
  technicalIssues('Технические проблемы'),
  privacy('Вопросы приватности'),
  other('Другая причина');

  const DeleteAccountReason(this.title);
  final String title;
}

/// Ported from `DeleteAccountFlowView` in `ProfileViews.swift`.
///
/// Account deletion needs the backend auth layer; here the confirmation just
/// reports that it will be available once auth is connected.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  DeleteAccountReason _reason = DeleteAccountReason.notUseful;

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: Text(
          'Причина: ${_reason.title}. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Удаление аккаунта станет доступно после '
            'подключения авторизации.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Удалить аккаунт')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AppBackdrop(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Почему вы хотите удалить аккаунт?',
                        style: HSText.headline,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Выберите причину. Это поможет нам понять, что стоит '
                        'улучшить в сервисе.',
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
                    for (
                      var i = 0;
                      i < DeleteAccountReason.values.length;
                      i++
                    ) ...[
                      GestureDetector(
                        onTap: () => setState(
                          () => _reason = DeleteAccountReason.values[i],
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                _reason == DeleteAccountReason.values[i]
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 22,
                                color: _reason == DeleteAccountReason.values[i]
                                    ? context.hs.primary
                                    : context.secondaryText,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DeleteAccountReason.values[i].title,
                                style: HSText.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < DeleteAccountReason.values.length - 1)
                        const SettingsDivider(),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                DestructiveOutlineButton(
                  label: 'Продолжить удаление',
                  onPressed: _confirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
