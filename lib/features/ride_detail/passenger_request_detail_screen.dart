import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/date_formatter.dart';
import '../../models/passenger_request.dart';
import '../../state/chat_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/common.dart';
import '../chat/chat_detail_screen.dart';
import '../profile/public_profile_screen.dart';
import 'widgets/ride_detail_sections.dart';

/// Ported from `PassengerRequestDetailView` in `PassengerRequestDetailView.swift`.
///
/// Reached from the "Пассажиры" tab of search results. Own-request management
/// (cancel) is omitted until the My Trips area is ported.
class PassengerRequestDetailScreen extends ConsumerWidget {
  const PassengerRequestDetailScreen({super.key, required this.request});

  final PassengerRequest request;

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
          const AppBackdrop(),
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
                          RideLocationRow(
                            title: request.fromCity,
                            subtitle: 'Пассажир ищет водителя',
                            accent: hs.passenger,
                            showsConnector: true,
                          ),
                          RideLocationRow(
                            title: request.toCity,
                            subtitle: 'Маршрут запроса',
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
                      MaterialPageRoute<void>(
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
                      MaterialPageRoute<void>(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
