import 'dart:typed_data';

import '../domain/date_formatter.dart';

/// Ported from the chat model types in `Models.swift`.

enum ChatMessageKind { regular, system, attachment }

enum ChatMessageDeliveryStatus { sent, read }

enum ChatAttachmentKind { photo, file }

enum ChatCategory { active, archive }

class ChatAttachment {
  const ChatAttachment({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.storagePath,
    this.publicUrl,
    this.contentType,
    this.byteSize,
  });

  final ChatAttachmentKind kind;
  final String title;
  final String subtitle;
  final String? storagePath;
  final String? publicUrl;
  final String? contentType;
  final int? byteSize;

  String get iconName => kind == ChatAttachmentKind.photo ? 'photo' : 'doc';

  String get previewText =>
      kind == ChatAttachmentKind.photo ? 'Фото: $title' : 'Файл: $title';

  /// Mirrors the `ChatAttachment` `Codable` keys used by `DBChatAttachmentPayload`.
  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      kind: json['kind'] == 'photo'
          ? ChatAttachmentKind.photo
          : ChatAttachmentKind.file,
      title: (json['title'] as String?) ?? 'Вложение',
      subtitle: (json['subtitle'] as String?) ?? '',
      storagePath: json['storagePath'] as String?,
      publicUrl: json['publicURL'] as String?,
      contentType: json['contentType'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind == ChatAttachmentKind.photo ? 'photo' : 'file',
      'title': title,
      'subtitle': subtitle,
      'storagePath': storagePath,
      'publicURL': publicUrl,
      'contentType': contentType,
      'byteSize': byteSize,
    };
  }

  bool sameAs(ChatAttachment? other) {
    if (other == null) return false;
    return kind == other.kind &&
        title == other.title &&
        subtitle == other.subtitle &&
        storagePath == other.storagePath;
  }
}

/// Ported from `ChatMessage` in `Models.swift`.
class ChatMessage {
  ChatMessage({
    String? id,
    this.backendId,
    required this.text,
    required this.isIncoming,
    DateTime? sentAt,
    required this.timeLabel,
    required this.dayLabel,
    this.kind = ChatMessageKind.regular,
    this.attachment,
    this.deliveryStatus,
  }) : id = id ?? 'msg-${DateTime.now().microsecondsSinceEpoch}',
       sentAt = sentAt ?? DateTime.now();

  final String id;
  final String? backendId;
  final String text;
  final bool isIncoming;
  final DateTime sentAt;
  final String timeLabel;
  final String dayLabel;
  final ChatMessageKind kind;
  final ChatAttachment? attachment;
  final ChatMessageDeliveryStatus? deliveryStatus;

  String get previewText => attachment?.previewText ?? text;

  /// Returns a copy with the given fields replaced. Used by the chat store's
  /// merge logic, which adopts an existing message's local [id].
  ChatMessage copyWith({String? id}) {
    final copy = ChatMessage(
      id: id ?? this.id,
      backendId: backendId,
      text: text,
      isIncoming: isIncoming,
      sentAt: sentAt,
      timeLabel: timeLabel,
      dayLabel: dayLabel,
      kind: kind,
      attachment: attachment,
      deliveryStatus: deliveryStatus,
    );
    return copy;
  }
}

/// Ported from `ChatMessageGroup` in `Models.swift`.
class ChatMessageGroup {
  const ChatMessageGroup({required this.title, required this.messages});
  final String title;
  final List<ChatMessage> messages;
}

/// Ported from `ChatThread` in `Models.swift`.
class ChatThread {
  ChatThread({
    required this.id,
    this.backendId,
    this.rideId,
    this.passengerRequestId,
    this.participantBackendId,
    required this.name,
    required this.route,
    required this.preview,
    required this.timeLabel,
    this.tripStatus = '',
    this.tagline = '',
    this.headerNote = '',
    this.unreadCount = 0,
    this.isOnline = false,
    this.isTyping = false,
    this.category = ChatCategory.active,
    this.relatedDate,
    this.avatarBytes,
    this.avatarUrl,
    required this.messages,
  });

