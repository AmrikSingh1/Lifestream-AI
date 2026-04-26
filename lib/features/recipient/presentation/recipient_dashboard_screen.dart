import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/verification_provider.dart';
import '../../../../core/services/request_completion_service.dart';
import '../../../../core/utils/pdf_actions.dart';
import '../../../../core/router/app_router.dart';
import '../../donor/presentation/widgets/email_otp_sheet.dart';
import '../../home/presentation/donor_profile_sheet.dart';

// ─── Gemini API Key ───────────────────────────────────────────────
const _kGeminiApiKey = 'AIzaSyBJT8MepIEQzfQTtpH5SgLefPDVefX2ZuI';

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);
}

// ─── Providers ───────────────────────────────────────────────────
final donorsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final recipientData = await ref.watch(recipientDataProvider.future);
  final recipientBg = recipientData?['bloodGroup'] as String? ?? '';

  final stream = FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'donor')
      .where('onboardingComplete', isEqualTo: true)
      .snapshots();

  await for (final snap in stream) {
    yield snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((u) => u['latitude'] != null && u['longitude'] != null)
        .where((u) {
          final donorBg = u['bloodGroup'] as String? ?? '';
          if (recipientBg.isEmpty) return true; // If somehow missing, show all
          if (donorBg == recipientBg) return true;
          if (donorBg == 'O+' || donorBg == 'O-') return true;
          return false;
        })
        .toList();
  }
});

final recipientDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.exists ? doc.data() : null;
});

final recipientRequestHistoryProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('blood_requests')
      .snapshots()
      .map((snap) {
        final list = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((request) {
              final requesterId = request['requesterId'] as String?;
              final recipientId = request['recipientId'] as String?;
              return requesterId == uid || recipientId == uid;
            })
            .toList();
        list.sort((a, b) {
          final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
        return list;
      });
});

// ─── Screen ──────────────────────────────────────────────────────
class RecipientDashboardScreen extends ConsumerStatefulWidget {
  const RecipientDashboardScreen({super.key});

  @override
  ConsumerState<RecipientDashboardScreen> createState() => _RecipientDashboardScreenState();
}

class _RecipientDashboardScreenState extends ConsumerState<RecipientDashboardScreen> {
  int _tab = 0;

  void _handleProfileUpdated() {
    ref.invalidate(recipientDataProvider);
    ref.invalidate(donorsStreamProvider);
    setState(() => _tab = 0);
  }

  @override
  Widget build(BuildContext context) {
    final verifiedAsync = ref.watch(emailOtpVerifiedProvider);
    if (verifiedAsync.valueOrNull == false) {
      return const _RecipientVerificationGateView();
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: IndexedStack(
        index: _tab,
        children: [
          _RecipientHomeTab(),
          _AiCoachTab(),
          const _RecipientRequestsTab(),
          _RecipientProfileTab(onProfileUpdated: _handleProfileUpdated),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _RecipientVerificationGateView extends ConsumerWidget {
  const _RecipientVerificationGateView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipientAsync = ref.watch(recipientDataProvider);
    final email = FirebaseAuth.instance.currentUser?.email ??
        (recipientAsync.valueOrNull?['email'] as String?);

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
                  const Icon(Icons.verified_user_rounded,
                      color: AppColors.warning, size: 44),
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
                    'OTP verification is required before using recipient features.',
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

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.dashboard_rounded, label: 'Home'),
      (icon: Icons.psychology_rounded, label: 'AI Health'),
      (icon: Icons.history_rounded, label: 'Requests'),
      (icon: Icons.person_rounded, label: 'Profile'),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.only(
                      right: i == items.length - 1 ? 0 : 8,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: selected
                          ? const LinearGradient(colors: AppColors.crimsonGradient)
                          : null,
                      boxShadow: selected
                          ? [BoxShadow(color: AppColors.crimson.withOpacity(0.4), blurRadius: 12)]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon,
                            color: selected ? Colors.white : AppColors.textMuted,
                            size: 22),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
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

// ─── HOME TAB (MAP + DASHBOARD) ──────────────────────────────────
class _RecipientHomeTab extends ConsumerStatefulWidget {
  const _RecipientHomeTab();

  @override
  ConsumerState<_RecipientHomeTab> createState() => _RecipientHomeTabState();
}

class _RecipientHomeTabState extends ConsumerState<_RecipientHomeTab> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<Map<String, dynamic>>? _lastDonorsList;
  List<Map<String, dynamic>> _nearbyDonors = [];
  int _nearbyCount = 0;
  LatLng _initialPosition = const LatLng(20.5937, 78.9629); // India center
  bool _locationLoaded = false;
  static const List<String> _urgencyOptions = ['CRITICAL', 'HIGH', 'MEDIUM'];

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are disabled. Requesting permission won't help until they turn it on.
        // We continue to check permissions anyway in case the OS lies or they turn it on immediately.
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return; // Permanently denied, cannot ask again
      }
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        if (mounted) {
          setState(() {
            _initialPosition = LatLng(pos.latitude, pos.longitude);
            _locationLoaded = true;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 12));
          // Re-evaluate markers with the new origin constraint
          if (_lastDonorsList != null) {
            _buildMarkers(_lastDonorsList!);
          }
        }
      }
    } catch (e) {
      debugPrint('Location init error: $e');
    }
  }

