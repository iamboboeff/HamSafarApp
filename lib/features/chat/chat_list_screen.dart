import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/l10n.dart';
import '../../domain/chat_domain.dart';
import '../../models/chat.dart';
import '../../state/chat_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../widgets/app_backdrop.dart';
import 'archive_chats_screen.dart';
import 'chat_detail_screen.dart';
import 'widgets/chat_thread_list.dart';

/// Ported from `ChatRootView` in `ChatRootView.swift`.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openThread(ChatThread thread) {
    Navigator.of(context).push(
      HSRoute<void>(
        builder: (_) => ChatDetailScreen(threadId: thread.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final filtered = ChatListDomain.filteredThreads(
      threads: chatState.threads,
      searchText: _searchText,
      category: ChatCategory.active,
    );

    return BackdropScaffoldBody(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatListHeader(
                    title: tr('Сообщения'),
                    subtitle: tr('Чаты и важные события по поездкам'),
                    trailingIcon: Icons.archive_outlined,
                    onTrailingTap: () => Navigator.of(context).push(
                      HSRoute<void>(
                        builder: (_) => const ArchiveChatsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: HSSpacing.section),
                  ChatSearchField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchText = value),
                  ),
                  const SizedBox(height: HSSpacing.section),
                ],
              ),
            ),
            Expanded(
              child: chatState.isListLoading && chatState.threads.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(chatProvider.notifier).loadChats(),
                      child: filtered.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: EmptyChatStateContent(
                                    icon: Icons.forum_outlined,
                                    title: tr('Активных чатов пока нет'),
                                    subtitle: tr(
                                        'Новые диалоги с водителями и пассажирами появятся здесь.'),
                                  ),
                                ),
                              ],
                            )
                          : ChatThreadListView(
                              threads: filtered,
                              isArchiveList: false,
                              onSelect: _openThread,
                              onDelete: (t) => ref
                                  .read(chatProvider.notifier)
                                  .deleteThread(t.id),
                              onArchiveToggle: (t) => ref
                                  .read(chatProvider.notifier)
                                  .setArchived(t.id, true),
                              canModify: (t) => !ref
                                  .read(chatProvider.notifier)
                                  .isLockedByActiveTrip(t),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ported from `ChatListHeader` in `ChatSections.swift`.
class ChatListHeader extends StatelessWidget {
  const ChatListHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailingIcon,
    required this.onTrailingTap,
  });

  final String title;
  final String subtitle;
  final IconData trailingIcon;
  final VoidCallback onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HSText.largeTitle),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: HSText.subheadline.copyWith(
                  color: context.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onTrailingTap,
          child: Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hs.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: hs.stroke),
            ),
            child: Icon(trailingIcon, size: 18, color: hs.primary),
          ),
        ),
      ],
    );
  }
}

/// Ported from `ChatSearchField` in `ChatSections.swift`.
class ChatSearchField extends StatelessWidget {
  const ChatSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: tr('Поиск по чатам'),
        prefixIcon: const Icon(Icons.search, size: 20),
        filled: true,
        fillColor: hs.cardBackground,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Ported from `EmptyChatStateContent` in `ChatSupportViews.swift`.
class EmptyChatStateContent extends StatelessWidget {
  const EmptyChatStateContent({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: context.hs.primary),
          const SizedBox(height: 10),
          Text(title, style: HSText.headline),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: HSText.subheadline.copyWith(color: context.secondaryText),
          ),
        ],
      ),
    );
  }
}
