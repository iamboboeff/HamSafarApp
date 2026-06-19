import 'package:flutter/material.dart';

import 'package:hamsafar/core/i18n/l10n.dart';

import '../../../theme/app_colors.dart';

/// Ported from `ChatComposerBar` + `AttachmentMenuButton` in
/// `ChatDetailSections.swift` / `ChatSupportViews.swift`.
class ChatComposerBar extends StatelessWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      color: hs.cardBackground,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: onAttach,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hs.secondarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, size: 18, color: hs.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: tr('Введите сообщение'),
                  filled: true,
                  fillColor: hs.secondarySurface,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final canSend = controller.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: canSend ? onSend : null,
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: canSend
                        ? hs.primary
                        : hs.primary.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, size: 18, color: Colors.white),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
