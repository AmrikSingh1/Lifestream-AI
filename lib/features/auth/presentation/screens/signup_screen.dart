import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../providers/auth_provider.dart';
import '../widgets/glassmorphic_input.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Save form state to provider
    ref.read(signupFormProvider.notifier).updateFullName(''); // Default empty
    ref.read(signupFormProvider.notifier).updateEmail(_emailController.text.trim());
    ref.read(signupFormProvider.notifier).updatePassword(_passwordController.text.trim());

    // Call Sign Up
    final success = await ref.read(authStateProvider.notifier).signUp();

    if (success && mounted) {
      showSuccessSnackbar(context, 'Account created successfully!');
      context.goNamed('role'); // Redirect to Role Selection
    } else if (mounted) {
      final state = ref.read(authStateProvider);
      if (state.hasError) {
        showErrorSnackbar(context, state.error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _onGoogleSignIn() async {
    final success = await ref.read(authStateProvider.notifier).signInWithGoogle();
    
    if (success && mounted) {
      context.go(AppRoutes.home); // Router will redirect to role selection if needed
    } else if (mounted) {
      final state = ref.read(authStateProvider);
      if (state.hasError) {
        showErrorSnackbar(context, state.error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Back button
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.onboarding);
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.glassWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),

                  // Header
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 500.ms).slideY(
                        begin: 0.2,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 8),
                  const Text(
                    'Join the LifeStream AI network.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                  const SizedBox(height: 40),

                  // Glassmorphic form card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.04),
                            ],
                          ),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Email
                            GlassmorphicInput(
                              label: 'Email Address',
                              hint: 'you@example.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Email required';
                                if (!value.contains('@')) return 'Valid email required';
                                return null;
                              },
                            ).animate().fadeIn(delay: 380.ms),

                            const SizedBox(height: 16),

                            // Password
                            GlassmorphicInput(
                              label: 'Password',
                              hint: 'Create a strong password',
                              controller: _passwordController,
                              obscureText: true,
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Password required';
                                if (value.length < 6) return 'At least 6 characters';
                                return null;
                              },
                            ).animate().fadeIn(delay: 460.ms),

                          ],
                        ),
                      ),
                    ),
                    ).animate().fadeIn(delay: 250.ms, duration: 600.ms).slideY(
                          begin: 0.2,
                          curve: Curves.easeOut,
                        ),

                  const SizedBox(height: 32),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        disabledBackgroundColor: AppColors.royalBlue.withOpacity(0.5),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.royalBlueLight,
                              AppColors.royalBlueDark,
                            ],
                          ),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 10),
                                    Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    ).animate().fadeIn(delay: 520.ms, duration: 500.ms).slideY(
                          begin: 0.2,
                        ),

                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.3))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.3))),
                    ],
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 24),

                  // Google Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _onGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),

                  const SizedBox(height: 40),

                  // Login Link
                  Center(
                    child: TextButton(
                      onPressed: () => context.goNamed('login'),
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Log In',
                              style: TextStyle(
                                color: AppColors.crimson,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 800.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
