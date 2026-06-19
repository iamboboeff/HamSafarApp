import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's base background.
///
/// Originally a tinted base with soft blurred accent glows (ported from
/// `AppBackdrop` in `SharedUIComponents.swift`). The design now calls for a
/// FLAT background — a solid dark surface in dark mode (solid cream in light
/// mode) with all the contrast coming from the gray cards on top, not from
/// background gradients/glows. So this is just a solid fill in both themes.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(color: context.hs.background),
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
