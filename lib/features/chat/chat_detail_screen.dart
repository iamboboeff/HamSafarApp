import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/hs_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/l10n.dart';
import '../../core/preferences/preferences_store.dart';
import '../../domain/date_formatter.dart';
import '../../models/chat.dart';
import '../../models/user_profile.dart';
import '../../state/app_state.dart';
import '../../state/chat_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../profile/public_profile_screen.dart';
import 'widgets/chat_composer_bar.dart';
import 'widgets/message_bubble.dart';

/// Ported from `ChatDetailView` in `ChatDetailView.swift`.
///
/// The Swift version layers in Supabase realtime, presence/typing, attachment
/// uploads, message pagination and review prompts; the Flutter port keeps the
/// local conversation view — grouped messages, the composer, and the header.
class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingOlder = false;
  // True while the thread's messages are being fetched, so we can show a
  // spinner instead of a blank screen for the 2-3s it takes to load.
  bool _loadingThread = true;

  // --- Telegram-style scroll + unread divider ---
  // Whether the user is near the bottom; new messages auto-scroll only then, so
  // we never yank them down while they read history.
  bool _atBottom = true;
  int _lastMsgCount = 0;
  // Unread count captured BEFORE markRead, so we can place the "new messages"
  // divider above the first unread message and keep it stable while viewing.
  int _unreadAtOpen = 0;
  String? _firstUnreadId;
  bool _initialScrollDone = false;
  final GlobalKey _unreadDividerKey = GlobalKey();

  // Presence: heartbeat so the other person sees "в сети", and a debounced
  // typing flag for "печатает...".
  Timer? _presenceTimer;
  Timer? _typingClear;
  bool _typingPublished = false;

  /// Captured in [initState] so [dispose] can clear the active thread without
  /// touching `ref` — Riverpod forbids using `ref` once the element is
  /// unmounted.
  late final ChatNotifier _notifier;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(chatProvider.notifier);
    _notifier = notifier;
    notifier.setActiveThread(widget.threadId);
    // Capture unread BEFORE markRead so we can show the "new messages" divider.
    _unreadAtOpen = notifier.threadById(widget.threadId)?.unreadCount ?? 0;
    final draft = notifier.consumePendingDraft(widget.threadId);
    if (draft != null) _composer.text = draft;
    _scrollController.addListener(_onScroll);
    // Presence: mark online now + heartbeat (the row goes stale after ~18s, so
    // refresh under that), and publish typing while composing.
    notifier.updatePresence(widget.threadId);
    _presenceTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _notifier.updatePresence(widget.threadId);
    });
    _composer.addListener(_onComposerTyping);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      notifier.markRead(widget.threadId);
      try {
        await notifier.loadThread(widget.threadId);
      } finally {
        if (mounted) {
          _resolveUnreadDivider();
          setState(() => _loadingThread = false);
        }
      }
      if (!mounted) return;
      // After the list (with any unread divider) is laid out, position it at
      // the first unread message like Telegram — otherwise at the bottom.
      WidgetsBinding.instance.addPostFrameCallback((_) => _initialScroll());
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _typingClear?.cancel();
    _notifier.clearPresence();
    _notifier.clearActiveThread();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerTyping() {
    final typing = _composer.text.trim().isNotEmpty;
    if (typing) {
      if (!_typingPublished) {
        _typingPublished = true;
        _notifier.updatePresence(widget.threadId, typing: true);
      }
      _typingClear?.cancel();
      _typingClear = Timer(const Duration(seconds: 4), _stopTyping);
    } else if (_typingPublished) {
      _stopTyping();
    }
  }

  void _stopTyping() {
    _typingClear?.cancel();
    if (!_typingPublished) return;
    _typingPublished = false;
    _notifier.updatePresence(widget.threadId, typing: false);
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
    _atBottom = true;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    _atBottom = pos.pixels >= pos.maxScrollExtent - 120;
    // Load the preceding page when the user scrolls near the top, preserving
    // the visible position so the list does not jump.
    if (!_loadingOlder && pos.pixels <= 80) {
      _loadOlderMessages();
    }
  }

  /// Picks the message the "Новые сообщения" divider sits above — the first of
  /// the last [_unreadAtOpen] incoming messages.
  void _resolveUnreadDivider() {
    if (_unreadAtOpen <= 0) return;
    final msgs = _notifier.threadById(widget.threadId)?.messages ?? const [];
    var seen = 0;
    for (var i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].isIncoming) {
        seen++;
        if (seen == _unreadAtOpen) {
          _firstUnreadId = msgs[i].id;
          return;
        }
      }
    }
  }

  /// On open, scroll to the unread divider (Telegram-style) if there is one,
  /// otherwise jump straight to the latest message.
  void _initialScroll() {
    final ctx = _unreadDividerKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.12,
        duration: const Duration(milliseconds: 220),
      );
    } else {
      _scrollToBottom(animate: false);
    }
    _initialScrollDone = true;
  }

  Future<void> _loadOlderMessages() async {
    _loadingOlder = true;
    final beforeExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final loaded =
        await ref.read(chatProvider.notifier).loadOlderMessages(widget.threadId);
    if (loaded && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final afterExtent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(
          _scrollController.position.pixels + (afterExtent - beforeExtent),
        );
      });
    }
    _loadingOlder = false;
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider.notifier).sendMessage(widget.threadId, text);
    _composer.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  /// Ported from `ChatDetailView.handleSelectedPhoto` — opens the photo
  /// picker, validates and uploads the file, and sends an attachment message.
  Future<void> _pickAndSendPhoto() async {
    // First-time soft pre-prompt explaining why we need photo access, before
    // the system picker opens (QA #100 — the modern Android Photo Picker does
    // not surface its own permission dialog).
    if (!await ChatAttachmentPromptStore.hasShown()) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Доступ к фото')),
          content: Text(
            tr('Разрешите доступ к фотографиям, чтобы прикреплять их в чат.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr('Отмена')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr('Разрешить')),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      await ChatAttachmentPromptStore.markShown();
    }

    final picker = ImagePicker();
    final XFile? xfile;
    try {
      xfile = await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть галерею.'))),
      );
      return;
    }
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final fileName = xfile.name.isNotEmpty ? xfile.name : 'photo.jpg';
    final mime = xfile.mimeType ?? _mimeFromExtension(fileName);
    if (!mounted) return;

    final error =
        await ref.read(chatProvider.notifier).sendPhotoAttachment(
              widget.threadId,
              data: bytes,
              fileName: fileName,
              contentType: mime,
            );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _mimeFromExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
  }

  /// Blocks or unblocks the chat partner (App Store Guideline 1.2). Blocking
  /// hides the conversation both ways and returns to the chat list.
  Future<void> _toggleBlock(ChatThread thread, bool isBlocked) async {
    final id = thread.participantBackendId;
    if (id == null) return;
    final notifier = ref.read(blockedUserIdsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (isBlocked) {
      try {
        await notifier.unblock(id);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(tr('Пользователь разблокирован.'))),
        );
      } catch (_) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content:
                Text(tr('Не удалось разблокировать. Попробуйте ещё раз.')),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Заблокировать пользователя?')),
        content: Text(
          trf(
            'Вы больше не увидите сообщения, поездки и запросы от {name}, '
            'а этот пользователь — ваши. Чат скроется из списка. Разблокировать '
            'можно в настройках приватности.',
            {'name': thread.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('Отмена')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('Заблокировать')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await notifier.block(id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Пользователь заблокирован.'))),
      );
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('Не удалось заблокировать. Попробуйте ещё раз.')),
        ),
      );
    }
  }

  void _openPartnerProfile(ChatThread thread) {
    final backendId = thread.participantBackendId;
    if (backendId == null) return;
    final fallback = UserProfile(
      id: backendId,
      backendId: backendId,
      name: thread.name,
      rating: 0,
      completedTrips: 0,
      avatarBytes: thread.avatarBytes,
      avatarUrl: thread.avatarUrl,
    );
    Navigator.of(context).push(
      HSRoute<void>(
        builder: (_) => UserPublicProfileScreen(
          userId: backendId,
          fallback: fallback,
        ),
      ),
    );
  }

  /// Ported from `ChatDetailView.showReviewSheet`. Opens the leave-review
  /// sheet bound to [prompt]; on submit, calls `ChatNotifier.submitReview`.
  Future<void> _openLeaveReviewSheet(ReviewPromptContext prompt) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaveRideReviewSheet(prompt: prompt),
    );
    if (!mounted) return;
    if (submitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Спасибо за отзыв!'))),
      );
    }
  }

  /// Ported from `ChatDetailView.groupedMessages` — consecutive runs of
  /// messages sharing a day label.
  List<ChatMessageGroup> _groupedMessages(ChatThread thread) {
    final groups = <ChatMessageGroup>[];
    for (final message in thread.messages) {
      if (groups.isEmpty || groups.last.title != message.dayLabel) {
        groups.add(
          ChatMessageGroup(title: message.dayLabel, messages: [message]),
        );
      } else {
        groups.last.messages.add(message);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final chatState = ref.watch(chatProvider);
    final threads = chatState.threads;
    final thread = threads.cast<ChatThread?>().firstWhere(
      (t) => t?.id == widget.threadId,
      orElse: () => null,
    );

    if (thread == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: GlassCard(
            child: Text(
              tr('Этот чат больше недоступен.'),
              style: HSText.subheadline.copyWith(color: context.secondaryText),
            ),
          ),
        ),
      );
    }

    final groups = _groupedMessages(thread);
    final partnerBlocked = thread.participantBackendId != null &&
        ref.watch(blockedUserIdsProvider).contains(thread.participantBackendId);

    // Auto-scroll to the newest message when one arrives — but only if the user
    // is already at the bottom, so reading history is never interrupted.
    final msgCount = thread.messages.length;
    if (msgCount > _lastMsgCount) {
      final wasAtBottom = _atBottom;
      _lastMsgCount = msgCount;
      if (_initialScrollDone && wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToBottom();
          ref.read(chatProvider.notifier).markRead(widget.threadId);
        });
      }
    }

    return Scaffold(
      backgroundColor: hs.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: thread.participantBackendId == null
              ? null
              : () => _openPartnerProfile(thread),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                heroAvatar(
                  id: thread.participantBackendId,
                  child: ProfileAvatar(
                    initials: thread.initials,
                    avatarBytes: thread.avatarBytes,
                    avatarUrl: thread.avatarUrl,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thread.name,
                        style: HSText.headline,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (thread.isTyping)
                        Text(
                          tr('печатает...'),
                          style: HSText.caption.copyWith(color: hs.primary),
                        )
                      else if (thread.isOnline)
                        Text(
                          tr('в сети'),
                          style: HSText.caption
                              .copyWith(color: context.secondaryText),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone, size: 18, color: hs.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('Звонок скоро появится'))),
              );
            },
          ),
          if (thread.participantBackendId != null)
            PopupMenuButton<String>(
              tooltip: tr('Ещё'),
              onSelected: (value) {
                if (value == 'profile') {
                  _openPartnerProfile(thread);
                } else if (value == 'block') {
                  _toggleBlock(thread, partnerBlocked);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'profile', child: Text(tr('Профиль'))),
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                    partnerBlocked
                        ? tr('Разблокировать')
                        : tr('Заблокировать'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Pinned booking request — stays under the app bar, always visible
          // regardless of scroll (Telegram "pinned message" style).
          if (chatState.pendingBooking != null)
            PendingBookingBanner(
              context: chatState.pendingBooking!,
              onConfirm: () => ref
                  .read(chatProvider.notifier)
                  .updatePendingBooking(
                    threadId: widget.threadId,
                    status: 'confirmed',
                  ),
              onDecline: () => ref
                  .read(chatProvider.notifier)
                  .updatePendingBooking(
                    threadId: widget.threadId,
                    status: 'cancelled',
                  ),
            ),
          Expanded(
            child: _loadingThread && thread.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: ConstrainedBox(
                        // Bottom-anchor: when the conversation is shorter than the
                        // viewport, the column fills the height and aligns its
                        // content to the bottom, so the latest message sits just
                        // above the composer instead of leaving an empty void.
                        // (minus the 16+12 vertical padding so it doesn't force a
                        // spurious scroll.) bottom still == maxScrollExtent, so the
                        // auto-scroll / load-older logic is unchanged.
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 28,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final group in groups) ...[
                              MessageDateDivider(title: group.title),
                              for (final message in group.messages) ...[
                                if (_firstUnreadId != null &&
                                    message.id == _firstUnreadId)
                                  _NewMessagesDivider(key: _unreadDividerKey),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _MessageRow(
                                    message: message,
                                    threadId: widget.threadId,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (chatState.reviewPrompt != null)
            ReviewPromptBanner(
              prompt: chatState.reviewPrompt!,
              onTap: () => _openLeaveReviewSheet(chatState.reviewPrompt!),
              onDismiss: () =>
                  ref.read(chatProvider.notifier).dismissReviewPrompt(),
            ),
          ChatComposerBar(
            controller: _composer,
            onSend: _send,
            onAttach: _pickAndSendPhoto,
          ),
        ],
      ),
    );
  }
}

/// Ported from `ChatMessageRow` in `ChatDetailSections.swift` — aligns the
/// bubble depending on whether the message is system / incoming / outgoing.
class _MessageRow extends ConsumerWidget {
  const _MessageRow({required this.message, required this.threadId});

  final ChatMessage message;
  final String threadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.kind == ChatMessageKind.system) {
      return MessageBubble(message: message);
    }
    final attachment = message.attachment;
    return Row(
      children: [
        if (!message.isIncoming) const Spacer(flex: 1),
        Flexible(
          flex: 5,
          child: Align(
            alignment: message.isIncoming
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: MessageBubble(
              message: message,
              onOpenAttachment: attachment == null
                  ? null
                  : () => _openAttachment(context, ref, attachment),
              onRetry:
                  message.deliveryStatus == ChatMessageDeliveryStatus.failed
                  ? () => ref
                        .read(chatProvider.notifier)
                        .retryMessage(threadId, message.id)
                  : null,
            ),
          ),
        ),
        if (message.isIncoming) const Spacer(flex: 1),
      ],
    );
  }

  /// Resolves the attachment to a viewable URL and opens it — photos in an
  /// in-app viewer, other files via the system handler (QA #77).
  Future<void> _openAttachment(
    BuildContext context,
    WidgetRef ref,
    ChatAttachment attachment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final url = await ref.read(chatProvider.notifier).attachmentUrl(attachment);
    if (url == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть вложение.'))),
      );
      return;
    }
    if (attachment.kind == ChatAttachmentKind.photo) {
      navigator.push(
        HSRoute<void>(
          builder: (_) =>
              _AttachmentImageViewer(url: url, title: attachment.title),
        ),
      );
      return;
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть вложение.'))),
      );
    }
  }
}

