import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/otp_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  int _step = 0; // 0 = send OTP, 1 = enter OTP
  String _generatedOtp = "";
  final _otpController = TextEditingController();
  bool _isLoading = false;

  void _sendOtp() async {
    setState(() => _isLoading = true);
    
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered email found.'), backgroundColor: AppColors.error),
      );
      return;
    }

    // Generate a 6 digit random OTP
    _generatedOtp = (100000 + Random().nextInt(900000)).toString();
    
    final success = await OtpService.sendOtp(email, _generatedOtp);
    
    if (success) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _step = 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to your email successfully!')),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send OTP. Try again later.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _verifyOtp() async {
    if (_otpController.text.trim() != _generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Please check your email and try again.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Mark as verified in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isEmailVerifiedViaOtp': true,
      });
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email Verified Successfully! ✅'),
          backgroundColor: AppColors.heroGreen,
        ),
      );
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.heroGradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
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
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.royalBlueLight.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_read_rounded, 
                            color: AppColors.royalBlueLight, 
                            size: 48
                          ),
                        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                        
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Email Verification',
                          style: TextStyle(
                            color: AppColors.textPrimary, 
                            fontSize: 24, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        const Text(
                          'Secure your account with OTP authentication',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                        
                        const SizedBox(height: 36),
                        
                        if (_step == 0) ...[
                          const Text(
                            'We will send a 6-digit OTP to your registered email address.', 
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4)
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.royalBlue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ).animate().fadeIn(delay: 200.ms),
                        ] else ...[
                          const Text(
                            'Enter the 6-digit OTP sent to your email', 
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 15)
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 8, fontSize: 22, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: const TextStyle(color: AppColors.textMuted, letterSpacing: 8),
                              filled: true,
                              fillColor: AppColors.darkBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.glassBorder),
                              ),
                              counterText: '',
                            ),
                          ).animate().fadeIn().slideX(),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.heroGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _isLoading ? null : () => setState(() => _step = 0),
                            child: const Text('Resend Code', style: TextStyle(color: AppColors.royalBlueLight, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
