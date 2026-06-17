import 'package:flutter/material.dart';

/// HamSafar palette, ported from the SwiftUI `Color` extension in `Theme.swift`.
///
/// Colors that differ between light/dark are exposed through this
/// [ThemeExtension] so widgets can read `context.hs` and get the right value
/// for the active brightness automatically.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.purple,
    required this.background,
    required this.tint,
    required this.cardBackground,
    required this.secondarySurface,
    required this.stroke,
    required this.mint,
    required this.warm,
    required this.passenger,
    required this.orange,
    required this.star,
    required this.danger,
  });

  /// Brand colors — identical in both modes.
  final Color primary;
  final Color purple;
  final Color mint;
  final Color warm;
  final Color passenger;
  final Color orange;
  final Color star;

  /// Cancelled / destructive state — brightness-tuned so it stays readable and
  /// doesn't clash with the coral passenger colour.
  final Color danger;

  /// Surface colors — brightness dependent.
  final Color background;
  final Color tint;
  final Color cardBackground;
  final Color secondarySurface;
  final Color stroke;

  static const _primary = Color(0xFF149ECC);
  static const _purple = Color(0xFF2B57D4);
  static const _mint = Color(0xFF33B885);
  static const _warm = Color(0xFFFABA36);
  static const _passenger = Color(0xFFED5736);
  static const _orange = Color(0xFFFF9500);
  static const _star = Color(0xFFFFCC00);

  factory AppColors.light() => const AppColors(
    primary: _primary,
    purple: _purple,
    mint: _mint,
    warm: _warm,
    passenger: _passenger,
    orange: _orange,
    star: _star,
    danger: Color(0xFFE5484D),
    background: Color(0xFFFCF5EB),
    tint: Color(0xFFE6F5F7),
    cardBackground: Color(0xFFFFFCF7),
    secondarySurface: Color(0xFFF2F7F2),
    stroke: Color(0xC7D6E0E6),
  );

  factory AppColors.dark() => const AppColors(
    primary: _primary,
    purple: _purple,
    mint: _mint,
    warm: _warm,
    passenger: _passenger,
    orange: _orange,
    star: _star,
    danger: Color(0xFFFF6166),
    background: Color(0xFF0D1421),
    tint: Color(0xFF141F33),
    cardBackground: Color(0xFF141C2E),
    secondarySurface: Color(0xFF1F2940),
    stroke: Color(0x14FFFFFF),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? purple,
    Color? background,
    Color? tint,
    Color? cardBackground,
    Color? secondarySurface,
    Color? stroke,
    Color? mint,
    Color? warm,
    Color? passenger,
    Color? orange,
    Color? star,
    Color? danger,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      purple: purple ?? this.purple,
      background: background ?? this.background,
      tint: tint ?? this.tint,
      cardBackground: cardBackground ?? this.cardBackground,
      secondarySurface: secondarySurface ?? this.secondarySurface,
      stroke: stroke ?? this.stroke,
      mint: mint ?? this.mint,
      warm: warm ?? this.warm,
      passenger: passenger ?? this.passenger,
      orange: orange ?? this.orange,
      star: star ?? this.star,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      background: Color.lerp(background, other.background, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      secondarySurface: Color.lerp(
        secondarySurface,
        other.secondarySurface,
        t,
      )!,
      stroke: Color.lerp(stroke, other.stroke, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      passenger: Color.lerp(passenger, other.passenger, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      star: Color.lerp(star, other.star, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  /// Shorthand for the HamSafar palette: `context.hs.primary`.
  AppColors get hs => Theme.of(this).extension<AppColors>()!;
}