  Future<void> _buildMarkers(List<Map<String, dynamic>> donors) async {
    final newMarkers = <Marker>{};
    final filteredNearbyDonors = <Map<String, dynamic>>[];
    int nearby = 0;

    for (final donor in donors) {
      final lat = (donor['latitude'] as num?)?.toDouble();
      final lon = (donor['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final donorCopy = Map<String, dynamic>.from(donor);

      // 100km filtering
      if (_locationLoaded) {
        final distKm = Geolocator.distanceBetween(
              _initialPosition.latitude,
              _initialPosition.longitude,
              lat,
              lon,
            ) / 1000;
        if (distKm > 100) continue;
        donorCopy['distanceKm'] = distKm;
      } else {
        donorCopy['distanceKm'] = 0.0;
      }
      nearby++;
      filteredNearbyDonors.add(donorCopy);

      BitmapDescriptor icon;
      try {
        icon = await _buildDonorMarker(donor);
      } catch (_) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }

      newMarkers.add(Marker(
        markerId: MarkerId(donor['id'] as String),
        position: LatLng(lat, lon),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        onTap: () => _showDonorProfile(donor),
      ));
    }
    
    // Sort by real physical distance (Ascending)
    filteredNearbyDonors.sort((a, b) {
      final dA = a['distanceKm'] as double? ?? 0.0;
      final dB = b['distanceKm'] as double? ?? 0.0;
      return dA.compareTo(dB);
    });
    
    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
        _nearbyDonors = filteredNearbyDonors;
        _nearbyCount = nearby;
      });
    }
  }

  void _showDonorProfile(Map<String, dynamic> donor) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DonorProfileSheet(donor: donor)),
    );
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.crimson,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (mounted) {
        context.go(AppRoutes.onboarding);
      }
    }
  }

  void _openAllNearbyDonors() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NearbyDonorsListScreen(donors: _nearbyDonors),
      ),
    );
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
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
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
    final donorsAsync = ref.watch(donorsStreamProvider);
    final recipientAsync = ref.watch(recipientDataProvider);

    // Build markers safely without triggering infinite loop
    if (donorsAsync.value != null && _lastDonorsList != donorsAsync.value) {
      _lastDonorsList = donorsAsync.value;
      // Post-frame callback ensures we don't setState implicitly during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _buildMarkers(donorsAsync.value!);
      });
    }

    return Column(
      children: [
        // Top 70% Map Layer
        Expanded(
          flex: 7,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 11),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                mapType: MapType.normal,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _setDarkMapStyle(controller);
                  if (_locationLoaded) {
                    controller.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 12));
                  }
                },
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Top Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.darkBg.withOpacity(0.88),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.glassBorder),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12)
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: AppColors.crimsonGradient),
                                  ),
                                  child: const Icon(Icons.bloodtype_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 8),
                                const Text('LifeStream AI',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.3),
                          const Spacer(),
                          GestureDetector(
                            onTap: _confirmAndLogout,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.darkBg.withOpacity(0.88),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
                            ),
                          ).animate().fadeIn(delay: 100.ms),
                        ],
                      ),
                    ),
                    // Donor count chip
                    donorsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (donors) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.darkBg.withOpacity(0.88),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.glassBorder),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle, color: Colors.greenAccent),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_nearbyCount donor${_nearbyCount == 1 ? '' : 's'} nearby',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _openAllNearbyDonors,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.darkBg.withOpacity(0.88),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: AppColors.glassBorder),
                                ),
                                child: const Text(
                                  'View All',
                                  style: TextStyle(
                                    color: AppColors.royalBlueLight,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    if (_locationLoaded) {
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_initialPosition, 14));
                    } else {
                      _loadUserLocation();
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)
                      ],
                    ),
                    child: const Icon(Icons.my_location_rounded, color: AppColors.royalBlue, size: 22),
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ),
            ],
          ),
        ),
        
        // Bottom 30% Dashboard Layer
        Expanded(
          flex: 3,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF14080B), Color(0xFF050A18)],
              ),
              border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                )
              ]
            ),
            child: recipientAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.crimson)),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
              data: (data) => Column(
                children: [
                  // Profile Strip
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: AppColors.cardGradient),
                          image: data?['profileImageUrl'] != null
                              ? DecorationImage(
                                  image: NetworkImage(data!['profileImageUrl'] as String),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: data?['profileImageUrl'] == null
                            ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data?['fullName'] as String? ?? 'You',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Looking for ${data?['bloodGroup'] as String? ?? '?'} donors',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.crimsonGradient),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: AppColors.crimson.withOpacity(0.3), blurRadius: 8)
                          ]
                        ),
                        child: Text(
                          data?['bloodGroup'] as String? ?? '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14),
                        ),
                      ),
                    ],
                  ).animate().fadeIn().slideY(begin: 0.2),
                  
                  const Spacer(),
                  
                  // Emergency Request Button
                  GestureDetector(
                    onTap: () async {
                      if (_initialPosition.latitude == 20.5937 && _initialPosition.longitude == 78.9629 && !_locationLoaded) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please wait for location to load')),
                        );
                        return;
                      }
                      
                      final selectedUrgency = await _pickUrgencyType();
                      if (selectedUrgency == null) return;

                      try {
                        // Grab highly accurate fresh position if possible
                        Position? freshPos;
                        try {
                          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (serviceEnabled) {
                            freshPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
                          }
                        } catch (_) {}

                        final reqLat = freshPos?.latitude ?? _initialPosition.latitude;
                        final reqLon = freshPos?.longitude ?? _initialPosition.longitude;

                        await FirebaseFirestore.instance.collection('blood_requests').add({
                          'recipientId': FirebaseAuth.instance.currentUser?.uid,
                          'requesterId': FirebaseAuth.instance.currentUser?.uid,
                          'requesterName': data?['fullName'] ?? 'Unknown Recipient',
                          'requesterPhone': data?['phoneNumber'] ?? '',
                          'bloodGroup': data?['bloodGroup'] ?? 'O+',
                          'latitude': reqLat,
                          'longitude': reqLon,
                          'status': 'pending',
                          'urgency': selectedUrgency,
                          'donorCompleted': false,
                          'recipientCompleted': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Emergency request broadcasted successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Error broadcasting: $e')),
                           );
                         }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.crimson.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.campaign_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'EMERGENCY REQUEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _setDarkMapStyle(GoogleMapController controller) async {
    const style = '''[
      {"elementType":"geometry","stylers":[{"color":"#1a1c2e"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
      {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
      {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
      {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
      {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},
      {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
      {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
      {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
      {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
      {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
      {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
      {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
      {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
      {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
      {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
    ]''';
    controller.setMapStyle(style);
  }
}