/// Full-screen, zoomable viewer for a photo attachment (QA #77).
class _AttachmentImageViewer extends StatelessWidget {
  const _AttachmentImageViewer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (context, error, stack) => Center(
              child: Text(
                tr('Не удалось загрузить изображение.'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Новые сообщения" separator shown above the first unread message, like
/// Telegram's unread divider.
class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final lineColor = hs.primary.withValues(alpha: 0.35);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: lineColor, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              tr('Новые сообщения'),
              style: HSText.caption2Bold.copyWith(color: hs.primary),
            ),
          ),
          Expanded(child: Divider(color: lineColor, thickness: 1)),
        ],
      ),
    );
  }
}

/// Banner above the composer that prompts the passenger to leave a review for
/// a freshly-completed trip. Ported from the "оставить отзыв" affordance in
/// `ChatDetailView.swift`.
class ReviewPromptBanner extends StatelessWidget {
  const ReviewPromptBanner({
    super.key,
    required this.prompt,
    required this.onTap,
    required this.onDismiss,
  });

  final ReviewPromptContext prompt;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hs.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hs.stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.star_rounded, color: hs.warm, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trf('Как прошла поездка с {name}?',
                        {'name': prompt.targetName}),
                    style: HSText.subheadlineSemibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trf('Оставьте отзыв за {route}.',
                        {'route': prompt.routeText}),
                    style: HSText.caption
                        .copyWith(color: context.secondaryText),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            tooltip: tr('Скрыть'),
            onPressed: onDismiss,
            icon: Icon(Icons.close, color: context.secondaryText),
          ),
        ],
      ),
    );
  }
}

