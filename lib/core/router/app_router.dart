import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/role_selection/presentation/role_selection_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/user_onboarding/presentation/donor_onboarding_screen.dart';
import '../../features/user_onboarding/presentation/recipient_onboarding_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const roleSelection = '/role';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const donorOnboarding = '/user-onboarding/donor';
  static const recipientOnboarding = '/user-onboarding/recipient';
  static const emailVerification = '/verify-email';
}

/// Checks if the authenticated user has completed onboarding.
/// Returns the route to redirect to, or null if no redirect is needed.
Future<String?> _checkOnboardingRedirect(GoRouterState state) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final isGoingToUserOnboarding =
      state.matchedLocation == AppRoutes.donorOnboarding ||
          state.matchedLocation == AppRoutes.recipientOnboarding;

  // If going to user onboarding, allow it (they are authenticated)
  if (isGoingToUserOnboarding) return null;

  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  if (!doc.exists) {
    if (state.matchedLocation == AppRoutes.roleSelection) return null;
    return AppRoutes.roleSelection;
  }

  final data = doc.data()!;
  final onboardingComplete = data['onboardingComplete'] as bool? ?? false;
  final role = data['role'] as String?;
  final isEmailVerified = data['isEmailVerifiedViaOtp'] as bool? ?? false;

  if (role == null || role.isEmpty) {
    if (state.matchedLocation == AppRoutes.roleSelection) return null;
    return AppRoutes.roleSelection;
  }

  if (!onboardingComplete) {
    final targetOnboarding = role == 'donor'
        ? AppRoutes.donorOnboarding
        : AppRoutes.recipientOnboarding;
    if (state.matchedLocation == targetOnboarding) return null;
    return targetOnboarding;
  }

  // Onboarding complete — now check for email verification
  if (!isEmailVerified) {
    if (state.matchedLocation == AppRoutes.emailVerification) return null;
    return AppRoutes.emailVerification;
  }

  // Onboarding complete & Email verified
  final isGoingToAuthPages = state.matchedLocation == AppRoutes.login ||
      state.matchedLocation == AppRoutes.signup ||
      state.matchedLocation == AppRoutes.onboarding ||
      state.matchedLocation == AppRoutes.roleSelection ||
      state.matchedLocation == AppRoutes.splash ||
      state.matchedLocation == AppRoutes.donorOnboarding ||
      state.matchedLocation == AppRoutes.recipientOnboarding ||
      state.matchedLocation == AppRoutes.emailVerification;

  if (isGoingToAuthPages) {
    return AppRoutes.home;
  }

  return null;
}

final goRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  redirect: (BuildContext context, GoRouterState state) async {
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
    final isGoingToAuth = state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.signup ||
        state.matchedLocation == AppRoutes.onboarding ||
        state.matchedLocation == AppRoutes.roleSelection ||
        state.matchedLocation == AppRoutes.splash ||
        state.matchedLocation == AppRoutes.donorOnboarding ||
        state.matchedLocation == AppRoutes.recipientOnboarding ||
        state.matchedLocation == AppRoutes.emailVerification;

    if (!isAuthenticated && !isGoingToAuth) {
      return AppRoutes.onboarding;
    }
    if (isAuthenticated) {
      return _checkOnboardingRedirect(state);
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.roleSelection,
      name: 'role',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const RoleSelectionScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.signup,
      name: 'signup',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SignupScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: AppRoutes.home,
      name: 'home',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: AppRoutes.donorOnboarding,
      name: 'donorOnboarding',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const DonorOnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.recipientOnboarding,
      name: 'recipientOnboarding',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const RecipientOnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.emailVerification,
      name: 'emailVerification',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const EmailVerificationScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ),
  ],
);
