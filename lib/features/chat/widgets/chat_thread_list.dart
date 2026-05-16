import 'package:flutter/material.dart';

import '../../../models/chat.dart';
import '../../../theme/app_colors.dart';
import 'chat_thread_row.dart';

/// Ported from `ChatThreadListSection` in `ChatSections.swift` — a list of
/// chat threads with leading "archive toggle" and trailing "delete" swipe
/// actions.
class ChatThreadListView extends StatelessWidget {
  const ChatThreadListView({
    super.key,
    required this.threads,
    required this.isArchiveList,
    required this.onSelect,
    required this.onDelete,
    required this.onArchiveToggle,
  });

  final List<ChatThread> threads;

  /// When true the leading swipe label/icon reflects "unarchive".
  final bool isArchiveList;
  final ValueChanged<ChatThread> onSelect;
  final ValueChanged<ChatThread> onDelete;
  final ValueChanged<ChatThread> onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      itemCount: threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final thread = threads[index];
        return Dismissible(
          key: ValueKey(thread.id),
          background: _swipeBackground(
            context,
            alignment: Alignment.centerLeft,
            color: isArchiveList ? hs.mint : hs.primary,
            icon: isArchiveList ? Icons.unarchive : Icons.archive,
            label: isArchiveList ? 'Убрать из архива' : 'В архив',
          ),
          secondaryBackground: _swipeBackground(
            context,
            alignment: Alignment.centerRight,
            color: Colors.red,
            icon: Icons.delete,
            label: 'Удалить',
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              onArchiveToggle(thread);
              return false;
            }
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Удалить чат?'),
                content: const Text('Переписка будет удалена из списка чатов.'),
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
            return confirmed ?? false;
          },
          onDismissed: (_) => onDelete(thread),
          child: GestureDetector(
            onTap: () => onSelect(thread),
            behavior: HitTestBehavior.opaque,
            child: ChatThreadRow(thread: thread),
          ),
        );
      },
    );
  }

  Widget _swipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
