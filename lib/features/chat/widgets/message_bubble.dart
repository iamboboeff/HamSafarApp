import 'package:flutter/material.dart';

import '../../../models/chat.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';

class _SystemStyle {
  const _SystemStyle({
    required this.icon,
    required this.tint,
    required this.background,
    required this.stroke,
  });
  final IconData icon;
  final Color tint;
  final Color background;
  final Color stroke;
}

/// Ported from `MessageBubble` in `ChatMessageComponents.swift`.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.onOpenAttachment});

  final ChatMessage message;

  /// Invoked when the user taps an attachment, to open/preview it (QA #77).
  final VoidCallback? onOpenAttachment;

  _SystemStyle _systemStyle(BuildContext context) {
    final hs = context.hs;
    final text = message.text.toLowerCase();
    if (text.contains('отмен')) {
      return _SystemStyle(
        icon: Icons.cancel,
        tint: Colors.red,
        background: Colors.red.withValues(alpha: 0.10),
        stroke: Colors.red.withValues(alpha: 0.18),
      );
    }
    if (text.contains('подтверж') || text.contains('заброни')) {
      return _SystemStyle(
        icon: Icons.check_circle,
        tint: hs.primary,
        background: hs.primary.withValues(alpha: 0.10),
        stroke: hs.primary.withValues(alpha: 0.18),
      );
    }
    if (text.contains('маршрут:') || text.contains('выезд')) {
      return _SystemStyle(
        icon: Icons.directions_car,
        tint: hs.warm,
        background: hs.warm.withValues(alpha: 0.10),
        stroke: hs.warm.withValues(alpha: 0.18),
      );
    }
    return _SystemStyle(
      icon: Icons.info,
      tint: context.secondaryText,
      background: hs.secondarySurface,
      stroke: hs.stroke,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.system) {
      final style = _systemStyle(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.stroke),
        ),
        child: Row(
          children: [
            Icon(style.icon, size: 14, color: style.tint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.text,
                style: HSText.captionMedium.copyWith(
                  color: context.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hs = context.hs;
    final isIncoming = message.isIncoming;
    final fg = isIncoming ? context.primaryText : Colors.white;
    final attachment = message.attachment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isIncoming ? hs.cardBackground : hs.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachment != null)
            GestureDetector(
              onTap: onOpenAttachment,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (isIncoming ? hs.primary : Colors.white)
                          .withValues(alpha: isIncoming ? 0.12 : 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      attachment.kind == ChatAttachmentKind.photo
                          ? Icons.photo
                          : Icons.description,
                      size: 18,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          attachment.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: HSText.subheadlineSemibold.copyWith(color: fg),
                        ),
                        Text(
                          attachment.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HSText.caption.copyWith(
                            color: isIncoming
                                ? context.secondaryText
                                : Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onOpenAttachment != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      attachment.kind == ChatAttachmentKind.photo
                          ? Icons.open_in_full
                          : Icons.download_rounded,
                      size: 16,
                      color: isIncoming
                          ? context.secondaryText
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ],
              ),
            )
          else
            Text(message.text, style: HSText.subheadline.copyWith(color: fg)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.timeLabel,
                style: HSText.caption2.copyWith(
                  color: isIncoming
                      ? context.secondaryText
                      : Colors.white.withValues(alpha: 0.8),
                ),
              ),
              if (!isIncoming && message.deliveryStatus != null) ...[
                const SizedBox(width: 4),
                Icon(
                  message.deliveryStatus == ChatMessageDeliveryStatus.read
                      ? Icons.done_all
                      : Icons.done,
                  size: 13,
                  color: Colors.white.withValues(
                    alpha:
                        message.deliveryStatus == ChatMessageDeliveryStatus.read
                        ? 1
                        : 0.8,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Ported from `MessageDateDivider` in `ChatMessageComponents.swift`.
class MessageDateDivider extends StatelessWidget {
  const MessageDateDivider({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.hs.cardBackground,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            title,
            style: HSText.captionSemibold.copyWith(
              color: context.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
