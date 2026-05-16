import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/date_formatter.dart';
import '../../models/chat.dart';
import '../../models/user_profile.dart';
import 'supabase_chat_rows.dart';
import 'supabase_rows.dart' show BookingRow, RideRow;
import 'supabase_service.dart' show SupabaseServiceError;

class _CounterpartProfile {
  const _CounterpartProfile({required this.name, this.avatarBytes});
  final String name;
  final Uint8List? avatarBytes;
}

/// Ported from `SupabaseServiceChat.swift` — the chat backend layer: thread /
/// message reads, sends, read-state, presence, archive (hide), realtime sync,
/// attachment uploads, and the pending-booking banner.
class SupabaseChatService {
  SupabaseChatService(this._client);

  final SupabaseClient _client;

  static const int chatPageSize = 40;
  static const Duration _presenceFreshness = Duration(seconds: 18);
  static const Duration _typingFreshness = Duration(seconds: 6);
  static const String _attachmentsBucket = 'chat-attachments';

  RealtimeChannel? _chatRealtimeChannel;

  String get _requireUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw SupabaseServiceError('Пользователь не авторизован.');
    }
    return id;
  }

  // ---------------------------------------------------------------------------
  // Realtime (ported from startChatRealtimeSync / stopChatRealtimeSync)
  // ---------------------------------------------------------------------------

  /// Subscribes to chat-table changes. [onSync] is invoked with the affected
  /// thread id (or `null` when a full reload is needed).
  Future<void> startChatRealtimeSync(void Function(String? threadId) onSync) async {
    await stopChatRealtimeSync();
    if (_client.auth.currentUser == null) return;

    String? threadIdOf(PostgresChangePayload payload) {
      final record = payload.newRecord.isNotEmpty
          ? payload.newRecord
          : payload.oldRecord;
      return record['thread_id'] as String?;
    }

    final channel = _client.channel('public:chat-realtime');
    _chatRealtimeChannel = channel;

    // chat_threads / chat_participants → full reload (threadId: null).
    for (final table in ['chat_threads', 'chat_participants']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => onSync(null),
      );
    }
    // chat_user_states / chat_user_presence / chat_messages → per-thread refresh.
    for (final table in ['chat_user_states', 'chat_user_presence', 'chat_messages']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) => onSync(threadIdOf(payload)),
      );
    }

    channel.subscribe();
  }

  Future<void> stopChatRealtimeSync() async {
    final channel = _chatRealtimeChannel;
    _chatRealtimeChannel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  // ---------------------------------------------------------------------------
  // Reads (ported from fetchChats / fetchChat / fetchChatSummary)
  // ---------------------------------------------------------------------------

  /// Maps `profiles.id` → display name + avatar bytes. Mirrors
  /// `enrichedProfilesByID` for the only fields chat needs.
  Future<Map<String, _CounterpartProfile>> _fetchProfileNamesById() async {
    final rows =
        await _client.from('profiles').select('id,full_name,avatar_url');
    final map = <String, _CounterpartProfile>{};
    for (final raw in rows) {
      final id = raw['id'] as String?;
      if (id == null) continue;
      map[id] = _CounterpartProfile(
        name: (raw['full_name'] as String?) ?? 'Чат',
        avatarBytes:
            UserProfile.decodeAvatarUrl(raw['avatar_url'] as String?),
      );
    }
    return map;
  }

  /// Ported from `fetchChats`.
  Future<List<ChatThread>> fetchChats() async {
    final userId = _requireUserId;

    final threadRows = (await _client.from('chat_threads').select())
        .map(ChatThreadRow.new)
        .toList();
    final participantRows = (await _client.from('chat_participants').select())
        .map(ChatParticipantRow.new)
        .toList();
    final stateRows = (await _client
            .from('chat_user_states')
            .select()
            .eq('user_id', userId))
        .map(ChatUserStateRow.new)
        .toList();
    final messageRows = (await _client
            .from('chat_messages')
            .select('id,thread_id,sender_id,kind,created_at,body'))
        .map(ChatMessageRow.new)
        .toList();
    final profileNames = await _fetchProfileNamesById();

    final participantUserIds =
        participantRows.map((p) => p.userId).toSet().toList();
    final presenceRows = participantUserIds.isEmpty
        ? <ChatPresenceRow>[]
        : (await _client
                .from('chat_user_presence')
                .select()
                .inFilter('user_id', participantUserIds))
            .map(ChatPresenceRow.new)
            .toList();

    final participantsByThread = <String, List<ChatParticipantRow>>{};
    for (final p in participantRows) {
      participantsByThread.putIfAbsent(p.threadId, () => []).add(p);
    }
    final stateByThreadId = {for (final s in stateRows) s.threadId: s};
    final messagesByThreadId = <String, List<ChatMessageRow>>{};
    for (final m in messageRows) {
      messagesByThreadId.putIfAbsent(m.threadId, () => []).add(m);
    }

    final summaries = <_ChatSummary>[];
    for (final row in threadRows) {
      final threadParticipants = participantsByThread[row.id] ?? const [];
      if (!threadParticipants.any((p) => p.userId == userId)) continue;

      final counterpartId = threadParticipants
          .where((p) => p.userId != userId)
          .map((p) => p.userId)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);
      final threadMessages = messagesByThreadId[row.id] ?? const [];
      final latestMessage = threadMessages.isEmpty
          ? null
          : threadMessages
              .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
      final latestContent = latestMessage == null
          ? const ChatMessageContent(text: 'Новый диалог')
          : chatMessageContent(latestMessage);
      final previewMessage =
          latestContent.attachment?.previewText ?? latestContent.text;
      final latestDate = latestMessage?.createdAt ?? row.createdAt;
      final state = stateByThreadId[row.id];
      final counterpartPresence = counterpartId == null
          ? null
          : presence(
              userId: counterpartId,
              threadId: row.id,
              rows: presenceRows,
            );

      summaries.add(
        _ChatSummary(
          ChatThread(
            id: 'chat-${row.id}',
            backendId: row.id,
            rideId: row.rideId,
            passengerRequestId: row.passengerRequestId,
            participantBackendId: counterpartId,
            name: counterpartId == null
                ? 'Чат'
                : (profileNames[counterpartId]?.name ?? 'Чат'),
            route: normalizedChatRoute(row.title ?? 'Диалог'),
            preview: previewMessage,
            timeLabel: DateTextFormatter.time(latestDate),
            tripStatus: row.title ?? 'Диалог',
            tagline: _taglineFor(latestMessage?.kind),
            headerNote: 'Обсудите детали поездки, время и место встречи.',
            unreadCount: unreadCount(
              rows: threadMessages,
              threadId: row.id,
              currentUserId: userId,
              state: state,
            ),
            isOnline: counterpartPresence?.isOnline ?? false,
            isTyping: counterpartPresence?.isTyping ?? false,
            category: state?.isHidden == true
                ? ChatCategory.archive
                : ChatCategory.active,
            avatarBytes: counterpartId == null
                ? null
                : profileNames[counterpartId]?.avatarBytes,
            messages: const [],
          ),
          latestDate,
        ),
      );
    }

    return _deduplicatedChatSummaries(summaries);
  }

  /// Ported from `fetchChatSummary` — a single thread without its messages.
  Future<ChatThread?> fetchChatSummary(String threadId) async {
    final userId = _requireUserId;

    final threadRows = (await _client
            .from('chat_threads')
            .select()
            .eq('id', threadId))
        .map(ChatThreadRow.new)
        .toList();
    if (threadRows.isEmpty) return null;
    final row = threadRows.first;

    final participantRows = (await _client
            .from('chat_participants')
            .select()
            .eq('thread_id', threadId))
        .map(ChatParticipantRow.new)
        .toList();
    if (!participantRows.any((p) => p.userId == userId)) return null;

    final stateRows = (await _client
            .from('chat_user_states')
            .select()
            .eq('thread_id', threadId))
        .map(ChatUserStateRow.new)
        .toList();
    final messageRows = (await _client
            .from('chat_messages')
            .select('id,thread_id,sender_id,kind,created_at,body')
            .eq('thread_id', threadId))
        .map(ChatMessageRow.new)
        .toList();

    final counterpartId = participantRows
        .where((p) => p.userId != userId)
        .map((p) => p.userId)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final profileNames = await _fetchProfileNamesById();
    final presenceRows = counterpartId == null
        ? <ChatPresenceRow>[]
        : (await _client
                .from('chat_user_presence')
                .select()
                .eq('user_id', counterpartId))
            .map(ChatPresenceRow.new)
            .toList();

    final latestMessage = messageRows.isEmpty
        ? null
        : messageRows
            .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    final latestContent =
        latestMessage == null ? null : chatMessageContent(latestMessage);
    final latestDate = latestMessage?.createdAt ?? row.createdAt;
    final state = stateRows
        .where((s) => s.userId == userId)
        .cast<ChatUserStateRow?>()
        .firstWhere((_) => true, orElse: () => null);
    final counterpartPresence = counterpartId == null
        ? null
        : presence(userId: counterpartId, threadId: row.id, rows: presenceRows);

    return ChatThread(
      id: 'chat-${row.id}',
      backendId: row.id,
      rideId: row.rideId,
      passengerRequestId: row.passengerRequestId,
      participantBackendId: counterpartId,
      name: counterpartId == null
          ? 'Чат'
          : (profileNames[counterpartId]?.name ?? 'Чат'),
      route: normalizedChatRoute(row.title ?? 'Диалог'),
      preview: latestContent?.attachment?.previewText ??
          latestContent?.text ??
          'Новый диалог',
      timeLabel: DateTextFormatter.time(latestDate),
      tripStatus: row.title ?? 'Диалог',
      tagline: _taglineFor(latestMessage?.kind),
      headerNote: 'Обсудите детали поездки, время и место встречи.',
      unreadCount: unreadCount(
        rows: messageRows,
        threadId: row.id,
        currentUserId: userId,
        state: state,
      ),
      isOnline: counterpartPresence?.isOnline ?? false,
      isTyping: counterpartPresence?.isTyping ?? false,
      category:
          state?.isHidden == true ? ChatCategory.archive : ChatCategory.active,
      avatarBytes: counterpartId == null
          ? null
          : profileNames[counterpartId]?.avatarBytes,
      messages: const [],
    );
  }

  /// Ported from `fetchChat` — a single thread with its most recent page of
  /// messages (up to [chatPageSize]).
  Future<ChatThread?> fetchChat(String threadId) async {
    final userId = _requireUserId;

    final threadRows = (await _client
            .from('chat_threads')
            .select()
            .eq('id', threadId))
        .map(ChatThreadRow.new)
        .toList();
    if (threadRows.isEmpty) return null;
    final row = threadRows.first;

    final participantRows = (await _client
            .from('chat_participants')
            .select()
            .eq('thread_id', threadId))
        .map(ChatParticipantRow.new)
        .toList();
    if (!participantRows.any((p) => p.userId == userId)) return null;

    final recentDescending = (await _client
            .from('chat_messages')
            .select()
            .eq('thread_id', threadId)
            .order('created_at', ascending: false)
            .limit(chatPageSize))
        .map(ChatMessageRow.new)
        .toList();
    final messageRows = recentDescending.reversed.toList();

    final stateRows = (await _client
            .from('chat_user_states')
            .select()
            .eq('thread_id', threadId))
        .map(ChatUserStateRow.new)
        .toList();

    final counterpartId = participantRows
        .where((p) => p.userId != userId)
        .map((p) => p.userId)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final profileNames = await _fetchProfileNamesById();
    final presenceRows = counterpartId == null
        ? <ChatPresenceRow>[]
        : (await _client
                .from('chat_user_presence')
                .select()
                .eq('user_id', counterpartId))
            .map(ChatPresenceRow.new)
            .toList();

    final state = stateRows
        .where((s) => s.userId == userId)
        .cast<ChatUserStateRow?>()
        .firstWhere((_) => true, orElse: () => null);
    final counterpartLastReadAt = counterpartId == null
        ? null
        : stateRows
            .where((s) => s.userId == counterpartId)
            .map((s) => s.lastReadAt)
            .cast<DateTime?>()
            .firstWhere((_) => true, orElse: () => null);
    final counterpartPresence = counterpartId == null
        ? null
        : presence(userId: counterpartId, threadId: row.id, rows: presenceRows);

    final threadMessages = messageRows
        .map((m) => _mapMessage(m, userId, counterpartLastReadAt))
        .toList();
    final latestDate = messageRows.isEmpty
        ? row.createdAt
        : messageRows
            .map((m) => m.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);

    return ChatThread(
      id: 'chat-${row.id}',
      backendId: row.id,
      rideId: row.rideId,
      passengerRequestId: row.passengerRequestId,
      participantBackendId: counterpartId,
      name: counterpartId == null
          ? 'Чат'
          : (profileNames[counterpartId]?.name ?? 'Чат'),
      route: normalizedChatRoute(row.title ?? 'Диалог'),
      preview: threadMessages.isEmpty
          ? 'Новый диалог'
          : threadMessages.last.previewText,
      timeLabel: DateTextFormatter.time(latestDate),
      tripStatus: row.title ?? 'Диалог',
      tagline: _taglineFor(
        threadMessages.isEmpty ? null : threadMessages.last.kind.name,
      ),
      headerNote: 'Обсудите детали поездки, время и место встречи.',
      unreadCount: unreadCount(
        rows: messageRows,
        threadId: row.id,
        currentUserId: userId,
        state: state,
      ),
      isOnline: counterpartPresence?.isOnline ?? false,
      isTyping: counterpartPresence?.isTyping ?? false,
      category:
          state?.isHidden == true ? ChatCategory.archive : ChatCategory.active,
      avatarBytes: counterpartId == null
          ? null
          : profileNames[counterpartId]?.avatarBytes,
      messages: threadMessages,
    );
  }

  /// Ported from `fetchOlderChatMessages` — the page of messages immediately
  /// preceding [before], oldest-first.
  Future<List<ChatMessage>> fetchOlderChatMessages(
    String threadId,
    DateTime before, {
    int limit = 40,
  }) async {
    final userId = _requireUserId;

    final participantRows = (await _client
            .from('chat_participants')
            .select()
            .eq('thread_id', threadId))
        .map(ChatParticipantRow.new)
        .toList();
    final stateRows = (await _client
            .from('chat_user_states')
            .select()
            .eq('thread_id', threadId))
        .map(ChatUserStateRow.new)
        .toList();

    final counterpartId = participantRows
        .where((p) => p.userId != userId)
        .map((p) => p.userId)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    final counterpartLastReadAt = counterpartId == null
        ? null
        : stateRows
            .where((s) => s.userId == counterpartId)
            .map((s) => s.lastReadAt)
            .cast<DateTime?>()
            .firstWhere((_) => true, orElse: () => null);

    final olderDescending = (await _client
            .from('chat_messages')
            .select()
            .eq('thread_id', threadId)
            .lt('created_at', before.toUtc().toIso8601String())
            .order('created_at', ascending: false)
            .limit(limit))
        .map(ChatMessageRow.new)
        .toList();

    return olderDescending.reversed
        .map((m) => _mapMessage(m, userId, counterpartLastReadAt))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Writes (ported from ensureChatThread / sendChatMessage / ...)
  // ---------------------------------------------------------------------------

  /// Ported from `ensureChatThread` — find-or-create the thread between the
  /// current user and [participantId]; returns the backend thread id.
  Future<String> ensureChatThread({
    required String route,
    required String participantId,
    String? rideId,
    String? passengerRequestId,
    List<ChatMessage> initialMessages = const [],
  }) async {
    final userId = _requireUserId;
    if (participantId == userId) {
      throw SupabaseServiceError('Нельзя начать диалог с самим собой.');
    }
    final normalizedRoute = normalizedChatRoute(route);

    Future<String?> findExisting() async {
      final threadRows = (await _client.from('chat_threads').select())
          .map(ChatThreadRow.new)
          .toList();
      final participantRows =
          (await _client.from('chat_participants').select())
              .map(ChatParticipantRow.new)
              .toList();
      final byThread = <String, List<ChatParticipantRow>>{};
      for (final p in participantRows) {
        byThread.putIfAbsent(p.threadId, () => []).add(p);
      }
      for (final row in threadRows) {
        final tp = byThread[row.id] ?? const [];
        final hasCurrent = tp.any((p) => p.userId == userId);
        final hasParticipant = tp.any((p) => p.userId == participantId);
        if (!hasCurrent || !hasParticipant) continue;
        if (rideId != null) {
          if (row.rideId == rideId) return row.id;
          continue;
        }
        if (passengerRequestId != null) {
          if (row.passengerRequestId == passengerRequestId) return row.id;
          continue;
        }
        if (normalizedChatRoute(row.title ?? '') == normalizedRoute) {
          return row.id;
        }
      }
      return null;
    }

    // First pass, then a refresh pass to absorb a concurrent creation.
    for (var attempt = 0; attempt < 2; attempt++) {
      final existingId = await findExisting();
      if (existingId != null) {
        try {
          await upsertChatUserState(
            threadId: existingId,
            userId: userId,
            lastReadAt: null,
            isHidden: false,
          );
        } catch (_) {
          // Restoring the hidden flag is best-effort.
        }
        return existingId;
      }
    }

    final insertedThread = await _client
        .from('chat_threads')
        .insert({
          'ride_id': rideId,
          'passenger_request_id': passengerRequestId,
          'kind': 'ride',
          'title': normalizedRoute,
          'created_by': userId,
        })
        .select()
        .single();
    final newThreadId = insertedThread['id'] as String;

    await _client.from('chat_participants').insert([
      {'thread_id': newThreadId, 'user_id': userId},
      {'thread_id': newThreadId, 'user_id': participantId},
    ]);

    for (final message in initialMessages) {
      if (message.kind != ChatMessageKind.system) continue;
      await _client.from('chat_messages').insert({
        'thread_id': newThreadId,
        'sender_id': userId,
        'body': encodedChatMessageBody(message.text, message.attachment),
        'kind': message.kind.name,
      });
    }

    return newThreadId;
  }

  /// Ported from `sendChatMessage`.
  Future<ChatMessage> sendChatMessage({
    required String threadId,
    required String text,
    ChatMessageKind kind = ChatMessageKind.regular,
    ChatAttachment? attachment,
  }) async {
    final userId = _requireUserId;
    final inserted = ChatMessageRow(
      await _client
          .from('chat_messages')
          .insert({
            'thread_id': threadId,
            'sender_id': userId,
            'body': encodedChatMessageBody(text, attachment),
            'kind': kind.name,
          })
          .select()
          .single(),
    );
    return _mapMessage(inserted, userId, null,
        forcedStatus: ChatMessageDeliveryStatus.sent);
  }

  // ---------------------------------------------------------------------------
  // Attachments (ported from uploadChatAttachment + createSignedChatAttachmentURL)
  // ---------------------------------------------------------------------------

  /// Ported from `uploadChatAttachment`. Uploads [data] to the
  /// `chat-attachments` bucket under
  /// `{userId}/{threadId}/{uuid}-{sanitizedFileName}` and returns a
  /// [ChatAttachment] referencing the new storage path.
  Future<ChatAttachment> uploadChatAttachment({
    required String threadId,
    required String fileName,
    required Uint8List data,
    required String contentType,
    required ChatAttachmentKind kind,
  }) async {
    final userId = _requireUserId;
    final sanitized = _sanitizedStorageFileName(fileName);
    final unique =
        '${DateTime.now().microsecondsSinceEpoch}-${data.length}';
    final path = '$userId/$threadId/$unique-$sanitized';

    await _client.storage.from(_attachmentsBucket).uploadBinary(
          path,
          data,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return ChatAttachment(
      kind: kind,
      title: fileName,
      subtitle: _formattedAttachmentSize(data.length),
      storagePath: path,
      contentType: contentType,
      byteSize: data.length,
    );
  }

  /// Ported from `createSignedChatAttachmentURL`. Resolves an attachment's
  /// storage path to a short-lived signed URL the client can download.
  Future<String> createSignedChatAttachmentUrl(String path,
      {int expiresIn = 300}) async {
    return _client.storage
        .from(_attachmentsBucket)
        .createSignedUrl(path, expiresIn);
  }

  String _sanitizedStorageFileName(String fileName) {
    final sanitized = StringBuffer();
    for (final code in fileName.runes) {
      final ch = String.fromCharCode(code);
      final isAlphaNum = RegExp(r'[A-Za-z0-9]').hasMatch(ch);
      sanitized.write(isAlphaNum || ch == '.' || ch == '_' || ch == '-'
          ? ch
          : '-');
    }
    final result = sanitized.toString();
    return result.isEmpty ? 'attachment' : result;
  }

  String _formattedAttachmentSize(int bytes) {
    if (bytes <= 0) return 'Вложение из чата';
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} МБ';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(0)} КБ';
    }
    return '$bytes Б';
  }

  // ---------------------------------------------------------------------------
  // Pending booking context (ported from fetchPendingBookingContext)
  // ---------------------------------------------------------------------------

  /// Ported from `fetchPendingBookingContext`. Returns the most recent pending
  /// booking against one of the signed-in driver's rides where the booking
  /// passenger matches [participantId]. The route is used to disambiguate when
  /// multiple matching rides exist.
  Future<PendingChatBookingContext?> fetchPendingBookingContext({
    required String participantId,
    required String route,
  }) async {
    final userId = _requireUserId;
    final normalizedRoute = normalizedChatRoute(route);

    List<RideRow> rideRows;
    try {
      rideRows = (await _client
              .from('rides_with_availability')
              .select()
              .eq('driver_id', userId))
          .map((e) => RideRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }

    final rideIds = rideRows.map((r) => r.id).whereType<String>().toList();
    if (rideIds.isEmpty) return null;

    List<BookingRow> bookingRows;
    try {
      bookingRows = (await _client
              .from('bookings')
              .select()
              .eq('passenger_id', participantId)
              .eq('status', 'pending')
              .inFilter('ride_id', rideIds)
              .order('created_at', ascending: false))
          .map((e) => BookingRow(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }

    if (bookingRows.isEmpty) return null;
    final first = bookingRows.first;

    RideRow? matchedRide;
    for (final ride in rideRows) {
      if (ride.id == first.rideId &&
          normalizedChatRoute('${ride.fromCity} - ${ride.toCity}') ==
              normalizedRoute) {
        matchedRide = ride;
        break;
      }
    }
    matchedRide ??= rideRows.firstWhere(
      (ride) => ride.id == first.rideId,
      orElse: () => rideRows.first,
    );

    final rideId = matchedRide.id;
    if (rideId == null) return null;
    final preferred =
        bookingRows.firstWhere((b) => b.rideId == rideId, orElse: () => first);

    return PendingChatBookingContext(
      bookingId: preferred.id,
      rideId: preferred.rideId,
      seatsCount: preferred.seatsCount,
      departureAt: matchedRide.departureAt,
      route: '${matchedRide.fromCity} — ${matchedRide.toCity}',
    );
  }

  /// Ported from `ensureSystemChatMessage` — inserts the system message only if
  /// an identical one is not already present in the recent history.
  Future<ChatMessage?> ensureSystemChatMessage({
    required String threadId,
    required String text,
  }) async {
    final existing = (await _client
            .from('chat_messages')
            .select('id,thread_id,sender_id,kind,created_at,body')
            .eq('thread_id', threadId)
            .eq('kind', ChatMessageKind.system.name)
            .order('created_at', ascending: false)
            .limit(80))
        .map(ChatMessageRow.new)
        .toList();
    final alreadyExists =
        existing.any((row) => chatMessageContent(row).text == text);
    if (alreadyExists) return null;
    return sendChatMessage(
      threadId: threadId,
      text: text,
      kind: ChatMessageKind.system,
    );
  }

  /// Ported from `markChatRead` — sets `last_read_at` to now. (The Swift version
  /// also clears pending push jobs; push is not ported.)
  Future<void> markChatRead(String threadId) async {
    final userId = _requireUserId;
    final existing = await fetchChatUserState(threadId, userId);
    await upsertChatUserState(
      threadId: threadId,
      userId: userId,
      lastReadAt: DateTime.now(),
      isHidden: existing?.isHidden ?? false,
    );
  }

  /// Ported from `markChatUnread` — rewinds `last_read_at` to just before the
  /// latest incoming message.
  Future<void> markChatUnread(String threadId) async {
    final userId = _requireUserId;
    final existing = await fetchChatUserState(threadId, userId);

    final latestIncoming = (await _client
            .from('chat_messages')
            .select('created_at')
            .eq('thread_id', threadId)
            .neq('sender_id', userId)
            .order('created_at', ascending: false)
            .limit(1))
        .cast<Map<String, dynamic>>()
        .toList();

    DateTime? lastReadAt;
    if (latestIncoming.isNotEmpty) {
      final createdAt =
          DateTime.tryParse('${latestIncoming.first['created_at']}')?.toLocal();
      if (createdAt != null) {
        lastReadAt = createdAt.subtract(const Duration(seconds: 1));
      }
    }

    await upsertChatUserState(
      threadId: threadId,
      userId: userId,
      lastReadAt: lastReadAt,
      isHidden: existing?.isHidden ?? false,
    );
  }

  /// Ported from `hideChat`.
  Future<void> hideChat(String threadId) =>
      setChatHidden(threadId: threadId, isHidden: true);

  /// Ported from `setChatHidden`.
  Future<void> setChatHidden({
    required String threadId,
    required bool isHidden,
  }) async {
    final userId = _requireUserId;
    await upsertChatUserState(
      threadId: threadId,
      userId: userId,
      lastReadAt: DateTime.now(),
      isHidden: isHidden,
    );
  }

  /// Ported from `upsertChatUserState`.
  Future<void> upsertChatUserState({
    required String threadId,
    required String userId,
    required DateTime? lastReadAt,
    required bool isHidden,
  }) async {
    await _client.from('chat_user_states').upsert(
      {
        'thread_id': threadId,
        'user_id': userId,
        'last_read_at': lastReadAt?.toUtc().toIso8601String(),
        'is_hidden': isHidden,
      },
      onConflict: 'thread_id,user_id',
    );
  }

  /// Ported from `fetchChatUserState`.
  Future<ChatUserStateRow?> fetchChatUserState(
    String threadId,
    String userId,
  ) async {
    final rows = (await _client
            .from('chat_user_states')
            .select()
            .eq('thread_id', threadId)
            .eq('user_id', userId)
            .limit(1))
        .map(ChatUserStateRow.new)
        .toList();
    return rows.isEmpty ? null : rows.first;
  }

  /// Ported from `updateChatPresence`.
  Future<void> updateChatPresence({
    String? threadId,
    required bool isTyping,
  }) async {
    final userId = _requireUserId;
    await _client.from('chat_user_presence').upsert(
      {
        'user_id': userId,
        'thread_id': threadId,
        'is_online': true,
        'is_typing': isTyping,
      },
      onConflict: 'user_id',
    );
  }

  /// Ported from `clearChatPresence`.
  Future<void> clearChatPresence() =>
      updateChatPresence(threadId: null, isTyping: false);

  // ---------------------------------------------------------------------------
  // Helpers (ported from the free functions in SupabaseServiceChat.swift)
  // ---------------------------------------------------------------------------

  ChatMessage _mapMessage(
    ChatMessageRow row,
    String currentUserId,
    DateTime? counterpartLastReadAt, {
    ChatMessageDeliveryStatus? forcedStatus,
  }) {
    final content = chatMessageContent(row);
    return ChatMessage(
      backendId: row.id,
      text: content.text,
      isIncoming: row.senderId != currentUserId,
      sentAt: row.createdAt,
      timeLabel: DateTextFormatter.time(row.createdAt),
      dayLabel: chatDayLabel(row.createdAt),
      kind: _kindFrom(row.kind),
      attachment: content.attachment,
      deliveryStatus: forcedStatus ??
          deliveryStatus(
            row: row,
            currentUserId: currentUserId,
            counterpartLastReadAt: counterpartLastReadAt,
          ),
    );
  }

  /// Ported from `unreadCount`.
  int unreadCount({
    required List<ChatMessageRow> rows,
    required String threadId,
    required String currentUserId,
    required ChatUserStateRow? state,
  }) {
    final lastReadAt = state?.lastReadAt;
    return rows.where((row) {
      if (row.threadId != threadId) return false;
      if (row.kind != 'regular') return false;
      if (row.senderId == currentUserId) return false;
      if (lastReadAt != null) return row.createdAt.isAfter(lastReadAt);
      return true;
    }).length;
  }

  /// Ported from `chatMessageContent` — plain body for regular/system messages,
  /// JSON `{text, attachment}` payload for attachment messages.
  ChatMessageContent chatMessageContent(ChatMessageRow row) {
    if (row.kind != ChatMessageKind.attachment.name) {
      return ChatMessageContent(text: row.body);
    }
    try {
      final decoded = jsonDecode(row.body);
      if (decoded is Map<String, dynamic>) {
        final attachmentJson = decoded['attachment'];
        return ChatMessageContent(
          text: (decoded['text'] as String?) ?? row.body,
          attachment: attachmentJson is Map<String, dynamic>
              ? ChatAttachment.fromJson(attachmentJson)
              : null,
        );
      }
    } catch (_) {
      // Fall through to the plain-body fallback.
    }
    return ChatMessageContent(text: row.body);
  }

  /// Ported from `encodedChatMessageBody`.
  String encodedChatMessageBody(String text, ChatAttachment? attachment) {
    if (attachment == null) return text;
    return jsonEncode({'text': text, 'attachment': attachment.toJson()});
  }

  /// Ported from `presence` — applies the freshness windows.
  ChatPresenceState? presence({
    required String userId,
    required String threadId,
    required List<ChatPresenceRow> rows,
  }) {
    final row = rows
        .where((r) => r.userId == userId)
        .cast<ChatPresenceRow?>()
        .firstWhere((_) => true, orElse: () => null);
    if (row == null) return null;
    final age = DateTime.now().difference(row.updatedAt);
    final isFresh = age <= _presenceFreshness;
    final isTypingFresh = age <= _typingFreshness;
    return ChatPresenceState(
      isOnline: row.isOnline && isFresh,
      isTyping: row.isTyping && row.threadId == threadId && isTypingFresh,
    );
  }

  /// Ported from `deliveryStatus`.
  ChatMessageDeliveryStatus? deliveryStatus({
    required ChatMessageRow row,
    required String currentUserId,
    required DateTime? counterpartLastReadAt,
  }) {
    if (row.kind == 'system') return null;
    if (row.senderId != currentUserId) return null;
    if (counterpartLastReadAt != null &&
        !counterpartLastReadAt.isBefore(row.createdAt)) {
      return ChatMessageDeliveryStatus.read;
    }
    return ChatMessageDeliveryStatus.sent;
  }

  /// Ported from `deduplicatedChatSummaries`.
  List<ChatThread> _deduplicatedChatSummaries(List<_ChatSummary> summaries) {
    final unique = <String, _ChatSummary>{};
    for (final summary in summaries) {
      final thread = summary.thread;
      final key = thread.backendId ??
          '${thread.participantBackendId ?? thread.name}|'
              '${normalizedChatRoute(thread.route)}';
      final existing = unique[key];
      if (existing == null || summary.latestDate.isAfter(existing.latestDate)) {
        unique[key] = summary;
      }
    }
    final sorted = unique.values.toList()
      ..sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return sorted.map((s) => s.thread).toList();
  }

  ChatMessageKind _kindFrom(String raw) {
    return ChatMessageKind.values
        .where((k) => k.name == raw)
        .cast<ChatMessageKind?>()
        .firstWhere((_) => true, orElse: () => null) ??
        ChatMessageKind.regular;
  }

  String _taglineFor(String? messageKind) {
    if (messageKind == 'system') return 'Системное сообщение';
    if (messageKind == 'attachment') return 'Вложение';
    return 'Сообщения';
  }
}

/// Ported from `normalizedChatRoute` — used by both the service and the store.
String normalizedChatRoute(String route) {
  return route
      .replaceAll('→', '-')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('  ', ' ')
      .split('-')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .join(' - ');
}

/// Internal `(thread, latestDate)` pair used while building summaries.
class _ChatSummary {
  _ChatSummary(this.thread, this.latestDate);
  final ChatThread thread;
  final DateTime latestDate;
}
