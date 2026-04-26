import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider for the selected role
final selectedRoleProvider = StateProvider<String?>((ref) => null);

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.heroGradient,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 48),
                const Text(
                  'How can we\nhelp you today?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: -0.2, curve: Curves.easeOut),

                const SizedBox(height: 12),
                const Text(
                  'Select your role to get started with the\nLifeStream AI network.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                const SizedBox(height: 60),

                // Donate Card
                _RoleCard(
                  icon: Icons.volunteer_activism_rounded,
                  title: 'I want to\nDonate',
                  subtitle: 'Be a hero. Your blood can\nsave up to 3 lives.',
                  gradient: AppColors.cardGradient,
                  glowColor: AppColors.royalBlue,
                  role: 'donor',
                  onTap: () async {
                    ref.read(selectedRoleProvider.notifier).state = 'donor';
                    final success = await ref.read(authStateProvider.notifier).updateUserRole(role: 'donor');
                    if (success && context.mounted) {
                      context.go(AppRoutes.donorOnboarding);
                    }
                  },
                ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideX(
                      begin: -0.3,
                      curve: Curves.easeOutBack,
                    ),

                const SizedBox(height: 24),

                // Need Blood Card
                _RoleCard(
                  icon: Icons.medical_services_rounded,
                  title: 'I need\nBlood',
                  subtitle:
                      'Find verified donors\nnear you in minutes.',
                  gradient: AppColors.crimsonGradient,
                  glowColor: AppColors.crimson,
                  role: 'recipient',
                  onTap: () async {
                    ref.read(selectedRoleProvider.notifier).state = 'recipient';
                    final success = await ref.read(authStateProvider.notifier).updateUserRole(role: 'recipient');
                    if (success && context.mounted) {
                      context.go(AppRoutes.recipientOnboarding);
                    }
                  },
                ).animate().fadeIn(delay: 550.ms, duration: 600.ms).slideX(
                      begin: 0.3,
                      curve: Curves.easeOutBack,
                    ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'You can change this later in settings.',
                    style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                    ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color glowColor;
  final String role;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.glowColor,
    required this.role,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _scaleController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _scaleController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor
                    .withOpacity(_isPressed ? 0.55 : 0.35),
                blurRadius: _isPressed ? 30 : 20,
                spreadRadius: _isPressed ? 4 : 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        widget.icon,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
