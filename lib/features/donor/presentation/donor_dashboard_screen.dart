import 'dart:ui';
import 'package:path/path.dart' as p;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/verification_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/request_completion_service.dart';
import '../../../../core/utils/pdf_actions.dart';
import '../../../../core/utils/certificate_generator.dart';
import 'providers/donor_providers.dart';
import 'radar_map_tab.dart';
import 'widgets/email_otp_sheet.dart';

// ─── Gemini API Key placeholder ───────────────────────────────────
// Replace with your actual key from https://aistudio.google.com
const _kGeminiApiKey = 'AIzaSyA8CsCYbEB79joG8JQD1ZW2tUAeA2LMAvk';

// ─── Chat message model ───────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);
}

// ─── Donor Level helper ───────────────────────────────────────────
class _DonorLevel {
  static const _levels = [
    (label: 'Bronze Hero', min: 0, max: 5, color: Color(0xFFCD7F32)),
    (label: 'Silver Hero', min: 6, max: 15, color: Color(0xFFC0C0C0)),
    (label: 'Gold Hero', min: 16, max: 30, color: Color(0xFFFFD700)),
    (label: 'Platinum Hero', min: 31, max: 99999, color: Color(0xFFE5E4E2)),
  ];

  static ({String label, Color color, double progress}) get(int count) {
    for (final lvl in _levels) {
      if (count >= lvl.min && count <= lvl.max) {
        final range = lvl.max - lvl.min;
        final prog = range == 0 ? 1.0 : (count - lvl.min) / range;
        return (label: lvl.label, color: lvl.color, progress: prog.clamp(0.0, 1.0));
      }
    }
    return (label: 'Platinum Hero', color: const Color(0xFFE5E4E2), progress: 1.0);
  }
}

// ─── Root Dashboard ───────────────────────────────────────────────
class DonorDashboardScreen extends ConsumerStatefulWidget {
  const DonorDashboardScreen({super.key});

  @override
  ConsumerState<DonorDashboardScreen> createState() =>
      _DonorDashboardScreenState();
}

