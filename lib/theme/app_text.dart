import 'package:flutter/material.dart';

/// Text styles approximating the SwiftUI semantic fonts used across HamSafar.
///
/// SwiftUI's Dynamic Type sizes are mapped to fixed sizes here; `.rounded`
/// designs collapse to bold weights since no rounded font is bundled yet.
abstract final class HSText {
  static const largeTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
  );
  static const title2 = TextStyle(fontSize: 26, fontWeight: FontWeight.w700);
  static const title3 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
  static const headline = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 17);
  static const bodyMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );
  static const subheadline = TextStyle(fontSize: 15);
  static const subheadlineMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
  static const subheadlineSemibold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  static const footnote = TextStyle(fontSize: 13);
  static const caption = TextStyle(fontSize: 12);
  static const captionMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  static const captionSemibold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const captionBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
  static const caption2 = TextStyle(fontSize: 11);
  static const caption2Bold = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
}

extension TextColorsX on BuildContext {
  /// SwiftUI `.primary` foreground.
  Color get primaryText => Theme.of(this).colorScheme.onSurface;

  /// SwiftUI `.secondary` foreground.
  Color get secondaryText =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.6);
}
