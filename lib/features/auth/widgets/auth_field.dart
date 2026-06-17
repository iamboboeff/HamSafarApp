import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';

/// Ported from `AuthField` in `AuthenticationViews.swift`.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.title,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.isSecure = false,
    this.focusNode,
  });

  final String title;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool isSecure;

  /// Optional external focus node — lets the parent move focus into the field
  /// programmatically (e.g. autofocus the OTP field after the code is sent,
  /// QA #87). When null an internal node is used.
  final FocusNode? focusNode;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  FocusNode? _internalFocusNode;

  /// Whether the password text is currently hidden. Toggled by the eye button
  /// so users can reveal what they typed (QA #81).
  late bool _obscure = widget.isSecure;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: HSText.captionSemibold.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 8),
        // Tap anywhere in the field (icon / padding included) to focus and open
        // the keyboard — the collapsed text area alone was too small a target
        // (QA #30).
        GestureDetector(
          onTap: _focusNode.requestFocus,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hs.secondarySurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hs.stroke),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(widget.icon, size: 18, color: hs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: _obscure,
                    keyboardType: widget.keyboardType,
                    autocorrect: false,
                    enableSuggestions: !widget.isSecure,
                    decoration: InputDecoration.collapsed(hintText: widget.title),
                  ),
                ),
                if (widget.isSecure) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ported from `AuthDateField` in `AuthenticationViews.swift`.
class AuthDateField extends StatelessWidget {
  const AuthDateField({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: HSText.captionSemibold.copyWith(color: context.secondaryText),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hs.secondarySurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: hs.stroke),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Icon(icon, size: 18, color: hs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(value, style: HSText.body)),
                Icon(Icons.calendar_today, size: 16, color: hs.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
