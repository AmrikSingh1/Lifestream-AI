import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/verification_provider.dart';
import '../../donor/presentation/widgets/email_otp_sheet.dart';
import '../../donor/presentation/donor_dashboard_screen.dart';
import '../../recipient/presentation/recipient_dashboard_screen.dart';

final _homeRoleProvider = StreamProvider.autoDispose<String>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value('recipient');
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['role'] as String? ?? 'recipient');
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(_homeRoleProvider);
    final verifiedAsync = ref.watch(emailOtpVerifiedProvider);

    if (verifiedAsync.valueOrNull == false) {
      final email = FirebaseAuth.instance.currentUser?.email;
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
                      Icons.verified_user_rounded,
                      color: AppColors.warning,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Email verification required',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Verify your email via OTP to use donor and recipient features.',
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: email == null || email.isEmpty
                          ? null
                          : () => EmailOtpSheet.show(context, email),
                      child: const Text('Verify Email Now'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return roleAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF050A18),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0047AB)),
        ),
      ),
      error: (_, __) => const RecipientDashboardScreen(),
      data: (role) => role == 'donor'
          ? const DonorDashboardScreen()
          : const RecipientDashboardScreen(),
    );
  }
}
