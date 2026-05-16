import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/date_formatter.dart';
import '../../models/chat.dart';
import '../../models/user_profile.dart';
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

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(chatProvider.notifier);
    notifier.setActiveThread(widget.threadId);
    final draft = notifier.consumePendingDraft(widget.threadId);
    if (draft != null) _composer.text = draft;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      notifier.markRead(widget.threadId);
      _jumpToBottom();
      await notifier.loadThread(widget.threadId);
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    });
  }

  @override
  void dispose() {
    ref.read(chatProvider.notifier).clearActiveThread();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  /// Loads the preceding page of messages when the user scrolls near the top,
  /// preserving the visible position so the list does not jump.
  void _onScroll() {
    if (_loadingOlder || !_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 80) {
      _loadOlderMessages();
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  /// Ported from `ChatDetailView.handleSelectedPhoto` — opens the photo
  /// picker, validates and uploads the file, and sends an attachment message.
  Future<void> _pickAndSendPhoto() async {
    final picker = ImagePicker();
    final XFile? xfile;
    try {
      xfile = await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть галерею.')),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  String _mimeFromExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    return 'image/jpeg';
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
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
        const SnackBar(content: Text('Спасибо за отзыв!')),
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
              'Этот чат больше недоступен.',
              style: HSText.subheadline.copyWith(color: context.secondaryText),
            ),
          ),
        ),
      );
    }

    final groups = _groupedMessages(thread);

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
                          'печатает...',
                          style: HSText.caption.copyWith(color: hs.primary),
                        )
                      else if (thread.isOnline)
                        Text(
                          'в сети',
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
                const SnackBar(content: Text('Звонок скоро появится')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              children: [
                for (final group in groups) ...[
                  MessageDateDivider(title: group.title),
                  for (final message in group.messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MessageRow(message: message),
                    ),
                ],
              ],
            ),
          ),
          if (chatState.pendingBooking != null)
            PendingBookingBanner(
              context: chatState.pendingBooking!,
              onConfirm: () => ref
                  .read(chatProvider.notifier)
                  .updatePendingBooking(
                      threadId: widget.threadId, status: 'confirmed'),
              onDecline: () => ref
                  .read(chatProvider.notifier)
                  .updatePendingBooking(
                      threadId: widget.threadId, status: 'declined'),
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
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.system) {
      return MessageBubble(message: message);
    }
    return Row(
      children: [
        if (!message.isIncoming) const Spacer(flex: 1),
        Flexible(
          flex: 5,
          child: Align(
            alignment: message.isIncoming
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: MessageBubble(message: message),
          ),
        ),
        if (message.isIncoming) const Spacer(flex: 1),
      ],
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
                    'Как прошла поездка с ${prompt.targetName}?',
                    style: HSText.subheadlineSemibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Оставьте отзыв за ${prompt.routeText}.',
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
            tooltip: 'Скрыть',
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
            Text('Отзыв о поездке', style: HSText.headline),
            const SizedBox(height: 4),
            Text(
              'Поделитесь впечатлением о поездке с ${widget.prompt.targetName}.',
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
            Text('Комментарий (необязательно)',
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
                hintText: 'Расскажите, как прошла поездка…',
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
                child: Text(_isSubmitting ? 'Отправка…' : 'Опубликовать отзыв'),
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
        ? '1 место'
        : ctx.seatsCount < 5
            ? '${ctx.seatsCount} места'
            : '${ctx.seatsCount} мест';
    final departureText = DateTextFormatter.dayMonthTime(ctx.departureAt);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hs.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hs.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Заявка на поездку',
              style: HSText.subheadlineSemibold.copyWith(color: hs.primary)),
          const SizedBox(height: 4),
          Text(ctx.route, style: HSText.subheadline),
          const SizedBox(height: 2),
          Text(
            '$departureText · $seatsText',
            style: HSText.caption.copyWith(color: context.secondaryText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Отклонить'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onConfirm,
                  child: const Text('Подтвердить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