  final String id;
  final String? backendId;
  final String? rideId;
  final String? passengerRequestId;
  final String? participantBackendId;
  final String name;
  final String route;
  String preview;
  String timeLabel;
  final String tripStatus;
  String tagline;
  final String headerNote;
  int unreadCount;
  final bool isOnline;
  bool isTyping;
  ChatCategory category;
  final DateTime? relatedDate;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  List<ChatMessage> messages;

  String get initials => name
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0])
      .join();

  bool get hasStartedConversation => messages.any(
    (m) =>
        m.kind == ChatMessageKind.regular ||
        m.kind == ChatMessageKind.attachment,
  );

  ChatCategory get effectiveCategory => category;

  DateTime get latestActivityDate => messages.isNotEmpty
      ? messages.last.sentAt
      : (relatedDate ?? DateTime(1970));

  /// Returns a copy with the given fields replaced. The chat store's merge
  /// logic uses this to adopt an existing thread's local [id] while taking the
  /// rest of a freshly-fetched thread.
  ChatThread copyWith({
    String? id,
    String? backendId,
    int? unreadCount,
    ChatCategory? category,
    List<ChatMessage>? messages,
    String? preview,
    String? timeLabel,
    String? tagline,
    bool? isTyping,
  }) {
    return ChatThread(
      id: id ?? this.id,
      backendId: backendId ?? this.backendId,
      rideId: rideId,
      passengerRequestId: passengerRequestId,
      participantBackendId: participantBackendId,
      name: name,
      route: route,
      preview: preview ?? this.preview,
      timeLabel: timeLabel ?? this.timeLabel,
      tripStatus: tripStatus,
      tagline: tagline ?? this.tagline,
      headerNote: headerNote,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline,
      isTyping: isTyping ?? this.isTyping,
      category: category ?? this.category,
      relatedDate: relatedDate,
      avatarBytes: avatarBytes,
      avatarUrl: avatarUrl,
      messages: messages ?? this.messages,
    );
  }

  /// Appends a system message if an identical one is not already present.
  /// Returns whether a message was appended.
  bool appendSystemMessageIfNeeded(
    String text, {
    required String timeLabel,
    required String dayLabel,
  }) {
    final exists = messages.any(
      (m) => m.kind == ChatMessageKind.system && m.text == text,
    );
    if (exists) return false;
    messages = [
      ...messages,
      ChatMessage(
        text: text,
        isIncoming: false,
        timeLabel: timeLabel,
        dayLabel: dayLabel,
        kind: ChatMessageKind.system,
      ),
    ];
    return true;
  }
}

/// Ported from `ReviewPromptContext` in `AppPreferencesDomain.swift` — the
/// "leave a review" banner shown to a passenger after a completed driver-led
/// trip, while the review window (7 days) is still open.
class ReviewPromptContext {
  const ReviewPromptContext({
    required this.rideId,
    required this.revieweeId,
    required this.targetName,
    required this.routeText,
  });

  final String rideId;
  final String revieweeId;
  final String targetName;
  final String routeText;
}

/// Ported from `PendingChatBookingContext` in `SupabaseServiceTypes.swift` —
/// the booking that the chat partner currently has pending against one of the
/// signed-in driver's rides, surfaced as an accept/decline banner above the
/// composer.
class PendingChatBookingContext {
  const PendingChatBookingContext({
    required this.bookingId,
    required this.rideId,
    required this.seatsCount,
    required this.departureAt,
    required this.route,
  });

  final String bookingId;
  final String rideId;
  final int seatsCount;
  final DateTime departureAt;
  final String route;
}

/// Shared day-label helper for chat (`Сегодня` / `Вчера` / `5 мая`).
String chatDayLabel(DateTime date) {
  if (DateUtilsX.isToday(date)) return 'Сегодня';
  if (DateUtilsX.isYesterday(date)) return 'Вчера';
  return DateTextFormatter.dayMonthShort(date);
}
