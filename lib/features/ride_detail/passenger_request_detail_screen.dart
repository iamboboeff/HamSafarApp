import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_formatter.dart';
import '../../models/passenger_request.dart';
import '../../state/app_state.dart';
import '../../state/chat_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_screen.dart';
import '../profile/public_profile_screen.dart';
import 'widgets/ride_detail_sections.dart';

/// Ported from `PassengerRequestDetailView` in `PassengerRequestDetailView.swift`.
///
/// Reached from the "Пассажиры" tab of search results (browsing other people's
/// requests) and from "Мои поездки" (the user's own request). When [isOwnRequest]
/// is true a "cancel request" action is shown (QA #61).
class PassengerRequestDetailScreen extends ConsumerWidget {
  const PassengerRequestDetailScreen({
    super.key,
    required this.request,
    this.isOwnRequest = false,
  });

  final PassengerRequest request;
  final bool isOwnRequest;

  Future<void> _cancelRequest(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить запрос?'),
        content: const Text(
          'Ваш запрос на поездку будет отменён и убран из списка.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Назад'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Отменить запрос'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(myPassengerRequestsProvider.notifier).cancel(request);
      messenger.showSnackBar(
        const SnackBar(content: Text('Запрос отменён.')),
      );
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось отменить запрос.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hs = context.hs;
    final reviewCount = request.passenger.completedTrips < 5
        ? 5
        : request.passenger.completedTrips;
    final arrival = request.departureDate.add(const Duration(hours: 4));
    final hasNote = request.note.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Запрос водителям')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateTextFormatter.weekdayDayMonth(request.departureDate),
                  style: HSText.title2,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateTextFormatter.time(request.departureDate),
                          style: HSText.headline,
                        ),
                        const SizedBox(height: 26),
                        Text(
                          DateTextFormatter.time(arrival),
                          style: HSText.headline,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          // A passenger request has no meeting-point address
                          // (unlike a driver ride), so the route shows just the
                          // cities — no filler subtitle.
                          RideLocationRow(
                            title: request.fromCity,
                            subtitle: '',
                            accent: hs.passenger,
                            showsConnector: true,
                          ),
                          RideLocationRow(
                            title: request.toCity,
                            subtitle: '',
                            accent: hs.warm,
                            showsConnector: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${request.seatsNeeded}', style: HSText.title2),
                        const SizedBox(height: 4),
                        Text(
                          request.seatsNeeded == 1
                              ? 'нужно место'
                              : 'нужно мест',
                          style: HSText.caption.copyWith(
                            color: context.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Пассажир', style: HSText.headline),
                const SizedBox(height: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final backendId = request.passenger.backendId;
                    if (backendId == null) return;
                    Navigator.of(context).push(
                      HSRoute<void>(
                        builder: (_) => UserPublicProfileScreen(
                          userId: backendId,
                          fallback: request.passenger,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      ProfileAvatar(
                        initials: request.passenger.initials,
                        avatarBytes: request.passenger.avatarBytes,
                        avatarUrl: request.passenger.avatarUrl,
                        size: 56,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(request.passenger.name, style: HSText.headline),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.star, size: 13, color: hs.warm),
                                const SizedBox(width: 6),
                                Text(
                                  '${request.passenger.ratingText} • '
                                  '$reviewCount отзывов',
                                  style: HSText.subheadline.copyWith(
                                    color: context.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const BleedDivider(),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    final threadId = ref
                        .read(chatProvider.notifier)
                        .openChatForRequest(request);
                    Navigator.of(context).push(
                      HSRoute<void>(
                        builder: (_) => ChatDetailScreen(threadId: threadId),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: hs.stroke),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: hs.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Напишите пассажиру, чтобы обсудить детали',
                            style: HSText.subheadlineSemibold.copyWith(
                              color: hs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (hasNote) ...[
                  const SizedBox(height: 18),
                  RideDetailSurfaceSection(
                    title: 'Комментарий',
                    child: Text(
                      request.note,
                      style: HSText.subheadline.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ),
                ],
                // Only an active (future, not cancelled) request can be
                // cancelled — an expired one auto-cancels, so no button.
                if (isOwnRequest &&
                    !request.isCompleted &&
                    !request.isCancelled) ...[
                  const SizedBox(height: 24),
                  PrimaryFilledButton(
                    label: 'Отменить запрос',
                    accent: Colors.red,
                    onPressed: () => _cancelRequest(context, ref),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
