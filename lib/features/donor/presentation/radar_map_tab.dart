import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import 'providers/donor_providers.dart';

// ─── Urgency helpers ──────────────────────────────────────────────
Color _urgencyColor(String? u) {
  switch ((u ?? '').toUpperCase()) {
    case 'CRITICAL':
      return const Color(0xFFFF2D55);
    case 'HIGH':
      return const Color(0xFFFF6B00);
    case 'MEDIUM':
      return const Color(0xFFFFBE21);
    default:
      return AppColors.heroGreen;
  }
}

IconData _urgencyIcon(String? u) {
  switch ((u ?? '').toUpperCase()) {
    case 'CRITICAL':
      return Icons.emergency_rounded;
    case 'HIGH':
      return Icons.warning_rounded;
    default:
      return Icons.info_rounded;
  }
}

// ─── Radar Map Tab ────────────────────────────────────────────────
class RadarMapTab extends ConsumerStatefulWidget {
  const RadarMapTab({super.key});

  @override
  ConsumerState<RadarMapTab> createState() => _RadarMapTabState();
}

class _RadarMapTabState extends ConsumerState<RadarMapTab> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(20.5937, 78.9629);
  bool _locationLoaded = false;
  final Set<Marker> _markers = {};
  Map<String, dynamic>? _selectedRequest;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        if (mounted) {
          setState(() {
            _center = LatLng(pos.latitude, pos.longitude);
            _locationLoaded = true;
          });
          _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_center, 12));
        }
      }
    } catch (_) {}
  }

  Future<void> _buildMarkers(List<Map<String, dynamic>> requests) async {
    final newMarkers = <Marker>{};
    for (final req in requests) {
      final lat = (req['latitude'] as num?)?.toDouble();
      final lon = (req['longitude'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      BitmapDescriptor icon;
      try {
        icon = await _buildRequestMarker(req);
      } catch (_) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }

      newMarkers.add(Marker(
        markerId: MarkerId(req['id'] as String),
        position: LatLng(lat, lon),
        icon: icon,
        anchor: const Offset(0.5, 1.0),
        onTap: () => setState(() => _selectedRequest = req),
      ));
    }
    if (mounted) {
      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
      });
    }
  }

  Future<BitmapDescriptor> _buildRequestMarker(
      Map<String, dynamic> req) async {
    final urgency = req['urgency'] as String? ?? 'MEDIUM';
    final blood = req['bloodGroup'] as String? ?? '?';
    final color = _urgencyColor(urgency);

    const double size = 100;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Outer pulsing ring
    canvas.drawCircle(
        const Offset(size / 2, size / 2),
        40,
        Paint()
          ..color = color.withOpacity(0.2)
          ..style = PaintingStyle.fill);

    // Main circle
    canvas.drawCircle(
        const Offset(size / 2, size / 2),
        28,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);

    // White ring
    canvas.drawCircle(
        const Offset(size / 2, size / 2),
        28,
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Blood group text
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.center,
    ))
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ))
      ..addText(blood);
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 60));
    canvas.drawParagraph(
        para,
        Offset(size / 2 - para.longestLine / 2,
            size / 2 - (para.height / 2)));

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _acceptRequest(Map<String, dynamic> req) async {
    final id = req['id'] as String?;
    if (id == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(id)
          .update({
        'status': 'accepted',
        'acceptedByDonorId': FirebaseAuth.instance.currentUser?.uid,
        'acceptedAt': FieldValue.serverTimestamp(),
        'donorId': FirebaseAuth.instance.currentUser?.uid,
        'donorCompleted': false,
        'recipientCompleted': false,
      });
      if (mounted) {
        setState(() => _selectedRequest = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('You\'re on your way! Hero mode activated. 🩸'),
              ],
            ),
            backgroundColor: AppColors.heroGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(combinedActiveRequestsProvider);

    requestsAsync.whenData(_buildMarkers);

    return Stack(
      children: [
        // Map
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _center, zoom: 11),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          onMapCreated: (c) {
            _mapController = c;
            _applyDarkStyle(c);
            if (_locationLoaded) {
              c.animateCamera(CameraUpdate.newLatLngZoom(_center, 12));
            }
          },
          // Hide selected card on map tap
          onTap: (_) => setState(() => _selectedRequest = null),
        ),

        // Header overlay
        SafeArea(
          child: Column(
            children: [
              // Title bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.darkBg.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded,
                              color: AppColors.urgentRed, size: 18),
                          const SizedBox(width: 8),
                          const Text('Emergency Radar',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Count chip
                    requestsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (list) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.darkBg.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: list.isEmpty
                                  ? AppColors.glassBorder
                                  : AppColors.urgentRed
                                      .withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: list.isEmpty
                                    ? Colors.grey
                                    : AppColors.urgentRed,
                              ),
                            )
                                .animate(
                                    onPlay: (c) => c.repeat())
                                .scaleXY(
                                  begin: 1,
                                  end: list.isEmpty ? 1 : 1.5,
                                  duration: 800.ms,
                                  curve: Curves.easeInOut,
                                )
                                .then()
                                .scaleXY(
                                  begin: 1.5,
                                  end: 1,
                                  duration: 800.ms,
                                ),
                            const SizedBox(width: 6),
                            Text(
                              '${list.length} active',
                              style: TextStyle(
                                  color: list.isEmpty
                                      ? AppColors.textMuted
                                      : AppColors.urgentRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _LegendChip(
                        color: const Color(0xFFFF2D55), label: 'Critical'),
                    const SizedBox(width: 8),
                    _LegendChip(
                        color: const Color(0xFFFF6B00), label: 'High'),
                    const SizedBox(width: 8),
                    _LegendChip(
                        color: const Color(0xFFFFBE21), label: 'Medium'),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),

        // My Location FAB
        Positioned(
          right: 16,
          bottom: _selectedRequest != null ? 320 : 24,
          child: GestureDetector(
            onTap: () {
              if (_locationLoaded) {
                _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_center, 14));
              }
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8)
                ],
              ),
              child: const Icon(Icons.my_location_rounded,
                  color: AppColors.royalBlue, size: 22),
            ),
          ),
        ),

        // Request Detail Card
        if (_selectedRequest != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _RequestDetailCard(
              request: _selectedRequest!,
              onAccept: () => _acceptRequest(_selectedRequest!),
              onDismiss: () => setState(() => _selectedRequest = null),
            ),
          ),
      ],
    );
  }

  Future<void> _applyDarkStyle(GoogleMapController c) async {
    const style = '''[
      {"elementType":"geometry","stylers":[{"color":"#0d1117"}]},
      {"elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]},
      {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1f2937"}]},
      {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#374151"}]},
      {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0a0f1a"}]},
      {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#111827"}]}
    ]''';
    c.setMapStyle(style);
  }
}

