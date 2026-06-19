import 'package:flutter/material.dart';
import 'package:hamsafar/core/i18n/l10n.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/chat_domain.dart';
import '../../models/chat.dart';
import '../../state/chat_state.dart';
import 'chat_detail_screen.dart';
import 'chat_list_screen.dart';
import 'widgets/chat_thread_list.dart';

/// Ported from `ArchiveChatsView` in `ArchiveChatsView.swift`.
class ArchiveChatsScreen extends ConsumerWidget {
  const ArchiveChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(chatProvider).threads;
    final archived = ChatListDomain.filteredThreads(
      threads: threads,
      searchText: '',
      category: ChatCategory.archive,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(tr('Архив'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (archived.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EmptyChatStateContent(
                icon: Icons.archive_outlined,
                title: tr('Архив пуст'),
                subtitle: tr(
                  'Чаты, перенесённые в архив, будут храниться здесь.',
                ),
              ),
            )
          else
            ChatThreadListView(
              threads: archived,
              isArchiveList: true,
              onSelect: (thread) => Navigator.of(context).push(
                HSRoute<void>(
                  builder: (_) => ChatDetailScreen(threadId: thread.id),
                ),
              ),
              onDelete: (t) =>
                  ref.read(chatProvider.notifier).deleteThread(t.id),
              onArchiveToggle: (t) =>
                  ref.read(chatProvider.notifier).setArchived(t.id, false),
            ),
        ],
      ),
    );
  }
}
