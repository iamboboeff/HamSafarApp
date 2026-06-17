import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/activity_notification.dart';
import '../../models/app_tab.dart';
import '../../state/activity_state.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/glass_card.dart';

/// Ported from `ActivityNotificationsView` in `ChatSupportViews.swift`.
class ActivityNotificationsScreen extends ConsumerStatefulWidget {
  const ActivityNotificationsScreen({super.key});

  @override
  ConsumerState<ActivityNotificationsScreen> createState() =>
      _ActivityNotificationsScreenState();
}

class _ActivityNotificationsScreenState
    extends ConsumerState<ActivityNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activityProvider.notifier).markAllRead();
    });
  }

  /// Tapping a notification takes the user to the relevant area. The rows carry
  /// no deep-link payload yet, so chat-type notifications open the chat tab and
  /// everything else (trip/request/booking events) opens "Мои поездки".
  void _openNotification(ActivityNotification n) {
    final type = n.type.toLowerCase();
    final isChat = type.contains('chat') || type.contains('message');
    Navigator.of(context).maybePop();
    ref
        .read(selectedTabProvider.notifier)
        .select(isChat ? AppTab.inbox : AppTab.trips);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Уведомления')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (state.isLoading && state.notifications.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (state.notifications.isEmpty)
            // Pull-to-refresh works on the empty state too (QA #85).
            RefreshIndicator(
              onRefresh: () => ref.read(activityProvider.notifier).refresh(),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const _EmptyState(),
                  ),
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: () => ref.read(activityProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                itemCount: state.notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final n = state.notifications[index];
                  return _ActivityRow(
                    notification: n,
                    onTap: () => _openNotification(n),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 28, color: hs.primary),
            const SizedBox(height: 10),
            Text('Уведомлений пока нет', style: HSText.headline),
            const SizedBox(height: 6),
            Text(
              'Подтверждения, публикации и напоминания о поездках появятся '
              'здесь.',
              textAlign: TextAlign.center,
              style: HSText.subheadline.copyWith(color: context.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.notification, this.onTap});
  final ActivityNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hs.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(notification.type), color: hs.primary,
                size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: HSText.subheadlineSemibold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      notification.timeText,
                      style: HSText.caption
                          .copyWith(color: context.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: HSText.caption
                      .copyWith(color: context.secondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'booking_confirmed':
      case 'booking_accepted':
        return Icons.check_circle_outline;
      case 'booking_declined':
      case 'booking_cancelled':
        return Icons.cancel_outlined;
      case 'ride_published':
        return Icons.directions_car_filled;
      case 'trip_reminder':
        return Icons.alarm_outlined;
      case 'chat':
      case 'message':
        return Icons.chat_bubble_outline;
      case 'review':
      case 'rating':
        return Icons.star_outline;
      default:
        return Icons.notifications_none;
    }
  }
}
