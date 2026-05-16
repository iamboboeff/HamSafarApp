import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ported from `AppBackdrop` in `SharedUIComponents.swift` — the tinted base
/// color with three soft, blurred accent circles bleeding off-screen.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Positioned.fill(
      child: ColoredBox(
        color: hs.background,
        child: Stack(
          children: [
            _blurCircle(
              color: hs.primary.withValues(alpha: 0.10),
              size: 280,
              blur: 20,
              dx: 120,
              dy: -260,
            ),
            _blurCircle(
              color: hs.purple.withValues(alpha: 0.12),
              size: 220,
              blur: 18,
              dx: -140,
              dy: -120,
            ),
            _blurCircle(
              color: hs.passenger.withValues(alpha: 0.12),
              size: 260,
              blur: 24,
              dx: -110,
              dy: 260,
            ),
          ],
        ),
      ),
    );
  }

  Widget _blurCircle({
    required Color color,
    required double size,
    required double blur,
    required double dx,
    required double dy,
  }) {
    return Center(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// A [Scaffold]-friendly wrapper: paints [AppBackdrop] behind [child].
class BackdropScaffoldBody extends StatelessWidget {
  const BackdropScaffoldBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AppBackdrop(),
        Positioned.fill(child: child),
      ],
    );
  }
}
