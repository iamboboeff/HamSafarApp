import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

/// Wraps a tappable child with the subtle press-scale used by the SwiftUI
/// button styles (`scaleEffect(isPressed ? 0.985 : 1)`).
class HSPressable extends StatefulWidget {
  const HSPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.985,
    this.pressedOpacity = 1,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final double pressedOpacity;

  @override
  State<HSPressable> createState() => _HSPressableState();
}

class _HSPressableState extends State<HSPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = _pressed && widget.onTap != null;
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: active ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: active ? widget.pressedOpacity : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Ported from `PrimaryFilledButtonStyle` in `SharedUIComponents.swift`.
class PrimaryFilledButton extends StatelessWidget {
  const PrimaryFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent,
    this.isLoading = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? accent;
  final bool isLoading;

  /// Optional trailing widget (e.g. a price), shown right-aligned.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final accentColor = accent ?? hs.primary;
    final enabled = onPressed != null && !isLoading;

    return HSPressable(
      onTap: enabled ? onPressed : null,
      pressedOpacity: 0.9,
      child: Opacity(
        opacity: enabled ? 1 : 0.78,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(HSRadius.medium),
          ),
          child: Row(
            mainAxisAlignment: trailing == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(label, style: HSText.headline.copyWith(color: Colors.white)),
              if (trailing != null)
                DefaultTextStyle.merge(
                  style: HSText.headline.copyWith(color: Colors.white),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ported from `SecondaryOutlineButtonStyle`.
class SecondaryOutlineButton extends StatelessWidget {
  const SecondaryOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return HSPressable(
      onTap: onPressed,
      pressedScale: 1,
      pressedOpacity: 0.8,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        decoration: BoxDecoration(
          color: hs.cardBackground.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(HSRadius.medium),
          border: Border.all(color: hs.stroke),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: HSText.subheadlineSemibold.copyWith(color: hs.primary),
        ),
      ),
    );
  }
}

/// Ported from `DestructiveOutlineButtonStyle`.
class DestructiveOutlineButton extends StatelessWidget {
  const DestructiveOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final red = Colors.red.withValues(alpha: 0.92);
    return HSPressable(
      onTap: onPressed,
      pressedScale: 1,
      pressedOpacity: 0.8,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
        decoration: BoxDecoration(
          color: hs.cardBackground.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(HSRadius.medium),
          border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: red),
              const SizedBox(width: 8),
            ],
            Text(label, style: HSText.subheadlineSemibold.copyWith(color: red)),
          ],
        ),
      ),
    );
  }
}
