import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_backdrop.dart';

/// Drop-in replacement for [MaterialPageRoute] that gives every pushed screen
/// its own solid background + local [AppBackdrop] layer.
///
/// Why: all Scaffolds use `Colors.transparent` so the global backdrop shows
/// through. During a [CupertinoPageTransitionsBuilder] slide animation two
/// transparent screens are composited on the same base, making text from both
/// screens ghost through each other. Wrapping each page in a solid
/// [ColoredBox] + local backdrop turns it into an opaque panel — the slide
/// looks exactly like native iOS navigation.
class HSRoute<T> extends MaterialPageRoute<T> {
  HSRoute({required super.builder, super.settings, super.fullscreenDialog});

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = super.buildPage(context, animation, secondaryAnimation);
    return _RouteShell(child: page);
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);
}

/// Solid background + decorative circles for every pushed page.
class _RouteShell extends StatelessWidget {
  const _RouteShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hs = context.hs;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: hs.background),
        const AppBackdrop(),
        child,
      ],
    );
  }
}