class _DonorDashboardScreenState extends ConsumerState<DonorDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final verifiedAsync = ref.watch(emailOtpVerifiedProvider);

    if (verifiedAsync.valueOrNull == false) {
      return const _VerificationGateView();
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: IndexedStack(
        index: _tab,
        children: [
          _DashboardTab(onTabChange: (i) => setState(() => _tab = i)),
          const RadarMapTab(),
          const _AiCoachTab(),
          const _DonorCardTab(),
          const _DonorRequestsTab(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _VerificationGateView extends ConsumerWidget {
  const _VerificationGateView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(donorProfileStreamProvider);
    final email = FirebaseAuth.instance.currentUser?.email ??
        profileAsync.valueOrNull?['email'] as String?;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mark_email_unread_rounded,
                    color: AppColors.warning,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Verify email to continue',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'OTP verification is required before using donor features.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: email == null || email.isEmpty
                        ? null
                        : () => EmailOtpSheet.show(context, email),
                    child: const Text('Verify Email via OTP'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Navigation ────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.dashboard_rounded, label: 'Home'),
      (icon: Icons.radar_rounded, label: 'Radar'),
      (icon: Icons.psychology_rounded, label: 'AI Coach'),
      (icon: Icons.badge_rounded, label: 'My Card'),
      (icon: Icons.history_rounded, label: 'Requests'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: const Border(top: BorderSide(color: AppColors.glassBorder)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.only(right: i == items.length - 1 ? 0 : 6),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: selected
                          ? const LinearGradient(
                              colors: AppColors.heroGreenGradient)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: AppColors.heroGreenGlow,
                                  blurRadius: 12)
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon,
                            color: selected
                                ? Colors.white
                                : AppColors.textMuted,
                            size: 20),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 1 — DASHBOARD
// ═══════════════════════════════════════════════════════════════════
class _DashboardTab extends ConsumerWidget {
  final ValueChanged<int> onTabChange;
  const _DashboardTab({required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(donorProfileStreamProvider);
    final availState = ref.watch(availabilityProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A18), Color(0xFF060F1E), Color(0xFF050A18)],
        ),
      ),
      child: SafeArea(
        child: profileAsync.when(
          loading: () => _DashboardShimmer(),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: AppColors.error))),
          data: (data) {
            final isAvail = data?['isAvailable'] as bool? ?? false;
            final donations = data?['donationCount'] as int? ?? 0;
            final lives = data?['livesSaved'] as int? ?? 0;
            final lastDon = data?['lastDonationDate'] != null
                ? (data!['lastDonationDate'] as Timestamp).toDate()
                : null;
            final daysUntilEligible = lastDon == null
                ? 0
                : (90 -
                        DateTime.now()
                            .difference(lastDon)
                            .inDays)
                    .clamp(0, 90);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Top bar
                  _TopBar(data: data),
                  const SizedBox(height: 28),

                  // Hero Card
                  _HeroCard(
                    data: data,
                    isAvailable: isAvail,
                    onToggle: (v) =>
                        ref.read(availabilityProvider.notifier).toggle(v),
                    isTogglingLoading: availState.isLoading,
                  ),
                  const SizedBox(height: 20),

                  // Incoming Emergency Request Card
                  const _IncomingRequestCard(),
                  const SizedBox(height: 20),

                  // Blood Demand Predictor Widget
                  const _DemandPredictorCard(),
                  const SizedBox(height: 20),

                  // Stats Row
                  _StatsRow(
                    donations: donations,
                    lives: lives,
                    daysUntilEligible: daysUntilEligible,
                  ),
                  const SizedBox(height: 20),

                  // Quick Actions
                  _QuickActions(onTabChange: onTabChange),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _TopBar({required this.data});

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.darkBg.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.crimson.withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.crimson,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Are you sure you want to sign out of your account? You will need to log in again to access your profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: const Text(
                                'Cancel',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Navigator.pop(context); // close dialog
                              await FirebaseAuth.instance.signOut();
                              await GoogleSignIn().signOut();
                              if (context.mounted) {
                                context.go(AppRoutes.onboarding);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: AppColors.crimsonGradient,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.crimson.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Sign Out',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profile pic
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: AppColors.crimsonGradient),
            image: data?['profileImageUrl'] != null
                ? DecorationImage(
                    image: NetworkImage(data!['profileImageUrl'] as String),
                    fit: BoxFit.cover)
                : null,
          ),
          child: data?['profileImageUrl'] == null
              ? const Icon(Icons.person_rounded,
                  color: Colors.white, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back,',
                  style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.7),
                      fontSize: 13)),
              Text(
                (data?['fullName'] as String? ?? 'Hero')
                    .split(' ')
                    .first,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        // Logout
        GestureDetector(
          onTap: () => _showLogoutConfirmation(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.logout_rounded,
                color: AppColors.textSecondary, size: 18),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }
}

// ─── Hero Card ─────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool isAvailable;
  final ValueChanged<bool> onToggle;
  final bool isTogglingLoading;

  const _HeroCard({
    required this.data,
    required this.isAvailable,
    required this.onToggle,
    required this.isTogglingLoading,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isAvailable
                  ? [
                      AppColors.heroGreen.withOpacity(0.18),
                      AppColors.heroGreenDark.withOpacity(0.08),
                    ]
                  : [
                      Colors.white.withOpacity(0.09),
                      Colors.white.withOpacity(0.04),
                    ],
            ),
            border: Border.all(
              color: isAvailable
                  ? AppColors.heroGreen.withOpacity(0.5)
                  : AppColors.glassBorder,
              width: 1.5,
            ),
            boxShadow: isAvailable
                ? [
                    BoxShadow(
                        color: AppColors.heroGreenGlow,
                        blurRadius: 30,
                        spreadRadius: 2)
                  ]
                : [],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Pulsing heart
                  _PulsingHeart(active: isAvailable),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAvailable
                              ? '🟢  Available to Save Lives'
                              : '⏸️  You\'re on a Break',
                          style: TextStyle(
                            color: isAvailable
                                ? AppColors.heroGreen
                                : AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAvailable
                              ? 'You\'re visible on recipient maps'
                              : 'Toggle ON to appear as available',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Availability',
                            style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.8),
                                fontSize: 13)),
                        Text(
                          isAvailable ? 'Active Donor' : 'Inactive',
                          style: TextStyle(
                            color: isAvailable
                                ? AppColors.heroGreen
                                : AppColors.textMuted,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    isTogglingLoading
                        ? const SizedBox(
                            width: 36,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.heroGreen))
                        : GestureDetector(
                            onTap: () => onToggle(!isAvailable),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 58,
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                gradient: isAvailable
                                    ? const LinearGradient(
                                        colors: AppColors.heroGreenGradient)
                                    : null,
                                color: isAvailable
                                    ? null
                                    : Colors.white.withOpacity(0.12),
                                boxShadow: isAvailable
                                    ? [
                                        BoxShadow(
                                            color: AppColors.heroGreenGlow,
                                            blurRadius: 10)
                                      ]
                                    : [],
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 300),
                                alignment: isAvailable
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.15);
  }
}

