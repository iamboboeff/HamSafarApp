import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text.dart';

/// Ported from `AuthField` in `AuthenticationViews.swift`.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.title,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.isSecure = false,
  });

  final String title;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool isSecure;

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
        Container(
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
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isSecure,
                  keyboardType: keyboardType,
                  autocorrect: false,
                  enableSuggestions: !isSecure,
                  decoration: InputDecoration.collapsed(hintText: title),
                ),
              ),
            ],
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
