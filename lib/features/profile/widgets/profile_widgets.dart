import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimens.dart';
import '../../../theme/app_text.dart';

/// Ported from `SettingsGroupCard` in `SharedUIComponents.swift`.
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({super.key, required this.children});

  /// Rows are laid out vertically; pass plain widgets — the card adds its own
  /// padding. Use [SettingsDivider] between rows where needed.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HSRadius.small,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hs.cardBackground,
            hs.cardBackground.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(HSRadius.large),
        border: Border.all(color: hs.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: context.hs.stroke);
}

/// Ported from `SettingsRow` in `ProfileViews.swift`.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: HSText.bodyMedium)),
            Icon(Icons.chevron_right, size: 18, color: context.secondaryText),
          ],
        ),
      ),
    );
  }
}

/// Ported from `ToggleRow` in `ProfileViews.swift`.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: HSText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: HSText.caption.copyWith(color: context.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeTrackColor: context.hs.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Ported from `ProfileAvatarView` in `ProfileViews.swift`. When
/// [avatarBytes] is non-null the photo is rendered as a clipped circle;
/// otherwise a gradient circle with the user's initials matches the Swift
/// fallback.
class ProfileAvatarView extends StatelessWidget {
  const ProfileAvatarView({
    super.key,
    required this.initials,
    required this.size,
    this.avatarBytes,
  });

  final String initials;
  final double size;
  final Uint8List? avatarBytes;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final bytes = avatarBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hs.primary.withValues(alpha: 0.18), hs.tint],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: hs.primary,
        ),
      ),
    );
  }
}

/// Ported from `GuestProfileHeaderCard` in `ProfileViews.swift`.
class GuestProfileHeaderCard extends StatelessWidget {
  const GuestProfileHeaderCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 108,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              hs.primary.withValues(alpha: 0.16),
              hs.tint,
              hs.cardBackground,
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: hs.stroke),
        ),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_add_alt_1, size: 28, color: hs.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Войти в аккаунт',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.secondaryText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Сохраните поездки, историю поиска и доступ к сообщениям.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HSText.subheadline.copyWith(
                      color: context.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ported from `SimpleProfileInput` in `ProfileViews.swift` — a label above a
/// boxed input.
class SimpleProfileInput extends StatelessWidget {
  const SimpleProfileInput({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: HSText.subheadlineSemibold),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: hs.secondarySurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Ported from `CustomSegmentedControl` in `SharedUIComponents.swift`.
class HSSegmentedControl<T> extends StatelessWidget {
  const HSSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.titleOf,
    required this.onSelect,
  });

  final List<T> items;
  final T selected;
  final String Function(T) titleOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hs.cardBackground.withValues(alpha: 0.92),
            hs.tint.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(HSRadius.medium),
        border: Border.all(color: hs.stroke),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(item),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: item == selected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              hs.primary,
                              hs.primary.withValues(alpha: 0.78),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(HSRadius.small),
                  ),
                  child: Text(
                    titleOf(item),
                    style: HSText.subheadlineSemibold.copyWith(
                      color: item == selected
                          ? Colors.white
                          : context.primaryText.withValues(alpha: 0.72),
                      fontWeight: item == selected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