// ─── Request Detail Card ──────────────────────────────────────────
class _RequestDetailCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _RequestDetailCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  State<_RequestDetailCard> createState() => _RequestDetailCardState();
}

class _RequestDetailCardState extends State<_RequestDetailCard> {
  String? _recipientAge;
  String? _recipientAddress;
  String? _profileUrl;
  bool _loadingDetails = true;

  @override
  void initState() {
    super.initState();
    _fetchRecipientDetails();
  }

  @override
  void didUpdateWidget(covariant _RequestDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request['id'] != widget.request['id']) {
      _fetchRecipientDetails();
    }
  }

  Future<void> _fetchRecipientDetails() async {
    final reqId = widget.request['recipientId'] as String? ?? widget.request['requesterId'] as String?;
    if (reqId == null || reqId.isEmpty) {
      if (mounted) setState(() => _loadingDetails = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(reqId).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _recipientAge = data?['age']?.toString();
          final city = data?['city'] as String? ?? '';
          final addr = data?['address'] as String? ?? '';
          _recipientAddress = [addr, city].where((s) => s.isNotEmpty).join(', ');
          _profileUrl = data?['profileImageUrl'] as String?;
          _loadingDetails = false;
        });
      } else if (mounted) {
        setState(() => _loadingDetails = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final blood = request['bloodGroup'] as String? ?? '?';
    final urgency = request['urgency'] as String? ?? 'MEDIUM';
    final requester =
        request['requesterName'] as String? ?? 'Unknown';
    final distance =
        (request['distanceKm'] as double? ?? 0.0).toStringAsFixed(1);
    final phone = request['requesterPhone'] as String? ?? '';
    final color = _urgencyColor(urgency);

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.darkBg.withOpacity(0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: AppColors.glassBorder),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle + dismiss
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.glassBorder,
                          borderRadius: BorderRadius.circular(2))),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recipient Overview with Profile Picture
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                      image: _profileUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_profileUrl!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: _profileUrl == null
                        ? Icon(Icons.person_rounded, color: color, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requester,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                        if (_recipientAge != null)
                          Text(
                            'Age: $_recipientAge',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  // Urgency badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_urgencyIcon(urgency), color: color, size: 14),
                        const SizedBox(width: 6),
                        Text('$urgency',
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats grid
              Row(
                children: [
                  _InfoTile(
                    icon: Icons.water_drop_rounded,
                    label: 'Blood Type',
                    value: blood,
                    color: AppColors.crimson,
                  ),
                  const SizedBox(width: 12),
                  _InfoTile(
                    icon: Icons.near_me_rounded,
                    label: 'Distance',
                    value: '${distance}km',
                    color: AppColors.royalBlueLight,
                  ),
                ],
              ),
              
              if (_recipientAddress != null && _recipientAddress!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.royalBlueLight, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _recipientAddress!,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  if (phone.isNotEmpty) ...[
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () async {
                          final cleaned = phone.replaceAll(RegExp(r'\D'), '');
                          final uri = Uri.parse('tel:$cleaned');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.glassBorder),
                            borderRadius: BorderRadius.circular(18),
                            color: Colors.white.withOpacity(0.05),
                          ),
                          child: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () async {
                          final cleaned = phone.replaceAll(RegExp(r'\D'), '');
                          final message = Uri.encodeComponent("Hi, I saw your urgent $blood request on LifeStream AI. I am a donor and I am on my way.");
                          final uri = Uri.parse('https://wa.me/$cleaned?text=$message');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF25D366).withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(18),
                            color: const Color(0xFF25D366).withOpacity(0.15),
                          ),
                          child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: widget.onAccept,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            color,
                            Color.lerp(color, Colors.black, 0.2)!
                          ]),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_run_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Heading There",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
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
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.3);
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkBg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ignore: unused_element
double _deg2rad(double deg) => deg * math.pi / 180;
