import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modern, BlaBlaCar-flavoured splash. Uses a dark-navy radial gradient base
/// with a soft teal glow under the logo, then plays a short staggered intro:
///
///   t = 0   ms : background fades in, light haptic tap fires
///   t = 200 ms : logo circle scales 0.7 → 1.0 with [Curves.easeOutBack]
///   t = 550 ms : "HamSafar" wordmark slides up from 24 px + fades in
///   t = 750 ms : tagline fades in
///   t = 900 ms : three pulsing dots start at the bottom (loop forever until
///                [LaunchGate] swaps in the real UI)
///
/// The widget is wrapped in [Material] explicitly so even when Flutter is
/// in debug mode no missing-`DefaultTextStyle` warning (the yellow underline)
/// can leak through if the route transition exposes [Text] before the
/// MaterialApp's default style is in scope.
class LaunchSplash extends StatefulWidget {
  const LaunchSplash({super.key});

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;

  late final Animation<double> _bgFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _bgFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.18, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.18, 0.5, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.5, 0.78, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.5, 0.78, curve: Curves.easeOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.68, 0.95, curve: Curves.easeOut),
    );

    // Light haptic tap on splash appearance — BlaBlaCar / Revolut style.
    // No-op on platforms that don't support feedback.
    HapticFeedback.lightImpact();

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.canvas,
      color: const Color(0xFF0D1421),
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ---- Background: dark navy + soft teal radial glow ----
              FadeTransition(
                opacity: _bgFade,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.1),
                      radius: 0.85,
                      colors: [
                        Color(0xFF1A2A4A),
                        Color(0xFF0D1421),
                      ],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),

              // ---- Subtle glow halo behind the logo ----
              Center(
                child: FadeTransition(
                  opacity: _logoFade,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(
                        color: Color(0x40149ECC),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // ---- Logo + title + tagline column ----
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo circle
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _LogoMark(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Opacity(
                    opacity: _titleFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _titleSlide.value),
                      child: const Text(
                        'HamSafar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                          decoration: TextDecoration.none,
                          fontFamily: 'Manrope',
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tagline
                  Opacity(
                    opacity: _taglineFade.value,
                    child: Text(
                      'Поездки между городами',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 0.4,
                        decoration: TextDecoration.none,
                        fontFamily: 'Manrope',
                      ),
                    ),
                  ),
                ],
              ),

              // ---- Pulsing dots at the bottom ----
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: FadeTransition(
                  opacity: _taglineFade,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      return _LoadingDots(t: _pulse.value);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    // The real HamSafar mark on a white squircle (matches the app icon), so it
    // reads on the dark splash.
    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF149ECC).withValues(alpha: 0.40),
            blurRadius: 36,
            spreadRadius: 1,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Image.asset(
        'assets/brand/icon_foreground.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        // Each dot lags by 0.18 of the cycle.
        final shifted = ((t + i * 0.18) % 1.0);
        final pulse = 0.4 + 0.6 * (shifted < 0.5 ? shifted * 2 : (1 - shifted) * 2);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20 + 0.55 * pulse),
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
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
    // Give the splash time to play its staggered intro (~1.1s) before
    // crossfading to the real UI.
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      // A soft selection click on the transition — a subtle BlaBlaCar /
      // Revolut affordance that the app is now "live".
      HapticFeedback.selectionClick();
      setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _ready ? widget.child : const LaunchSplash(),
    );
  }
}