// ─── Pulsing Heart ────────────────────────────────────────────────
class _PulsingHeart extends StatelessWidget {
  final bool active;
  const _PulsingHeart({required this.active});

  @override
  Widget build(BuildContext context) {
    final widget = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: active
              ? AppColors.heroGreenGradient
              : [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.04),
                ],
        ),
        boxShadow: active
            ? [
                BoxShadow(
                    color: AppColors.heroGreenGlow,
                    blurRadius: 16,
                    spreadRadius: 2)
              ]
            : [],
      ),
      child: Icon(
        Icons.favorite_rounded,
        color: active ? Colors.white : AppColors.textMuted,
        size: 26,
      ),
    );

    if (!active) return widget;

    return widget
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.12, 1.12),
          duration: 900.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .custom(
          duration: 0.ms,
          builder: (_, __, child) => child,
        );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int donations;
  final int lives;
  final int daysUntilEligible;

  const _StatsRow({
    required this.donations,
    required this.lives,
    required this.daysUntilEligible,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: Icons.favorite_rounded,
          value: '$lives',
          label: 'Lives Saved',
          color: AppColors.urgentRed,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.water_drop_rounded,
          value: '$donations',
          label: 'Donations',
          color: AppColors.royalBlueLight,
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: Icons.calendar_today_rounded,
          value: daysUntilEligible == 0 ? 'Ready!' : '$daysUntilEligible d',
          label: 'Next Eligible',
          color: daysUntilEligible == 0
              ? AppColors.heroGreen
              : AppColors.warning,
        ),
      ],
    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2);
  }
}

// ─── Demand Predictor Card ───────────────────────────────────────
class _DemandPredictorCard extends StatelessWidget {
  const _DemandPredictorCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_graph_rounded, color: AppColors.heroGreen, size: 20),
                  SizedBox(width: 8),
                  Text('AI Demand Forecast', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.royalBlueLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Next 7 Days', style: TextStyle(color: AppColors.royalBlueLight, fontSize: 10, fontWeight: FontWeight.w600)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DemandBar(bloodGroup: 'O+', value: 0.9, isUrgent: true),
              _DemandBar(bloodGroup: 'B+', value: 0.6, isUrgent: false),
              _DemandBar(bloodGroup: 'A+', value: 0.4, isUrgent: false),
              _DemandBar(bloodGroup: 'O-', value: 0.8, isUrgent: true),
            ],
          ),
          const SizedBox(height: 16),
          const Text('O+ and O- are predicted to be in critical shortage this weekend. Stay prepared.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1);
  }
}

class _DemandBar extends StatelessWidget {
  final String bloodGroup;
  final double value;
  final bool isUrgent;

