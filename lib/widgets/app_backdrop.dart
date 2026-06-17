import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Ported from `AppBackdrop` in `SharedUIComponents.swift` — the tinted base
/// color with three soft, blurred accent circles bleeding off-screen.
///
/// Implementation note: SwiftUI's `.blur(radius:)` renders the gaussian halo
/// without clipping it to the source bounds, so iOS shows a soft glow. Flutter's
/// `ImageFiltered` clips the blurred output to the child's painted bounds,
/// which made the circles look like bright "blobs" with hard edges. We work
/// around that by painting each circle inside a much larger transparent box,
/// giving the gaussian halo room to fade out naturally, and we slightly desaturate
/// the alphas + add a thin frost overlay so the overall scene reads as muted
/// glass instead of vivid neon.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light theme frosts toward the warm cream background; dark theme frosts
    // toward the deep navy. Both pull the saturation down toward iOS levels.
    final frostColor = (isDark ? hs.background : hs.cardBackground)
        .withValues(alpha: 0.32);

    return Positioned.fill(
      child: Stack(
        children: [
          _blurCircle(
            color: hs.primary.withValues(alpha: 0.07),
            size: 280,
            sigma: 48,
            dx: 120,
            dy: -260,
          ),
          _blurCircle(
            color: hs.purple.withValues(alpha: 0.08),
            size: 220,
            sigma: 44,
            dx: -140,
            dy: -120,
          ),
          _blurCircle(
            color: hs.passenger.withValues(alpha: 0.08),
            size: 260,
            sigma: 56,
            dx: -110,
            dy: 260,
          ),
          // Thin frost — knocks the saturation down so the screen looks
          // glassy instead of brightly tinted.
          Positioned.fill(
            child: IgnorePointer(child: Container(color: frostColor)),
          ),
        ],
      ),
    );
  }

  /// Render a soft, fully-faded gaussian glow. The circle is drawn inside an
  /// over-sized transparent canvas so the blur kernel can spread without being
  /// clipped at the child's bounds — matching SwiftUI's `.blur(radius:)` look.
  Widget _blurCircle({
    required Color color,
    required double size,
    required double sigma,
    required double dx,
    required double dy,
  }) {
    final canvasExtent = size + sigma * 6;
    return Center(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: SizedBox(
            width: canvasExtent,
            height: canvasExtent,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
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
