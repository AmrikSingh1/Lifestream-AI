import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../auth/presentation/widgets/glassmorphic_input.dart';

class DonorOnboardingScreen extends ConsumerStatefulWidget {
  const DonorOnboardingScreen({super.key});

  @override
  ConsumerState<DonorOnboardingScreen> createState() =>
      _DonorOnboardingScreenState();
}

class _DonorOnboardingScreenState
    extends ConsumerState<DonorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

  final _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  String? _selectedBloodGroup;
  File? _profileImage;
  bool _isLoading = false;
  bool _locationCaptured = false;
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _autoDetectLocation();
  }

  Future<void> _autoDetectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        
        setState(() => _isLoading = true);
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _lat = pos.latitude;
            _lon = pos.longitude;
            _locationCaptured = true;
            _isLoading = false;
          });
          showSuccessSnackbar(context, 'Location auto-detected!');
        }
      }
    } catch (e) {
      debugPrint('Auto-detect location error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 600,
    );
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  Future<void> _captureLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) showErrorSnackbar(context, 'Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) showErrorSnackbar(context, 'Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _locationCaptured = true;
      });
      if (mounted) showSuccessSnackbar(context, 'Location captured!');
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Could not get location.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadPhoto(String uid) async {
    if (_profileImage == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images')
        .child('$uid.jpg');
    await ref.putFile(_profileImage!);
    return await ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedBloodGroup == null) {
      showErrorSnackbar(context, 'Please select your blood group');
      return;
    }
    if (!_locationCaptured || _lat == null || _lon == null) {
      showErrorSnackbar(context, 'Please provide your location to continue');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final imageUrl = await _uploadPhoto(uid);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'phoneNumber': _phoneController.text.trim(),
        'bloodGroup': _selectedBloodGroup,
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _lat,
        'longitude': _lon,
        'profileImageUrl': imageUrl,
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, 'Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 28),

                  // Header
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
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Donor Profile',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                          Text('Complete your profile to get discovered',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),

                  // Profile Photo
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                  colors: AppColors.crimsonGradient),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.crimson.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                              image: _profileImage != null
                                  ? DecorationImage(
                                      image: FileImage(_profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImage == null
                                ? const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 52)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.royalBlue,
                                border: Border.all(color: AppColors.darkBg, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms).scale(
                      begin: const Offset(0.8, 0.8),
                      curve: Curves.easeOutBack),

                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Tap to add profile photo',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ),

                  const SizedBox(height: 28),

                  // Form Card
                  ClipRRect(
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
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassmorphicInput(
                              label: 'Full Name',
                              hint: 'Your full name',
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              prefixIcon: const Icon(Icons.person_outline_rounded,
                                  color: AppColors.textSecondary, size: 20),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            GlassmorphicInput(
                              label: 'Age',
                              hint: 'e.g. 28',
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              prefixIcon: const Icon(Icons.cake_outlined,
                                  color: AppColors.textSecondary, size: 20),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                final age = int.tryParse(v.trim());
                                if (age == null || age < 18 || age > 65) {
                                  return 'Must be 18–65';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            GlassmorphicInput(
                              label: 'Phone Number',
                              hint: '+91 98765 43210',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              prefixIcon: const Icon(Icons.phone_rounded,
                                  color: AppColors.textSecondary, size: 20),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 20),

                            // Blood Group
                            const Text('Blood Group',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _bloodGroups.map((bg) {
                                final sel = _selectedBloodGroup == bg;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedBloodGroup = bg),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: sel
                                          ? const LinearGradient(
                                              colors: AppColors.crimsonGradient)
                                          : null,
                                      color: sel
                                          ? null
                                          : Colors.white.withOpacity(0.08),
                                      border: Border.all(
                                        color: sel
                                            ? Colors.transparent
                                            : AppColors.glassBorder,
                                      ),
                                    ),
                                    child: Text(bg,
                                        style: TextStyle(
                                          color: sel
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                          fontSize: 14,
                                          fontWeight: sel
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        )),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 20),
                            GlassmorphicInput(
                              label: 'City',
                              hint: 'e.g. Mumbai',
                              controller: _cityController,
                              textCapitalization: TextCapitalization.words,
                              prefixIcon: const Icon(Icons.location_city_rounded,
                                  color: AppColors.textSecondary, size: 20),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            GlassmorphicInput(
                              label: 'Full Address',
                              hint: 'Street, Area, Pincode',
                              controller: _addressController,
                              textCapitalization: TextCapitalization.sentences,
                              prefixIcon: const Icon(Icons.home_outlined,
                                  color: AppColors.textSecondary, size: 20),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),

                            const SizedBox(height: 20),

                            // Location button
                            GestureDetector(
                              onTap: _isLoading ? null : _captureLocation,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: _locationCaptured
                                      ? LinearGradient(colors: [
                                          Colors.green.shade700,
                                          Colors.green.shade500
                                        ])
                                      : const LinearGradient(
                                          colors: AppColors.cardGradient),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_locationCaptured
                                              ? Colors.green
                                              : AppColors.royalBlue)
                                          .withOpacity(0.3),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _locationCaptured
                                          ? Icons.check_circle_rounded
                                          : Icons.my_location_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _locationCaptured
                                          ? 'Location Captured ✓'
                                          : 'Use My Current Location',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(
                      begin: 0.2, curve: Curves.easeOut),

                  const SizedBox(height: 28),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32)),
                        disabledBackgroundColor:
                            AppColors.royalBlue.withOpacity(0.5),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: const LinearGradient(
                            colors: AppColors.crimsonGradient,
                          ),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.volunteer_activism_rounded,
                                        color: Colors.white, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      'Save & Start Donating',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

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