  const _DemandBar({required this.bloodGroup, required this.value, required this.isUrgent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 12,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Container(
              width: 12,
              height: 60 * value,
              decoration: BoxDecoration(
                color: isUrgent ? AppColors.urgentRed : AppColors.heroGreen,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isUrgent ? [BoxShadow(color: AppColors.urgentRed.withOpacity(0.5), blurRadius: 6)] : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(bloodGroup, style: TextStyle(color: isUrgent ? AppColors.urgentRed : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Actions ────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final ValueChanged<int> onTabChange;
  const _QuickActions({required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: Icons.radar_rounded,
        label: 'Emergency\nRadar',
        color: AppColors.urgentRed,
        gradient: AppColors.crimsonGradient,
      ),
      (
        icon: Icons.psychology_rounded,
        label: 'AI Health\nCoach',
        color: AppColors.royalBlue,
        gradient: AppColors.cardGradient,
      ),
      (
        icon: Icons.badge_rounded,
        label: 'Donor\nID Card',
        color: AppColors.warning,
        gradient: [const Color(0xFFFFBE21), const Color(0xFFE0A800)],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: List.generate(actions.length, (i) {
            final a = actions[i];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  // Navigate to tab via state
                  onTabChange(i + 1);
                },
                child: Container(
                  margin: EdgeInsets.only(right: i < actions.length - 1 ? 8 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        a.color.withOpacity(0.15),
                        a.color.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: a.color.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: a.gradient),
                        ),
                        child: Icon(a.icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2);
  }
}

// ─── Shimmer Loading ──────────────────────────────────────────────
class _DashboardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.darkCard,
      highlightColor: AppColors.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // top bar
            Row(
              children: [
                _ShimBox(w: 46, h: 46, r: 23),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimBox(w: 80, h: 12),
                    const SizedBox(height: 6),
                    _ShimBox(w: 130, h: 18),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            _ShimBox(w: double.infinity, h: 160, r: 28),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _ShimBox(h: 90, r: 18)),
                const SizedBox(width: 10),
                Expanded(child: _ShimBox(h: 90, r: 18)),
                const SizedBox(width: 10),
                Expanded(child: _ShimBox(h: 90, r: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimBox extends StatelessWidget {
  final double? w;
  final double h;
  final double r;
  const _ShimBox({this.w, required this.h, this.r = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }
}

// ─── Incoming Request Card ──────────────────────────────────────────
class _IncomingRequestCard extends ConsumerWidget {
  const _IncomingRequestCard();

  Future<double> _getRealDistance(Map<String, dynamic> req) async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
          final reqLat = (req['latitude'] as num?)?.toDouble() ?? 0.0;
          final reqLon = (req['longitude'] as num?)?.toDouble() ?? 0.0;
          return Geolocator.distanceBetween(pos.latitude, pos.longitude, reqLat, reqLon) / 1000.0;
        }
      }
    } catch (_) {}
    return (req['distanceKm'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(combinedActiveRequestsProvider);
    
    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        final req = requests.first;
        final blood = req['bloodGroup'] as String? ?? '?';
        final name = req['requesterName'] as String? ?? 'Unknown';

        return FutureBuilder<double>(
          future: _getRealDistance(req),
          builder: (context, snapshot) {
            final distance = (snapshot.data ?? (req['distanceKm'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(1);
            // inject updated distance into the req so the detail sheet shows the accurate one too
            final updatedReq = Map<String, dynamic>.from(req);
            if (snapshot.hasData) updatedReq['distanceKm'] = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) => _RecipientDetailsSheet(request: updatedReq),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.urgentRed.withOpacity(0.4)),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.urgentRed.withOpacity(0.15),
                        AppColors.darkCard,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.urgentRed.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.urgentRed,
                        ),
                        child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Emergency Request',
                              style: TextStyle(color: AppColors.urgentRed, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '$name needs $blood • ${distance}km away',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.1),
            );
          }
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ─── Recipient Details Sheet ───────────────────────────────────────
class _RecipientDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RecipientDetailsSheet({required this.request});

  @override
  Widget build(BuildContext context) {
    final blood = request['bloodGroup'] as String? ?? '?';
    final name = request['requesterName'] as String? ?? 'Unknown';
    final phone = request['requesterPhone'] as String? ?? 'N/A';
    final dist = (request['distanceKm'] as double? ?? 0.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.urgentRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.emergency_rounded, color: AppColors.urgentRed, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Emergency Details',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.person_rounded, 'Requester', name, AppColors.royalBlueLight),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.water_drop_rounded, 'Blood Group', blood, AppColors.crimson),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.phone_rounded, 'Contact', phone, AppColors.success),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.near_me_rounded, 'Distance', '$dist km away', AppColors.warning),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.urgentRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 3 — AI COACH
// ═══════════════════════════════════════════════════════════════════
class _AiCoachTab extends ConsumerStatefulWidget {
  const _AiCoachTab();

  @override
  ConsumerState<_AiCoachTab> createState() => _AiCoachTabState();
}

class _AiCoachTabState extends ConsumerState<_AiCoachTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      'Hi! I\'m your AI Health Coach. I can check your blood donation eligibility based on your recent health history.\n\nTell me: have you donated recently, or would you like me to ask you a few quick screening questions?',
      false,
    ),
  ];
  bool _isTyping = false;
  DateTime? _nextEligibleDate;
  GenerativeModel? _model;
  ChatSession? _chat;

  static const _systemPrompt = '''
You are a compassionate medical screener and diet coach for blood donation eligibility for LifeStream AI in India. 
Your job is to have a warm but professional conversation to determine if the user can donate blood today, and suggest dietary improvements.

Ask about (one at a time, naturally):
1. Date of last blood donation (if any)
2. Recent tattoos or piercings (within 6 months)
3. Any current medications (especially antibiotics)
4. Recent fever or illness (within 2 weeks)
5. Recent international travel to malaria-risk zones

Rules:
- If they donated blood less than 90 days ago, they are INELIGIBLE. Tell them the exact next eligible date.
- If they have a recent tattoo/piercing, INELIGIBLE for 6 months.
- If on antibiotics, INELIGIBLE until course ends.
- If they had fever in last 2 weeks, INELIGIBLE.
- Always be encouraging and warm, even when ineligible.
- If INELIGIBLE or recovering, suggest 2-3 local Indian dietary items to build hemoglobin (e.g., Jaggery (Gur), Beetroot, Spinach (Palak), Pomegranate).
- When they mention a last donation date, detect it and respond with the next eligible date.
- Keep responses SHORT (2-4 sentences max).
- When concluding eligibility, use the word ELIGIBLE or INELIGIBLE in capital letters.
''';


  @override
  void initState() {
    super.initState();
    _initGemini();
  }

  void _initGemini() {
    if (_kGeminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') return;
    try {
      _model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: _kGeminiApiKey,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 300,
        ),
      );
      _chat = _model!.startChat();
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();

    String reply;
    if (_kGeminiApiKey == 'YOUR_GEMINI_API_KEY_HERE' || _chat == null) {
      await Future.delayed(const Duration(milliseconds: 800));
      reply =
          '⚠️ Gemini API key not configured. Please add your key to enable AI coaching. Visit https://aistudio.google.com to get a free key.';
    } else {
      try {
        final response = await _chat!.sendMessage(Content.text(text));
        reply = response.text ?? 'Sorry, I couldn\'t process that.';
        // Try to detect next eligible date from reply
        _parseEligibilityDate(reply);
      } catch (e) {
        print('Gemini API Error (Donor): $e');
        reply = 'Error: $e';
      }
    }

    if (mounted) {
      setState(() {
        _messages.add(_ChatMessage(reply, false));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _parseEligibilityDate(String text) {
    // Simple heuristic: look for "INELIGIBLE" and extract dates
    if (text.toUpperCase().contains('INELIGIBLE')) {
      // Try to find "next eligible" date pattern — fallback to 90 days from now
      final candidate = DateTime.now().add(const Duration(days: 90));
      setState(() => _nextEligibleDate = candidate);
    } else if (text.toUpperCase().contains('ELIGIBLE')) {
      setState(() => _nextEligibleDate = null);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A18), Color(0xFF060F1E)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: AppColors.cardGradient),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.royalBlue.withOpacity(0.4),
                            blurRadius: 12)
                      ],
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Health Coach',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text('Powered by Gemini 1.5 Flash',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            // Next eligible date banner
            if (_nextEligibleDate != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: AppColors.crimsonGradient),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Next Hero Date: ${_nextEligibleDate!.day} '
                          '${_monthName(_nextEligibleDate!.month)} '
                          '${_nextEligibleDate!.year}  '
                          '(${_daysUntil(_nextEligibleDate!)} days)',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Divider
            const Divider(color: AppColors.glassBorder, height: 1),

            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _TypingBubble();
                  }
                  final msg = _messages[index];
                  return _ChatBubble(message: msg);
                },
              ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
                color: AppColors.darkSurface,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Ask about your eligibility...',
                          hintStyle: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _isTyping ? null : _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: AppColors.cardGradient),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.royalBlue.withOpacity(0.4),
                              blurRadius: 8)
                        ],
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];

  int _daysUntil(DateTime d) =>
      d.difference(DateTime.now()).inDays.clamp(0, 999);
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft:
                Radius.circular(message.isUser ? 18 : 4),
            bottomRight:
                Radius.circular(message.isUser ? 4 : 18),
          ),
          gradient: message.isUser
              ? const LinearGradient(colors: AppColors.cardGradient)
              : null,
          color: message.isUser
              ? null
              : Colors.white.withOpacity(0.07),
          border: message.isUser
              ? null
              : Border.all(color: AppColors.glassBorder),
        ),
        child: Text(
          message.text,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14, height: 1.5),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }
}

class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.royalBlueLight),
            )
                .animate(onPlay: (c) => c.repeat())
                .moveY(
                  begin: 0,
                  end: -6,
                  duration: 500.ms,
                  delay: Duration(milliseconds: i * 120),
                  curve: Curves.easeInOut,
                )
                .then()
                .moveY(begin: -6, end: 0, duration: 500.ms);
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 4 — REQUEST HISTORY
// ═══════════════════════════════════════════════════════════════════
class _DonorRequestsTab extends ConsumerStatefulWidget {
  const _DonorRequestsTab();

  @override
  ConsumerState<_DonorRequestsTab> createState() => _DonorRequestsTabState();
}

class _DonorRequestsTabState extends ConsumerState<_DonorRequestsTab> {
  String _statusFilter = 'All';
  String _urgencyFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(donorRequestHistoryProvider);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A18), Color(0xFF0D1426)],
        ),
      ),
      child: SafeArea(
        child: requestsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.heroGreen)),
          error: (e, _) =>
              Center(child: Text('$e', style: const TextStyle(color: AppColors.error))),
          data: (requests) {
            final filtered = requests.where((request) {
              final status =
                  (request['status'] as String? ?? 'pending').toLowerCase();
              final urgency = (request['urgency'] as String? ?? 'MEDIUM').toUpperCase();
              final statusMatches = _statusFilter == 'All' ||
                  status == _statusFilter.toLowerCase();
              final urgencyMatches =
                  _urgencyFilter == 'All' || urgency == _urgencyFilter;
              return statusMatches && urgencyMatches;
            }).toList();

            if (requests.isEmpty) {
              return const Center(
                child: Text(
                  'No request history available',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HistoryFilterDropdown(
                          label: 'Status',
                          value: _statusFilter,
                          options: const ['All', 'Pending', 'Accepted', 'Completed'],
                          onChanged: (value) =>
                              setState(() => _statusFilter = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HistoryFilterDropdown(
                          label: 'Urgency',
                          value: _urgencyFilter,
                          options: const ['All', 'CRITICAL', 'HIGH', 'MEDIUM'],
                          onChanged: (value) =>
                              setState(() => _urgencyFilter = value),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No requests for selected filters',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) =>
                              _DonorRequestCard(request: filtered[index]),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemCount: filtered.length,
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryFilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _HistoryFilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppColors.darkSurface,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.royalBlueLight),
        ),
      ),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      items: options
          .map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt)))
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _DonorRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  const _DonorRequestCard({required this.request});

  @override
  State<_DonorRequestCard> createState() => _DonorRequestCardState();
}

