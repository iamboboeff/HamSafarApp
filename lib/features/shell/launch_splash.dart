import 'dart:ui';

import 'package:flutter/material.dart';

/// Ported from `LaunchSplashView` in `RootShellViews.swift`.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key});

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF2B57D4);
    const primary = Color(0xFF149ECC);
    return ColoredBox(
      color: purple,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x0AFFFFFF),
                  Color(0x00000000),
                  Color(0x1F000000),
                ],
              ),
            ),
            child: SizedBox.expand(),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = _controller.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: Container(
                      width: 140 + 28 * t,
                      height: 140 + 28 * t,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.94 + 0.14 * t,
                    child: Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, Color(0xB8149ECC)],
                  ),
                ),
                child: const Icon(
                  Icons.directions_car,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'HamSafar',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows [LaunchSplash] briefly on startup, then reveals [child] — the Flutter
/// stand-in for `ContentView`'s session-restore splash gate.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: _ready ? widget.child : const LaunchSplash(),
    );
  }
}