/// Ported from `LeaveRideReviewView` in `RideDetailViews.swift`. A modal sheet
/// with a 1-5 star picker, optional comment and a "опубликовать отзыв" button.
class LeaveRideReviewSheet extends ConsumerStatefulWidget {
  const LeaveRideReviewSheet({super.key, required this.prompt});
  final ReviewPromptContext prompt;

  @override
  ConsumerState<LeaveRideReviewSheet> createState() =>
      _LeaveRideReviewSheetState();
}

class _LeaveRideReviewSheetState extends ConsumerState<LeaveRideReviewSheet> {
  final _comment = TextEditingController();
  double _rating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final error = await ref.read(chatProvider.notifier).submitReview(
          rating: _rating,
          comment: _comment.text,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: hs.background,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: hs.stroke,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('Отзыв о поездке'), style: HSText.headline),
            const SizedBox(height: 4),
            Text(
              trf('Поделитесь впечатлением о поездке с {name}.',
                  {'name': widget.prompt.targetName}),
              style: HSText.subheadline.copyWith(color: context.secondaryText),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i == 5 ? 0 : 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _rating = i.toDouble()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: hs.secondarySurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _rating >= i ? Icons.star : Icons.star_border,
                            color: hs.warm,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(tr('Комментарий (необязательно)'),
                style: HSText.subheadlineSemibold),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                filled: true,
                fillColor: hs.secondarySurface,
                hintText: tr('Расскажите, как прошла поездка…'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: hs.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: hs.stroke),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(_isSubmitting
                    ? tr('Отправка…')
                    : tr('Опубликовать отзыв')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ported from `PendingBookingBanner` in `ChatDetailSections.swift`. Shown
/// above the composer when the chat partner has a pending booking against one
/// of the signed-in driver's rides — exposes accept/decline buttons.
class PendingBookingBanner extends StatelessWidget {
  const PendingBookingBanner({
    super.key,
    required this.context,
    required this.onConfirm,
    required this.onDecline,
  });

  final PendingChatBookingContext context;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final ctx = this.context;
    final seatsText = ctx.seatsCount == 1
        ? tr('1 место')
        : ctx.seatsCount < 5
            ? trf('{count} места', {'count': ctx.seatsCount})
            : trf('{count} мест', {'count': ctx.seatsCount});
    final departureText = DateTextFormatter.dayMonthTime(ctx.departureAt);

    // Pinned under the app bar (Telegram "pinned message" style): always
    // visible, independent of scroll, with a bottom hairline + downward shadow
    // and a primary accent stripe on the left.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: hs.cardBackground,
        border: Border(
          left: BorderSide(color: hs.primary, width: 3),
          bottom: BorderSide(color: hs.stroke),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.event_seat_outlined,
                  size: 16,
                  color: hs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Заявка на поездку'),
                      style: HSText.captionSemibold.copyWith(color: hs.primary),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      ctx.route,
                      style: HSText.subheadlineSemibold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$departureText · $seatsText',
                      style: HSText.caption.copyWith(
                        color: context.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(tr('Отклонить')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(tr('Подтвердить')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
