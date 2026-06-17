import '../../models/chat.dart';

/// Row DTOs ported from the `DBChat*` structs in `SupabaseServiceRows.swift`.
/// They parse the raw Supabase JSON (column-name keyed) for the chat tables.

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// Ported from `DBChatThreadRow`.
class ChatThreadRow {
  ChatThreadRow(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String? get rideId => json['ride_id'] as String?;
  String? get passengerRequestId => json['passenger_request_id'] as String?;
  String get kind => (json['kind'] as String?) ?? 'ride';
  String? get title => json['title'] as String?;
  String? get createdBy => json['created_by'] as String?;
  DateTime get createdAt => _parseDate(json['created_at']) ?? DateTime.now();
}

/// Ported from `DBChatParticipantRow`.
class ChatParticipantRow {
  ChatParticipantRow(this.json);
  final Map<String, dynamic> json;

  String get threadId => json['thread_id'] as String;
  String get userId => json['user_id'] as String;
}

/// Ported from `DBChatMessageRow`.
class ChatMessageRow {
  ChatMessageRow(this.json);
  final Map<String, dynamic> json;

  String get id => json['id'] as String;
  String get threadId => json['thread_id'] as String;
  String? get senderId => json['sender_id'] as String?;
  String get body => (json['body'] as String?) ?? '';
  String get kind => (json['kind'] as String?) ?? 'regular';
  DateTime get createdAt => _parseDate(json['created_at']) ?? DateTime.now();
}

/// Ported from `DBChatUserStateRow`.
class ChatUserStateRow {
  ChatUserStateRow(this.json);
  final Map<String, dynamic> json;

  String get threadId => json['thread_id'] as String;
  String get userId => json['user_id'] as String;
  DateTime? get lastReadAt => _parseDate(json['last_read_at']);
  bool get isHidden => (json['is_hidden'] as bool?) ?? false;
  // True once the user deletes the chat — distinct from archiving (is_hidden),
  // so a deleted chat stays gone instead of reappearing in the archive (QA #68).
  bool get isDeleted => (json['is_deleted'] as bool?) ?? false;
  DateTime? get updatedAt => _parseDate(json['updated_at']);
}

/// Ported from `DBChatPresenceRow`.
class ChatPresenceRow {
  ChatPresenceRow(this.json);
  final Map<String, dynamic> json;

  String get userId => json['user_id'] as String;
  String? get threadId => json['thread_id'] as String?;
  bool get isOnline => (json['is_online'] as bool?) ?? false;
  bool get isTyping => (json['is_typing'] as bool?) ?? false;
  DateTime get updatedAt => _parseDate(json['updated_at']) ?? DateTime(1970);
}

/// Ported from the `ChatMessageContent` struct in `SupabaseServiceChat.swift`.
class ChatMessageContent {
  const ChatMessageContent({required this.text, this.attachment});
  final String text;
  final ChatAttachment? attachment;
}

/// Ported from the `ChatPresenceState` struct in `SupabaseServiceChat.swift`.
class ChatPresenceState {
  const ChatPresenceState({required this.isOnline, required this.isTyping});
  final bool isOnline;
  final bool isTyping;
}