// ─── AI COACH TAB ─────────────────────────────────────────────────
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
      'Hi! I\'m your AI Health Assistant. I can help answer questions about receiving blood, matching blood types, and recovery. How can I assist you today?',
      false,
    ),
  ];
  bool _isTyping = false;
  GenerativeModel? _model;
  ChatSession? _chat;

  static const _systemPrompt = '''
You are a compassionate medical assistant for blood recipients for LifeStream AI.
Your job is to have a warm, professional conversation with users who need blood or are recovering.
Answer questions about blood types, compatibility, post-transfusion care, and general health tips.
Keep responses SHORT (2-4 sentences max), clear, and encouraging.
Limit medical advice to general facts and always tell them to consult their doctor for specifics.
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
        generationConfig: GenerationConfig(temperature: 0.7, maxOutputTokens: 300),
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
      reply = '⚠️ Gemini API key not configured. Please add your key to enable AI coaching.';
    } else {
      try {
        final response = await _chat!.sendMessage(Content.text(text));
        reply = response.text ?? 'Sorry, I couldn\'t process that.';
      } catch (e) {
        print('Gemini API Error (Recipient): $e');
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
          colors: [Color(0xFF050A18), Color(0xFF14080B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: AppColors.crimsonGradient),
                      boxShadow: [
                        BoxShadow(color: AppColors.crimson.withOpacity(0.4), blurRadius: 12)
                      ],
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Health Assistant',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('Powered by Gemini 1.5 Flash',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const Divider(color: AppColors.glassBorder, height: 1),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) return _TypingBubble();
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                          bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                        ),
                        gradient: msg.isUser ? const LinearGradient(colors: AppColors.crimsonGradient) : null,
                        color: msg.isUser ? null : Colors.white.withOpacity(0.07),
                        border: msg.isUser ? null : Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(msg.text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
                },
              ),
            ),

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
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Ask about receiving blood...',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        gradient: const LinearGradient(colors: AppColors.crimsonGradient),
                        boxShadow: [BoxShadow(color: AppColors.crimson.withOpacity(0.4), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
}

class _RecipientProfileTab extends ConsumerStatefulWidget {
  final VoidCallback onProfileUpdated;
  const _RecipientProfileTab({required this.onProfileUpdated});

  @override
  ConsumerState<_RecipientProfileTab> createState() => _RecipientProfileTabState();
}

class _RecipientProfileTabState extends ConsumerState<_RecipientProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  bool _isEditMode = false;
  bool _capturingLocation = false;
  double? _profileLatitude;
  double? _profileLongitude;
  String _selectedBloodGroup = 'O+';

  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  void _seedFields(Map<String, dynamic>? data) {
    if (_initialized || data == null) return;
    _fullNameController.text = (data['fullName'] as String?) ?? '';
    _phoneController.text = (data['phoneNumber'] as String?) ?? '';
    _ageController.text = data['age']?.toString() ?? '';
    _cityController.text = (data['city'] as String?) ?? '';
    _addressController.text = (data['address'] as String?) ?? '';
    _profileLatitude = (data['latitude'] as num?)?.toDouble();
    _profileLongitude = (data['longitude'] as num?)?.toDouble();
    final bg = (data['bloodGroup'] as String?) ?? 'O+';
    _selectedBloodGroup = _bloodGroups.contains(bg) ? bg : 'O+';
    _initialized = true;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
        'bloodGroup': _selectedBloodGroup,
        'latitude': _profileLatitude,
        'longitude': _profileLongitude,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _isEditMode = false);
      widget.onProfileUpdated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _captureCurrentLocation() async {
    setState(() => _capturingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services first.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _profileLatitude = position.latitude;
        _profileLongitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location captured successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to capture location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _capturingLocation = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipientAsync = ref.watch(recipientDataProvider);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A18), Color(0xFF14080B)],
        ),
      ),
      child: SafeArea(
        child: recipientAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.crimson)),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
          ),
          data: (data) {
            _seedFields(data);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Profile',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _isEditMode = !_isEditMode),
                          icon: Icon(
                            _isEditMode ? Icons.close_rounded : Icons.edit_rounded,
                            color: AppColors.textPrimary,
                          ),
                          tooltip: _isEditMode ? 'Close edit mode' : 'Edit profile',
                        ),
                      ],
                    ),
                    Text(
                      _isEditMode
                          ? 'Edit your details and save changes.'
                          : 'Your profile details are in view mode. Tap pencil to edit.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    _profileInput(
                      controller: _fullNameController,
                      label: 'Full Name',
                      enabled: _isEditMode,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _profileInput(
                      controller: _phoneController,
                      label: 'Phone Number',
                      enabled: _isEditMode,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _profileInput(
                      controller: _ageController,
                      label: 'Age',
                      enabled: _isEditMode,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final age = int.tryParse((v ?? '').trim());
                        if (age == null || age <= 0) return 'Enter a valid age';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _profileInput(
                      controller: _cityController,
                      label: 'City',
                      enabled: _isEditMode,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'City is required' : null,
                    ),
                    const SizedBox(height: 12),
                    _profileInput(
                      controller: _addressController,
                      label: 'Address',
                      enabled: _isEditMode,
                      maxLines: 2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBloodGroup,
                      dropdownColor: AppColors.darkSurface,
                      decoration: _profileDecoration('Blood Group'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      items: _bloodGroups
                          .map(
                            (bg) => DropdownMenuItem<String>(
                              value: bg,
                              child: Text(bg),
                            ),
                          )
                          .toList(),
                      onChanged: _isEditMode
                          ? (value) {
                              if (value == null) return;
                              setState(() => _selectedBloodGroup = value);
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        _profileLatitude != null && _profileLongitude != null
                            ? 'Current Location: ${_profileLatitude!.toStringAsFixed(5)}, ${_profileLongitude!.toStringAsFixed(5)}'
                            : 'Current Location: Not captured',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_isEditMode) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _capturingLocation ? null : _captureCurrentLocation,
                          icon: const Icon(Icons.my_location_rounded),
                          label: Text(
                            _capturingLocation
                                ? 'Capturing location...'
                                : 'Capture Current Location',
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.crimson,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Profile',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _profileInput({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: !enabled,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: _profileDecoration(label),
      validator: validator,
    );
  }

  InputDecoration _profileDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      floatingLabelStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.8),
      ),
    );
  }
}

class _RecipientRequestsTab extends ConsumerStatefulWidget {
  const _RecipientRequestsTab();

  @override
  ConsumerState<_RecipientRequestsTab> createState() =>
      _RecipientRequestsTabState();
}

class _RecipientRequestsTabState extends ConsumerState<_RecipientRequestsTab> {
  String _statusFilter = 'All';
  String _urgencyFilter = 'All';

  Future<void> _refreshRequests() async {
    ref.invalidate(recipientRequestHistoryProvider);
    await ref.read(recipientRequestHistoryProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(recipientRequestHistoryProvider);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A18), Color(0xFF14080B)],
        ),
      ),
      child: SafeArea(
        child: historyAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppColors.crimson)),
          error: (e, _) => Center(
            child: Text('Error: $e', style: const TextStyle(color: AppColors.error)),
          ),
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
                  'No requests yet',
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
                        child: _FilterDropdown(
                          label: 'Status',
                          value: _statusFilter,
                          options: const ['All', 'Pending', 'Accepted', 'Completed'],
                          onChanged: (value) =>
                              setState(() => _statusFilter = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FilterDropdown(
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
                  child: RefreshIndicator(
                    onRefresh: _refreshRequests,
                    color: AppColors.crimson,
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 220),
                              Center(
                                child: Text(
                                  'No requests for selected filters',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (context, index) =>
                                _RecipientRequestCard(request: filtered[index]),
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemCount: filtered.length,
                          ),
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

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({
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

class _RecipientRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  const _RecipientRequestCard({required this.request});

  @override
  State<_RecipientRequestCard> createState() => _RecipientRequestCardState();
}

class _RecipientRequestCardState extends State<_RecipientRequestCard> {
  bool _markingDone = false;
  bool _openingPdf = false;
  bool _downloadingPdf = false;
  String? _donorName;

  @override
  void initState() {
    super.initState();
    _fetchDonorName();
  }

  Future<void> _fetchDonorName() async {
    final donorId = widget.request['donorId'] as String?;
    if (donorId == null || donorId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(donorId).get();
      if (doc.exists && mounted) {
        setState(() {
          _donorName = doc.data()?['fullName'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _markCompleted() async {
    final requestId = widget.request['id'] as String?;
    if (requestId == null) return;
    setState(() => _markingDone = true);
    try {
      await RequestCompletionService.recipientMarkCompleted(requestId);
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
          const SnackBar(content: Text('Completion confirmed! Waiting for donor\'s confirmation to generate PDF.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to confirm completion: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _markingDone = false);
      }
    }
  }

  Future<void> _openPdf(String url) async {
    setState(() => _openingPdf = true);
    try {
      await PdfActions.viewPdfFromUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _openingPdf = false);
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download PDF: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingPdf = false);
      }
    }
  }

  void _openRequestDetails() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RequestDetailsSheet(request: widget.request),
    );
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

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _openRequestDetails,
      child: Container(
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
                    _donorName != null ? 'Donor: $_donorName' : requesterName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
            Row(
              children: [
                Text(
                  'Blood Group: $bloodGroup',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _urgencyColor(urgency).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _urgencyColor(urgency).withOpacity(0.5)),
                  ),
                  child: Text(
                    urgency.toUpperCase(),
                    style: TextStyle(
                      color: _urgencyColor(urgency),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Donor confirmation: ${donorCompleted ? 'Done' : 'Pending'}  |  Recipient confirmation: ${recipientCompleted ? 'Done' : 'Pending'}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            if (status == 'accepted' && !recipientCompleted) ...[
              const SizedBox(height: 12),
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
                      : const Text('Confirm Donation Completed'),
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
      ),
    );
  }
}

Color _urgencyColor(String urgency) {
  switch (urgency.toUpperCase()) {
    case 'CRITICAL':
      return AppColors.error;
    case 'HIGH':
      return AppColors.warning;
    default:
      return AppColors.royalBlueLight;
  }
}

class _RequestDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> request;
  const _RequestDetailsSheet({required this.request});

  @override
  State<_RequestDetailsSheet> createState() => _RequestDetailsSheetState();
}

class _RequestDetailsSheetState extends State<_RequestDetailsSheet> {
  Map<String, dynamic>? _donorData;
  bool _loadingDonor = false;

  @override
  void initState() {
    super.initState();
    _fetchDonorData();
  }

  Future<void> _fetchDonorData() async {
    final donorId = widget.request['donorId'] as String?;
    if (donorId == null || donorId.isEmpty) return;
    
    if (mounted) setState(() => _loadingDonor = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(donorId).get();
      if (doc.exists && mounted) {
        setState(() {
          _donorData = doc.data();
          _loadingDonor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDonor = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final status = (request['status'] as String? ?? 'pending').toUpperCase();
    final urgency = (request['urgency'] as String? ?? 'MEDIUM').toUpperCase();
    final createdAt = (request['createdAt'] as Timestamp?)?.toDate();
    final lat = (request['latitude'] as num?)?.toDouble();
    final lng = (request['longitude'] as num?)?.toDouble();

    String formatDate(DateTime? date) {
      if (date == null) return 'N/A';
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Details',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            row('Requester', request['requesterName'] as String? ?? 'Unknown'),
            row('Phone', request['requesterPhone'] as String? ?? 'N/A'),
            row('Blood Group', request['bloodGroup'] as String? ?? '-'),
            row('Status', status),
            row('Urgency', urgency),
            row('Requested At', formatDate(createdAt)),
            row(
              'Location',
              lat != null && lng != null
                  ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                  : 'N/A',
            ),
            
            if (request['donorId'] != null && (request['donorId'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.glassBorder),
              const SizedBox(height: 12),
              const Text(
                'Donor Details',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingDonor)
                const Center(child: CircularProgressIndicator(color: AppColors.crimson))
              else if (_donorData != null) ...[
                row('Donor Name', _donorData!['fullName'] as String? ?? 'Unknown'),
                row('Donor Phone', _donorData!['phoneNumber'] as String? ?? 'N/A'),
                row('Donor Blood', _donorData!['bloodGroup'] as String? ?? '-'),
                row('Donor City', _donorData!['city'] as String? ?? 'N/A'),
                if ((_donorData!['address'] as String? ?? '').isNotEmpty)
                  row('Donor Address', _donorData!['address'] as String),
                if (_donorData!['latitude'] != null && _donorData!['longitude'] != null)
                  row(
                    'Donor Location',
                    '${(_donorData!['latitude'] as num).toStringAsFixed(5)}, ${(_donorData!['longitude'] as num).toStringAsFixed(5)}',
                  ),
              ] else
                const Text(
                  'Donor information unavailable',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NearbyDonorsListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> donors;
  const _NearbyDonorsListScreen({required this.donors});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Nearby Donors'),
      ),
      body: donors.isEmpty
          ? const Center(
              child: Text(
                'No nearby donors found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: donors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final donor = donors[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DonorProfileSheet(donor: donor)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.crimson,
                          backgroundImage: (donor['profileImageUrl'] as String?)?.isNotEmpty ==
                                  true
                              ? NetworkImage(donor['profileImageUrl'] as String)
                              : null,
                          child: (donor['profileImageUrl'] as String?)?.isNotEmpty == true
                              ? null
                              : const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                donor['fullName'] as String? ?? 'Donor',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                donor['city'] as String? ?? 'Unknown city',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.near_me_rounded, color: AppColors.royalBlueLight, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(donor['distanceKm'] as double? ?? 0.0).toStringAsFixed(1)} km away',
                                    style: const TextStyle(
                                      color: AppColors.royalBlueLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient:
                                const LinearGradient(colors: AppColors.crimsonGradient),
                          ),
                          child: Text(
                            donor['bloodGroup'] as String? ?? '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
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
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.crimson),
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

// ─── Map Marker Logic ─────────────────────────────────────────────
Future<BitmapDescriptor> _buildDonorMarker(Map<String, dynamic> donor) async {
  final name = (donor['fullName'] as String? ?? 'Donor').split(' ').first;
  final age = donor['age']?.toString() ?? '';
  final bloodGroup = donor['bloodGroup'] as String? ?? '';
  final imageUrl = donor['profileImageUrl'] as String?;

  const double size = 160;
  const double imgRadius = 44;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Shadow background circle
  final shadowPaint = Paint()
    ..color = AppColors.crimson.withOpacity(0.5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  canvas.drawCircle(const Offset(size / 2, imgRadius + 8), imgRadius + 4, shadowPaint);

  // Load and draw profile image or fallback
  if (imageUrl != null && imageUrl.isNotEmpty) {
    try {
      final data = (await NetworkAssetBundle(Uri.parse(imageUrl)).load(imageUrl))
          .buffer
          .asUint8List();
      final codec = await ui.instantiateImageCodec(data,
          targetWidth: (imgRadius * 2).toInt(),
          targetHeight: (imgRadius * 2).toInt());
      final frame = await codec.getNextFrame();
      final img = frame.image;

      // Clip to circle
      final clipPath = Path()
        ..addOval(Rect.fromCircle(
            center: Offset(size / 2, imgRadius + 4), radius: imgRadius));
      canvas.clipPath(clipPath);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCircle(
            center: Offset(size / 2, imgRadius + 4), radius: imgRadius),
        Paint(),
      );
      canvas.restore();
    } catch (_) {
      _drawFallbackAvatar(canvas, size, imgRadius);
    }
  } else {
    _drawFallbackAvatar(canvas, size, imgRadius);
  }

  // White ring border
  final borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  canvas.drawCircle(
      Offset(size / 2, imgRadius + 4), imgRadius, borderPaint);

  // Blood group chip
  final chipRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
        center: Offset(size / 2, imgRadius * 2 + 14),
        width: 52,
        height: 24),
    const Radius.circular(12),
  );
  canvas.drawRRect(
      chipRect,
      Paint()
        ..color = AppColors.crimson
        ..style = PaintingStyle.fill);

  _drawText(
    canvas,
    bloodGroup,
    Offset(size / 2, imgRadius * 2 + 14),
    const TextStyle(
        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
  );

  // Name + age label
  final labelText = age.isNotEmpty ? '$name, $age' : name;
  _drawText(
    canvas,
    labelText,
    Offset(size / 2, imgRadius * 2 + 38),
    const TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
    shadow: const Shadow(color: Colors.black54, blurRadius: 4),
  );

  // Pin point
  final pinPaint = Paint()..color = AppColors.crimson;
  canvas.drawCircle(Offset(size / 2, imgRadius * 2 + 58), 5, pinPaint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), (imgRadius * 2 + 70).toInt());
  final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.fromBytes(pngBytes!.buffer.asUint8List());
}

void _drawFallbackAvatar(Canvas canvas, double size, double imgRadius) {
  final avatarPaint = Paint()
    ..shader = const LinearGradient(colors: AppColors.crimsonGradient)
        .createShader(Rect.fromCircle(
            center: Offset(size / 2, imgRadius + 4), radius: imgRadius));
  canvas.drawCircle(Offset(size / 2, imgRadius + 4), imgRadius, avatarPaint);

  final iconPainter = TextPainter(
    text: const TextSpan(
      text: '👤',
      style: TextStyle(fontSize: 36),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  iconPainter.paint(
      canvas,
      Offset(size / 2 - iconPainter.width / 2,
          imgRadius + 4 - iconPainter.height / 2));
}

void _drawText(Canvas canvas, String text, Offset center, TextStyle style,
    {Shadow? shadow}) {
  final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.center,
    maxLines: 1,
  ))
    ..pushStyle(ui.TextStyle(
      color: style.color,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      shadows: shadow != null ? [shadow] : null,
    ))
    ..addText(text);
  final para = pb.build()
    ..layout(ui.ParagraphConstraints(width: 150));
  canvas.drawParagraph(
      para, Offset(center.dx - para.longestLine / 2, center.dy - (style.fontSize ?? 12) / 2));
}
