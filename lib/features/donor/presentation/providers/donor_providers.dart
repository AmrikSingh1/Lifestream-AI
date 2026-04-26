import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// ─── Real-time donor stream ───────────────────────────────────────
final donorProfileStreamProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? doc.data() : null);
});

// ─── Availability notifier ────────────────────────────────────────
final availabilityProvider =
    StateNotifierProvider<AvailabilityNotifier, AsyncValue<bool>>((ref) {
  return AvailabilityNotifier(ref);
});

class AvailabilityNotifier extends StateNotifier<AsyncValue<bool>> {
  Timer? _locationTimer;

  AvailabilityNotifier(Ref _) : super(const AsyncData(false));

  Future<void> toggle(bool newValue) async {
    state = const AsyncLoading();
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      if (newValue) {
        // Start location updates every 10 min
        await _updateLocation(uid);
        _locationTimer =
            Timer.periodic(const Duration(minutes: 10), (_) => _updateLocation(uid));
      } else {
        _locationTimer?.cancel();
        _locationTimer = null;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'isAvailable': newValue});

      state = AsyncData(newValue);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> _updateLocation(String uid) async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'latitude': pos.latitude, 'longitude': pos.longitude});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}

// ─── Blood requests stream (within 15 km) ─────────────────────────
final nearbyRequestsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userAsync = ref.watch(donorProfileStreamProvider);
  final userData = userAsync.valueOrNull;
  if (userData == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('blood_requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
    final donorLat = (userData['latitude'] as num?)?.toDouble();
    final donorLon = (userData['longitude'] as num?)?.toDouble();
    final donorBg = userData['bloodGroup'] as String? ?? '';

    return snap.docs.map((d) {
      final data = {'id': d.id, ...d.data()};
      // Compute distance
      if (donorLat != null && donorLon != null) {
        final reqLat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        final reqLon = (data['longitude'] as num?)?.toDouble() ?? 0.0;
        data['distanceKm'] = Geolocator.distanceBetween(donorLat, donorLon, reqLat, reqLon) / 1000.0;
      } else {
        data['distanceKm'] = 999.0;
      }
      return data;
    }).where((d) {
      final urgency = (d['urgency'] as String? ?? '').toUpperCase();
      final isEmergency = urgency == 'CRITICAL' || urgency == 'HIGH' || urgency == 'MEDIUM';
      
      if (!isEmergency && (d['distanceKm'] as double) > 15.0) return false;
      
      // Blood compatibility
      final reqBg = d['bloodGroup'] as String? ?? '';
      if (donorBg == 'O+' || donorBg == 'O-') return true;
      return donorBg == reqBg;
    }).toList();
  });
});

// ─── Emergency requests matched to donor (within 10 km) ───────────
final emergencyRequestsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userAsync = ref.watch(donorProfileStreamProvider);
  final userData = userAsync.valueOrNull;
  if (userData == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('blood_requests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
    final donorLat = (userData['latitude'] as num?)?.toDouble();
    final donorLon = (userData['longitude'] as num?)?.toDouble();
    final donorBg = userData['bloodGroup'] as String? ?? '';

    return snap.docs.map((d) {
      final data = {'id': d.id, ...d.data()};
      if (donorLat != null && donorLon != null) {
        final reqLat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        final reqLon = (data['longitude'] as num?)?.toDouble() ?? 0.0;
        data['distanceKm'] = Geolocator.distanceBetween(donorLat, donorLon, reqLat, reqLon) / 1000.0;
      } else {
        data['distanceKm'] = 999.0;
      }
      return data;
    }).where((d) {
      if ((d['distanceKm'] as double) > 10.0) return false;

      // Blood compatibility
      final reqBg = d['bloodGroup'] as String? ?? '';
      if (donorBg == 'O+' || donorBg == 'O-') return true;
      return donorBg == reqBg;
    }).toList();
  });
});

// ─── Targeted requests for this donor ─────────────────────────────
final targetedRequestsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  final userAsync = ref.watch(donorProfileStreamProvider);
  final userData = userAsync.valueOrNull;

  return FirebaseFirestore.instance
      .collection('blood_requests')
      .where('donorId', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
    final donorLat = (userData?['latitude'] as num?)?.toDouble();
    final donorLon = (userData?['longitude'] as num?)?.toDouble();

    return snap.docs.map((d) {
      final data = {'id': d.id, ...d.data()};
      if (donorLat != null && donorLon != null) {
        final reqLat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        final reqLon = (data['longitude'] as num?)?.toDouble() ?? 0.0;
        data['distanceKm'] = Geolocator.distanceBetween(donorLat, donorLon, reqLat, reqLon) / 1000.0;
      } else {
        data['distanceKm'] = 0.0; // Default if donor location unknown
      }
      return data;
    }).toList();
  });
});

// ─── Combined Active Requests (Nearby + Targeted) ─────────────────
final combinedActiveRequestsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final nearby = ref.watch(nearbyRequestsProvider);
  final targeted = ref.watch(targetedRequestsProvider);

  if (nearby.isLoading || targeted.isLoading) {
    return const AsyncLoading();
  }

  if (nearby.hasError) return AsyncError(nearby.error!, nearby.stackTrace!);
  if (targeted.hasError) return AsyncError(targeted.error!, targeted.stackTrace!);

  final nearbyList = nearby.valueOrNull ?? [];
  final targetedList = targeted.valueOrNull ?? [];

  // Merge them uniquely
  final Map<String, Map<String, dynamic>> combined = {};
  for (final req in nearbyList) {
    combined[req['id'] as String] = req;
  }
  for (final req in targetedList) {
    combined[req['id'] as String] = req;
  }

  final outList = combined.values.toList();
  // Sort by createdAt descending
  outList.sort((a, b) {
    final tA = a['createdAt'] as Timestamp?;
    final tB = b['createdAt'] as Timestamp?;
    if (tA == null && tB == null) return 0;
    if (tA == null) return 1;
    if (tB == null) return -1;
    return tB.compareTo(tA);
  });

  return AsyncData(outList);
});

final donorRequestHistoryProvider =
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
          final donorId = request['donorId'] as String?;
          final acceptedByDonorId = request['acceptedByDonorId'] as String?;
          return donorId == uid || acceptedByDonorId == uid;
        })
        .toList();
    list.sort((a, b) {
      final tA = a['createdAt'] as Timestamp?;
      final tB = b['createdAt'] as Timestamp?;
      if (tA == null && tB == null) return 0;
      if (tA == null) return 1;
      if (tB == null) return -1;
      return tB.compareTo(tA);
    });
    return list;
  });
});
