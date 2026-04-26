import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../recipient/presentation/recipient_dashboard_screen.dart';

class DonorHomeScreen extends ConsumerWidget {
  const DonorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(recipientDataProvider);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                                colors: AppColors.crimsonGradient),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.crimson.withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.bloodtype_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text('LifeStream AI',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        await GoogleSignIn().signOut();
                        if (context.mounted) {
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
                        child: const Icon(Icons.logout_rounded,
                            color: AppColors.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms),

                const SizedBox(height: 36),

                userDataAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.royalBlue),
                  ),
                  error: (e, _) => Text('Error: $e',
                      style: const TextStyle(color: AppColors.error)),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello,',
                        style: TextStyle(
                            color: AppColors.textPrimary.withOpacity(0.6),
                            fontSize: 16),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 4),
                      Text(
                        data?['fullName'] as String? ?? 'Donor! 🩸',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            height: 1.1),
                      ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2),

                      const SizedBox(height: 28),

                      // Profile card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: AppColors.glassBorder),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.10),
                                  Colors.white.withOpacity(0.04),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                // Profile photo
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                        colors: AppColors.crimsonGradient),
                                    boxShadow: [
                                      BoxShadow(
                                          color:
                                              AppColors.crimson.withOpacity(0.4),
                                          blurRadius: 16),
                                    ],
                                    image: data?['profileImageUrl'] != null
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                data!['profileImageUrl']
                                                    as String),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: data?['profileImageUrl'] == null
                                      ? const Icon(Icons.person_rounded,
                                          color: Colors.white, size: 38)
                                      : null,
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _InfoRow(
                                        icon: Icons.water_drop_rounded,
                                        label: 'Blood Group',
                                        value: data?['bloodGroup'] as String? ??
                                            'N/A',
                                        iconColor: AppColors.crimson,
                                      ),
                                      const SizedBox(height: 10),
                                      _InfoRow(
                                        icon: Icons.cake_outlined,
                                        label: 'Age',
                                        value: data?['age']?.toString() ?? 'N/A',
                                        iconColor: AppColors.royalBlue,
                                      ),
                                      const SizedBox(height: 10),
                                      _InfoRow(
                                        icon: Icons.location_on_rounded,
                                        label: 'City',
                                        value: data?['city'] as String? ?? 'N/A',
                                        iconColor: AppColors.royalBlueLight,
                                      ),
                                      const SizedBox(height: 10),
                                      _InfoRow(
                                        icon: Icons.phone_rounded,
                                        label: 'Phone',
                                        value:
                                            data?['phoneNumber'] as String? ??
                                                'N/A',
                                        iconColor: AppColors.success,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(
                          begin: 0.2, curve: Curves.easeOut),

                      const SizedBox(height: 24),

                      // Address card
                      if ((data?['address'] as String? ?? '').isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: AppColors.glassBorder),
                                color: Colors.white.withOpacity(0.06),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.royalBlue.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.home_outlined,
                                        color: AppColors.royalBlue, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Address',
                                            style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12)),
                                        const SizedBox(height: 2),
                                        Text(
                                          data?['address'] as String? ?? '',
                                          style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                      const SizedBox(height: 24),

                      // Active donor status card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: AppColors.crimsonGradient,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.crimson.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You are an Active Donor',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Recipients near you can see your profile on the map.',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
