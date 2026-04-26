import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';

class DonorProfileSheet extends StatefulWidget {
  final Map<String, dynamic> donor;

  const DonorProfileSheet({super.key, required this.donor});

  @override
  State<DonorProfileSheet> createState() => _DonorProfileSheetState();
}

class _DonorProfileSheetState extends State<DonorProfileSheet> {
  bool _isRequesting = false;
  static const List<String> _urgencyOptions = ['CRITICAL', 'HIGH', 'MEDIUM'];

  String? get _recipientId => FirebaseAuth.instance.currentUser?.uid;
  String? get _donorId => widget.donor['id'] as String?;

  Stream<QuerySnapshot<Map<String, dynamic>>> _requestStateStream() {
    final recipientId = _recipientId;
    final donorId = _donorId;
    if (recipientId == null || donorId == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('blood_requests')
        .where('recipientId', isEqualTo: recipientId)
        .where('donorId', isEqualTo: donorId)
        .snapshots();
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _whatsapp(String phone) async {
    // Remove non-digit characters
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _requestBlood() async {
    final recipientId = _recipientId;
    final donorId = _donorId;

    if (recipientId == null || donorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Missing user information.')),
      );
      return;
    }

    final selectedUrgency = await _pickUrgencyType();
    if (selectedUrgency == null) return;

    final existing = await FirebaseFirestore.instance
        .collection('blood_requests')
        .where('recipientId', isEqualTo: recipientId)
        .where('donorId', isEqualTo: donorId)
        .get();

    if (existing.docs.isNotEmpty) {
      final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(existing.docs)
        ..sort((a, b) {
          final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
      final currentStatus =
          (sortedDocs.first.data()['status'] as String? ?? 'pending')
              .toUpperCase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Already requested ($currentStatus).')),
      );
      return;
    }

    setState(() => _isRequesting = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(recipientId).get();
      final data = doc.data() ?? {};

      await FirebaseFirestore.instance.collection('blood_requests').add({
        'recipientId': recipientId,
        'requesterId': recipientId,
        'donorId': donorId,
        'status': 'pending',
        'urgency': selectedUrgency,
        'donorCompleted': false,
        'recipientCompleted': false,
        'bloodGroup': data['bloodGroup'] ?? 'Unknown',
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'requesterName': data['fullName'] ?? 'Someone',
        'requesterPhone': data['phoneNumber'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isRequesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blood request sent! The donor will be notified.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRequesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  Future<String?> _pickUrgencyType() async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select urgency type',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ..._urgencyOptions.map(
                  (urgency) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      urgency,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                    onTap: () => Navigator.of(context).pop(urgency),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.donor['fullName'] as String? ?? 'Donor';
    final age = widget.donor['age']?.toString();
    final bloodGroup = widget.donor['bloodGroup'] as String? ?? '';
    final city = widget.donor['city'] as String? ?? '';
    final address = widget.donor['address'] as String? ?? '';
    final phone = widget.donor['phoneNumber'] as String? ?? '';
    final imageUrl = widget.donor['profileImageUrl'] as String?;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Donor Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Profile Image
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: AppColors.crimsonGradient),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.crimson.withOpacity(0.5),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(color: AppColors.crimson.withOpacity(0.5), width: 3),
                    image: imageUrl != null && imageUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl == null || imageUrl.isEmpty
                      ? const Icon(Icons.person_rounded, color: Colors.white, size: 64)
                      : null,
                ),
              ],
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),

            const SizedBox(height: 20),

            // Name + Age
            Text(
              age != null ? '$name, $age' : name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 12),

            // Blood Group badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.crimsonGradient),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.crimson.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    bloodGroup,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: 36),

            // Details card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.location_on_rounded,
                      label: 'City',
                      value: city,
                      iconColor: AppColors.royalBlue,
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.home_outlined,
                        label: 'Address',
                        value: address,
                        iconColor: AppColors.royalBlueLight,
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: phone,
                        iconColor: AppColors.success,
                      ),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

            const SizedBox(height: 28),

            // Action buttons
            if (phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Call
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _callPhone(phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: AppColors.crimsonGradient),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.crimson.withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.call_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Call',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // WhatsApp
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _whatsapp(phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'WhatsApp',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _requestStateStream(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final hasRequested = docs.isNotEmpty;
              String? status;
              if (hasRequested) {
                final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
                  ..sort((a, b) {
                    final aTime = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final bTime = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return bTime.compareTo(aTime);
                  });
                status = (sortedDocs.first.data()['status'] as String? ?? 'pending').toUpperCase();
              }
              return GestureDetector(
                onTap: (_isRequesting || hasRequested) ? null : _requestBlood,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: hasRequested
                        ? const LinearGradient(
                            colors: [Color(0xFF3A3A3A), Color(0xFF525252)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: (hasRequested
                                ? Colors.black
                                : AppColors.crimson)
                            .withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Center(
                    child: _isRequesting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasRequested
                                    ? Icons.check_circle_rounded
                                    : Icons.favorite_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                hasRequested
                                    ? 'REQUESTED (${status ?? 'PENDING'})'
                                    : 'REQUEST BLOOD FROM DONOR',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5);
            },
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
