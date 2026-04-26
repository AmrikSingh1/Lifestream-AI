import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

import '../../../../core/utils/snackbar_utils.dart';
import '../providers/auth_provider.dart';
import '../widgets/glassmorphic_input.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    final success = await ref.read(authStateProvider.notifier).signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (success && mounted) {
      context.goNamed('home');
    } else if (mounted) {
      // The auth provider throws error, but we catch it inside AsyncValue.guard
      // So if it fails, the error state is accessible via ref.read(authStateProvider)
      final state = ref.read(authStateProvider);
      if (state.hasError) {
        showErrorSnackbar(context, state.error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _onGoogleSignIn() async {
    final success = await ref.read(authStateProvider.notifier).signInWithGoogle();
    
    if (success && mounted) {
      context.goNamed('home');
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.darkBg,
              AppColors.royalBlueDark,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
                  SizedBox(height: 8.h),
                  Text(
                    'Login to continue saving lives.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
                  SizedBox(height: 40.h),

                  // Email
                  GlassmorphicInput(
                    label: 'Email Address',
                    hint: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter your email';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  )
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideX(begin: 0.1),
                  SizedBox(height: 16.h),

                  // Password
                  GlassmorphicInput(
                    label: 'Password',
                    hint: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 20),
                    controller: _passwordController,
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter your password';
                      return null;
                    },
                  )
                      .animate()
                      .fadeIn(delay: 500.ms)
                      .slideX(begin: 0.1),
                  SizedBox(height: 32.h),

                  // Login Button
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _onLogin,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      backgroundColor: AppColors.crimson,
                      foregroundColor: Colors.white,
                    ),
                    child: authState.isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms)
                      .scale(),
                  
                  SizedBox(height: 24.h),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.3))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Text(
                          'OR',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.3))),
                    ],
                  ).animate().fadeIn(delay: 700.ms),

                  SizedBox(height: 24.h),

                  // Google Login Button
                  ElevatedButton.icon(
                    onPressed: authState.isLoading ? null : _onGoogleSignIn,
                    icon: Icon(Icons.g_mobiledata, size: 28.sp),
                    label: Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),

                  SizedBox(height: 40.h),

                  // Sign Up Link
                  Center(
                    child: TextButton(
                      onPressed: () => context.pushNamed('signup'),
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
                          children: [
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: AppColors.crimson,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 900.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
