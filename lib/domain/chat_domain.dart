import '../models/chat.dart';

/// Ported from `ChatListDomain` in `ChatDomain.swift`.
///
/// The Swift version also auto-archives threads tied to finished trips; that
/// depends on cross-referencing booked trips and is omitted here — threads use
/// their explicit [ChatThread.category].
abstract final class ChatListDomain {
  static List<ChatThread> filteredThreads({
    required List<ChatThread> threads,
    required String searchText,
    required ChatCategory category,
  }) {
    final base = threads.where((t) => t.effectiveCategory == category).toList();
    final query = searchText.trim().toLowerCase();
    if (query.isEmpty) return base;
    return base.where((t) {
      return t.name.toLowerCase().contains(query) ||
          t.preview.toLowerCase().contains(query) ||
          t.route.toLowerCase().contains(query);
    }).toList();
  }
}