class _DonorRequestCardState extends State<_DonorRequestCard> {
  bool _accepting = false;
  bool _markingDone = false;
  bool _openingPdf = false;
  bool _downloadingPdf = false;

  Future<void> _acceptRequest() async {
    final requestId = widget.request['id'] as String?;
    if (requestId == null) return;
    setState(() => _accepting = true);
    try {
      await FirebaseFirestore.instance.collection('blood_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedByDonorId': FirebaseAuth.instance.currentUser?.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
        'donorId': FirebaseAuth.instance.currentUser?.uid,
        'donorCompleted': false,
        'recipientCompleted': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request accepted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to accept request: $e')));
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _markCompleted() async {
    final requestId = widget.request['id'] as String?;
    if (requestId == null) return;
    setState(() => _markingDone = true);
    try {
      await RequestCompletionService.donorMarkCompleted(requestId);
      if (!mounted) return;

      final doc = await FirebaseFirestore.instance.collection('blood_requests').doc(requestId).get();
      final updatedPdfUrl = doc.data()?['completionPdfUrl'] as String?;

      if (!mounted) return;

      if (updatedPdfUrl != null && updatedPdfUrl.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Donation completed! Opening certificate...')),
        );
        _openPdf(updatedPdfUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked complete! Waiting for recipient\'s confirmation to generate PDF.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to mark completed: $e')));
    } finally {
      if (mounted) setState(() => _markingDone = false);
    }
  }

  Future<void> _openPdf(String url) async {
    setState(() => _openingPdf = true);
    try {
      await PdfActions.viewPdfFromUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to open PDF: $e')));
    } finally {
      if (mounted) setState(() => _openingPdf = false);
    }
  }

  Future<void> _downloadPdf(String url, String requestId) async {
    setState(() => _downloadingPdf = true);
    try {
      final savedPath = await PdfActions.downloadPdfFromUrl(
        url: url,
        fileName: 'LifeStream_Completion_$requestId.pdf',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF downloaded: ${p.basename(savedPath)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to download PDF: $e')));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final status = (request['status'] as String? ?? 'pending').toLowerCase();
    final requesterName = request['requesterName'] as String? ?? 'Unknown';
    final bloodGroup = request['bloodGroup'] as String? ?? '-';
    final urgency = request['urgency'] as String? ?? 'NORMAL';
    final donorCompleted = request['donorCompleted'] == true;
    final recipientCompleted = request['recipientCompleted'] == true;
    final pdfUrl = request['completionPdfUrl'] as String?;
    final requestId = request['id'] as String? ?? 'request';

    Color statusColor() {
      switch (status) {
        case 'accepted':
          return AppColors.warning;
        case 'completed':
          return AppColors.success;
        default:
          return AppColors.royalBlueLight;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  requesterName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor().withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor().withOpacity(0.4)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Blood Group: $bloodGroup  •  Urgency: $urgency',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            'Donor confirmation: ${donorCompleted ? 'Done' : 'Pending'}  |  Recipient confirmation: ${recipientCompleted ? 'Done' : 'Pending'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _accepting ? null : _acceptRequest,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.royalBlue),
                child: _accepting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Accept Request'),
              ),
            ),
          ],
          if (status == 'accepted' && !donorCompleted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _markingDone ? null : _markCompleted,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
                child: _markingDone
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Mark Donation Completed'),
              ),
            ),
          ],
          if (pdfUrl != null && pdfUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openingPdf ? null : () => _openPdf(pdfUrl),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: Text(_openingPdf ? 'Opening...' : 'View PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloadingPdf
                        ? null
                        : () => _downloadPdf(pdfUrl, requestId),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(_downloadingPdf ? 'Saving...' : 'Download'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 5 — DONOR CARD
// ═══════════════════════════════════════════════════════════════════
class _DonorCardTab extends ConsumerWidget {
  const _DonorCardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(donorProfileStreamProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A18), Color(0xFF0D1426)],
        ),
      ),
      child: SafeArea(
        child: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.heroGreen)),
          error: (e, _) => Center(
              child: Text('$e',
                  style: const TextStyle(color: AppColors.error))),
          data: (data) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final name = data?['fullName'] as String? ?? 'Hero';
            final blood = data?['bloodGroup'] as String? ?? '?';
            final donations = data?['donationCount'] as int? ?? 0;
            final lives = data?['livesSaved'] as int? ?? 0;
            final level = _DonorLevel.get(donations);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Donor Identity',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 6),
                          Text('Tap card to flip for QR code',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                      if (data?['isEmailVerifiedViaOtp'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.royalBlueLight.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.royalBlueLight.withOpacity(0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_rounded, color: AppColors.royalBlueLight, size: 14),
                              SizedBox(width: 4),
                              Text('Verified', style: TextStyle(color: AppColors.royalBlueLight, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            final email = user?.email ?? data?['email'] as String?;
                            if (email != null && email.isNotEmpty) {
                              EmailOtpSheet.show(context, email);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No email found for this profile.')),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.mark_email_unread_rounded, color: AppColors.warning, size: 14),
                                SizedBox(width: 4),
                                Text('Verify Email', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Flip Card
                  FlipCard(
                    direction: FlipDirection.HORIZONTAL,
                    front: _CardFront(
                        name: name,
                        blood: blood,
                        donations: donations,
                        lives: lives,
                        level: level,
                        data: data),
                    back: _CardBack(uid: uid, name: name, blood: blood),
                  ).animate().fadeIn(delay: 100.ms).scale(
                      begin: const Offset(0.9, 0.9),
                      curve: Curves.easeOutBack),

                  const SizedBox(height: 28),

                  // Level Progress
                  _LevelProgress(level: level, donations: donations),

                  const SizedBox(height: 24),

                  // Community & Trust
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.shield_rounded, color: AppColors.heroGreen, size: 18),
                                  SizedBox(width: 6),
                                  Text('Trust Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text('12 Vouches', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(4, (index) => Align(
                                  widthFactor: 0.7,
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: AppColors.darkSurface,
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=\${index + 10}'),
                                    ),
                                  ),
                                )),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.groups_rounded, color: AppColors.royalBlueLight, size: 18),
                                  SizedBox(width: 6),
                                  Text('Community', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text('Delhi Tech Univ.', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('145 Active Donors', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  // Share hint
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.textMuted, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Show QR at donation centres for verification',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Download Certificate Button
                  if (donations > 0)
                    GestureDetector(
                      onTap: () async {
                        final file = await CertificateGenerator.generateDonorCertificate(
                          donorName: name,
                          bloodGroup: blood,
                          donationCount: donations,
                        );
                        await Printing.layoutPdf(onLayout: (_) => file.readAsBytesSync());
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(colors: AppColors.heroGreenGradient),
                          boxShadow: [
                            BoxShadow(color: AppColors.heroGreenGlow, blurRadius: 10)
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Download Hero Certificate',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Card Front ───────────────────────────────────────────────────
class _CardFront extends StatelessWidget {
  final String name, blood;
  final int donations, lives;
  final ({String label, Color color, double progress}) level;
  final Map<String, dynamic>? data;

  const _CardFront({
    required this.name,
    required this.blood,
    required this.donations,
    required this.lives,
    required this.level,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3A6B), Color(0xFF0A2245), Color(0xFF050A18)],
        ),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
              color: AppColors.royalBlue.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.royalBlue.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.crimson.withOpacity(0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bloodtype_rounded,
                        color: AppColors.crimson, size: 20),
                    const SizedBox(width: 6),
                    const Text('LifeStream AI',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: level.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: level.color.withOpacity(0.5)),
                      ),
                      child: Text(level.label,
                          style: TextStyle(
                              color: level.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Spacer(),
                // Profile photo
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: AppColors.crimsonGradient),
                        image: data?['profileImageUrl'] != null
                            ? DecorationImage(
                                image: NetworkImage(
                                    data!['profileImageUrl'] as String),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: data?['profileImageUrl'] == null
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white, size: 24)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          Text('Hero Donor',
                              style: TextStyle(
                                  color: AppColors.textSecondary.withOpacity(0.7),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    // Blood group
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                            colors: AppColors.crimsonGradient),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.crimson.withOpacity(0.4),
                              blurRadius: 10)
                        ],
                      ),
                      child: Center(
                        child: Text(blood,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(value: '$donations', label: 'Donations'),
                    const SizedBox(width: 20),
                    _MiniStat(value: '$lives', label: 'Lives Saved'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value, label;
  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

// ─── Card Back (QR) ───────────────────────────────────────────────
class _CardBack extends StatelessWidget {
  final String uid, name, blood;
  const _CardBack(
      {required this.uid, required this.name, required this.blood});

  @override
  Widget build(BuildContext context) {
    final qrData = 'lifestream://donor?uid=$uid&name=$name&blood=$blood';
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 110,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF050A18),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF050A18),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Scan to verify identity',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─── Level Progress ───────────────────────────────────────────────
class _LevelProgress extends StatelessWidget {
  final ({String label, Color color, double progress}) level;
  final int donations;

  const _LevelProgress({required this.level, required this.donations});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: level.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.military_tech_rounded,
                  color: level.color, size: 22),
              const SizedBox(width: 10),
              Text(level.label,
                  style: TextStyle(
                      color: level.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$donations donations',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: level.progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(level.color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _levelCaption(level.label, level.progress),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  String _levelCaption(String label, double p) {
    if (p >= 1.0) return '🎉 Maximum level reached! You\'re a Platinum Hero.';
    final pct = (p * 100).toInt();
    return '$pct% progress to next level — Keep saving lives!';
  }
}
