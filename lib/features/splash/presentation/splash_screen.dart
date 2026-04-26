import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.4,
            colors: [
              Color(0xFF0D1E4A),
              Color(0xFF050A18),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated logo container
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.08);
                  final glow = _pulseController.value;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.crimsonGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.crimson
                                .withOpacity(0.3 + glow * 0.4),
                            blurRadius: 30 + glow * 20,
                            spreadRadius: 2 + glow * 8,
                          ),
                          BoxShadow(
                            color: AppColors.royalBlue
                                .withOpacity(0.2 + glow * 0.2),
                            blurRadius: 50 + glow * 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  );
                },
                child: const Icon(
                  Icons.bloodtype_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 32),

              // App name
              const Text(
                'LifeStream',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(
                    begin: 0.3,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 8),

              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.royalBlue, AppColors.crimson],
                ).createShader(bounds),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

              const SizedBox(height: 16),

              const Text(
                'Smart Blood & Donor Network',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 600.ms),

              const SizedBox(height: 80),

              // Loading indicator
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.royalBlue.withOpacity(0.8),
                  ),
                ),
              ).animate().fadeIn(delay: 1200.ms, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
