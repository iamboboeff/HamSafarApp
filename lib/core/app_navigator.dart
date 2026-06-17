import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Global navigator key so push taps and in-app banners can navigate from
/// outside the widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

/// A new incoming chat message, published by the chat layer for the app root to
/// surface as a tappable banner. Decoupled via a stream so the chat state needs
/// no UI/feature imports.
class InAppMessage {
  const InAppMessage({
    required this.localThreadId,
    required this.title,
    required this.body,
  });

  final String localThreadId;
  final String title;
  final String body;
}

final StreamController<InAppMessage> inAppMessages =
    StreamController<InAppMessage>.broadcast();

/// Shows a tappable banner at the top of the screen (used for incoming messages
/// while the user is on another page). Auto-dismisses after [duration].
void showInAppMessageBanner({
  required String title,
  required String body,
  required VoidCallback onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) return;

  late OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _MessageBanner(
      title: title,
      body: body,
      onTap: () {
        remove();
        onTap();
      },
      onClose: remove,
    ),
  );
  overlay.insert(entry);
  Future.delayed(duration, remove);
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hs.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hs.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.chat_bubble_outline,
                      size: 18, color: hs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HSText.subheadlineSemibold,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HSText.caption
                            .copyWith(color: context.secondaryText),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(Icons.close,
                      size: 18, color: context.secondaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
