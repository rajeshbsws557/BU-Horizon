// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/horizon_logo.dart';

/// Branded launch screen for the BU-ISSF campus club.
///
/// A staged reveal: a rotating gradient ring spins up behind the logo, then the
/// club acronym, full name and tagline fade/slide in. After the intro settles
/// it routes to the home shell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Drives the one-shot staged entrance (logo → title → subtitle → footer).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  // Continuous spin for the gradient ring around the logo.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  Timer? _navTimer;

  Animation<double> _fade(double start, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(start, end, curve: Curves.easeOut),
      );

  Animation<Offset> _rise(double start, double end) => Tween<Offset>(
        begin: const Offset(0, 0.28),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _intro,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ));

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _navTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) context.go(AppRoutes.home);
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _intro.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: DecoratedBox(
        // Soft vignette so the centre reads as a spotlight.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.25),
            radius: 1.1,
            colors: [
              context.colors.primarySoft.withValues(alpha: context.isLight ? 0.6 : 0.3),
              context.colors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              // ---- Logo inside a spinning gradient ring ----
              ScaleTransition(
                scale: Tween<double>(begin: 0.75, end: 1).animate(
                  CurvedAnimation(
                    parent: _intro,
                    curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
                  ),
                ),
                child: FadeTransition(
                  opacity: _fade(0, 0.45),
                  child: _RingedLogo(spin: _ring),
                ),
              ),
              const SizedBox(height: 34),

              // ---- Club acronym ----
              FadeTransition(
                opacity: _fade(0.35, 0.7),
                child: SlideTransition(
                  position: _rise(0.35, 0.7),
                  child: ShaderMask(
                    shaderCallback: (r) => context.colors.blueGradient.createShader(r),
                    child: Text(
                      'BU-ISSF',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: context.colors.textPrimary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ---- Accent underline ----
              FadeTransition(
                opacity: _fade(0.5, 0.8),
                child: Container(
                  width: 46,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: context.colors.blueGradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Full expanded name ----
              FadeTransition(
                opacity: _fade(0.55, 0.9),
                child: SlideTransition(
                  position: _rise(0.55, 0.9),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      'Barishal University\nIntelligent Systems & Security Forum',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 4),

              // ---- Footer: app name + loader + credit ----
              FadeTransition(
                opacity: _fade(0.7, 1),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Powered by ',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textMuted,
                          ),
                        ),
                        Text(
                          'BU Horizon',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        backgroundColor: context.colors.surfaceAlt,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Developed by Rajesh Biswas (rajeshbiswas.dev)',
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app logo wrapped in a thin, continuously rotating gradient ring with a
/// soft outer glow — the visual centrepiece of the splash.
class _RingedLogo extends StatelessWidget {
  final Animation<double> spin;
  const _RingedLogo({required this.spin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer breathing glow.
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          // Rotating conic gradient ring.
          RotationTransition(
            turns: spin,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary,
                    context.colors.accentCyan,
                    AppColors.primary,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                ),
              ),
            ),
          ),
          // Inner disc carves the ring to a thin band.
          Container(
            width: 134,
            height: 134,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.background,
            ),
          ),
          // The logo itself.
          const HorizonLogo(size: 110),
        ],
      ),
    );
  }
}
