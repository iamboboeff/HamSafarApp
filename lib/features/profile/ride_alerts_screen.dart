import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ride_alert.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/glass_card.dart';
import 'widgets/profile_widgets.dart';

/// Management screen for the user's ride alerts ("оповещения о поездках").
/// Each row is a route the user subscribed to from the search screen; a push
/// is sent every time a new ride is published on that route, until the user
/// removes the alert here.
class RideAlertsScreen extends ConsumerWidget {
  const RideAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(rideAlertsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Оповещения о поездках')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(rideAlertsProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
              child: Column(
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Оповещения о поездках', style: HSText.headline),
                        const SizedBox(height: 10),
                        Text(
                          'Подпишитесь на маршрут на странице поиска, и мы '
                          'пришлём уведомление каждый раз, когда по нему '
                          'опубликуют новую поездку.',
                          style: HSText.subheadline.copyWith(
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (alerts.isEmpty)
                    const _EmptyState()
                  else
                    SettingsGroupCard(
                      children: [
                        for (var i = 0; i < alerts.length; i++) ...[
                          if (i > 0) const SettingsDivider(),
                          _AlertRow(alert: alerts[i]),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({required this.alert});

  final RideAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  hs.primary.withValues(alpha: 0.18),
                  hs.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 17,
              color: hs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${alert.fromCity} → ${alert.toCity}',
              style: HSText.bodyMedium,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: hs.danger),
            tooltip: 'Удалить',
            onPressed: () => _remove(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(rideAlertsProvider.notifier).remove(alert.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Оповещение «${alert.fromCity} → ${alert.toCity}» отключено',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось отключить оповещение')),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 54,
            color: context.secondaryText.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text('Пока нет оповещений', style: HSText.headline),
          const SizedBox(height: 8),
          Text(
            'Найдите маршрут на странице поиска и нажмите '
            '«Создать оповещение», чтобы получать уведомления о новых '
            'поездках по нему.',
            textAlign: TextAlign.center,
            style: HSText.subheadline.copyWith(color: context.secondaryText),
          ),
        ],
      ),
    );
  }
}
