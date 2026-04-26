import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';

class EmergencyOverlay extends StatefulWidget {
  final Map<String, dynamic> request;

  const EmergencyOverlay({super.key, required this.request});

  @override
  State<EmergencyOverlay> createState() => _EmergencyOverlayState();
}

class _EmergencyOverlayState extends State<EmergencyOverlay>
    with SingleTickerProviderStateMixin {
  int _seconds = 60;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_seconds <= 1) {
        _timer?.cancel();
        if (mounted) Navigator.of(context).pop(false);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _accept() {
    _timer?.cancel();
    Navigator.of(context).pop(true);
  }

  void _decline() {
    _timer?.cancel();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final blood = widget.request['bloodGroup'] as String? ?? '?';
    final urgency = widget.request['urgency'] as String? ?? 'CRITICAL';
    final requester =
        widget.request['requesterName'] as String? ?? 'Unknown';
    final distance =
        (widget.request['distanceKm'] as double? ?? 0.0).toStringAsFixed(1);

    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.darkBg.withOpacity(0.88),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing SOS icon
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) {
                      return Transform.scale(
                        scale: 1.0 + _pulseController.value * 0.15,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: AppColors.crimsonGradient),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.crimson.withOpacity(0.6),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.emergency_rounded,
                          color: Colors.white, size: 52),
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 28),

                  // EMERGENCY title
                  const Text(
                    '🚨 EMERGENCY REQUEST',
                    style: TextStyle(
                      color: AppColors.urgentRed,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 8),
                  Text(
                    'A blood request matching your blood group is nearby!',
                    style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.8),
                        fontSize: 14),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 32),

                  // Info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: AppColors.urgentRed.withOpacity(0.4)),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.urgentRed.withOpacity(0.12),
                          AppColors.darkCard.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        _OverlayRow(
                          icon: Icons.water_drop_rounded,
                          label: 'Blood Group',
                          value: blood,
                          color: AppColors.crimson,
                        ),
                        const Divider(
                            color: AppColors.glassBorder, height: 24),
                        _OverlayRow(
                          icon: Icons.near_me_rounded,
                          label: 'Distance',
                          value: '${distance}km away',
                          color: AppColors.royalBlueLight,
                        ),
                        const Divider(
                            color: AppColors.glassBorder, height: 24),
                        _OverlayRow(
                          icon: Icons.warning_rounded,
                          label: 'Urgency',
                          value: urgency,
                          color: AppColors.urgentRed,
                        ),
                        const Divider(
                            color: AppColors.glassBorder, height: 24),
                        _OverlayRow(
                          icon: Icons.local_hospital_rounded,
                          label: 'Requester',
                          value: requester,
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                  const SizedBox(height: 28),

                  // Countdown
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) {
                      return Text(
                        'Auto-declining in $_seconds seconds',
                        style: TextStyle(
                          color: _seconds <= 10
                              ? AppColors.urgentRed
                              : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: _seconds <= 10
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      );
                    },
                  ),

                  // Countdown arc
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: _seconds / 60,
                      backgroundColor:
                          Colors.white.withOpacity(0.1),
                      color: _seconds <= 10
                          ? AppColors.urgentRed
                          : AppColors.warning,
                      strokeWidth: 4,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      // Decline
                      Expanded(
                        child: GestureDetector(
                          onTap: _decline,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: Colors.white.withOpacity(0.06),
                              border: Border.all(
                                  color: AppColors.glassBorder),
                            ),
                            child: const Center(
                              child: Text(
                                'Decline',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Accept
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _accept,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                  colors: AppColors.crimsonGradient),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.crimson.withOpacity(0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.directions_run_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Accept Hero Call",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _OverlayRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Column(
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}
