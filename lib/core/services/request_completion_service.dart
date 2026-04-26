import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/request_completion_pdf_generator.dart';

class RequestCompletionService {
  static Future<void> donorMarkCompleted(String requestId) async {
    await _markCompleted(
      requestId: requestId,
      role: _CompleterRole.donor,
    );
  }

  static Future<void> recipientMarkCompleted(String requestId) async {
    await _markCompleted(
      requestId: requestId,
      role: _CompleterRole.recipient,
    );
  }

  static Future<void> _markCompleted({
    required String requestId,
    required _CompleterRole role,
  }) async {
    final docRef =
        FirebaseFirestore.instance.collection('blood_requests').doc(requestId);

    final current = await docRef.get();
    if (!current.exists) return;

    final data = current.data() ?? {};
    if (data['status'] == 'pending') {
      throw Exception('Request must be accepted before marking completion.');
    }

    final updates = role == _CompleterRole.donor
        ? {
            'donorCompleted': true,
            'donorCompletedAt': FieldValue.serverTimestamp(),
          }
        : {
            'recipientCompleted': true,
            'recipientCompletedAt': FieldValue.serverTimestamp(),
          };

    await docRef.update(updates);

    final refreshed = await docRef.get();
    if (!refreshed.exists) return;
    final refreshedData = refreshed.data() ?? {};

    final donorDone = refreshedData['donorCompleted'] == true;
    final recipientDone = refreshedData['recipientCompleted'] == true;
    if (!donorDone || !recipientDone) return;

    if (refreshedData['status'] == 'completed' &&
        (refreshedData['completionPdfUrl'] as String?)?.isNotEmpty == true) {
      return;
    }

    final donorId =
        (refreshedData['donorId'] as String?) ?? (refreshedData['acceptedByDonorId'] as String?);
    final recipientId =
        (refreshedData['recipientId'] as String?) ?? (refreshedData['requesterId'] as String?);

    final donorName = await _userField(donorId, 'fullName') ?? 'Donor';
    final donorBloodGroup = await _userField(donorId, 'bloodGroup') ?? '-';
    final recipientName = await _userField(recipientId, 'fullName') ??
        (refreshedData['requesterName'] as String?) ??
        'Recipient';
    final recipientPhone = await _userField(recipientId, 'phoneNumber') ??
        (refreshedData['requesterPhone'] as String?) ??
        '-';

    final pdfBytes = await RequestCompletionPdfGenerator.generateOfficialCompletionPdf(
      requestId: requestId,
      donorName: donorName,
      donorBloodGroup: donorBloodGroup,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      bloodGroupRequested: refreshedData['bloodGroup'] as String? ?? '-',
      completedAt: DateTime.now(),
    );

    final storagePath = 'request_pdfs/$requestId.pdf';
    final storageRef = FirebaseStorage.instance.ref().child(storagePath);
    await storageRef.putData(
      Uint8List.fromList(pdfBytes),
      SettableMetadata(contentType: 'application/pdf'),
    );
    final downloadUrl = await storageRef.getDownloadURL();

    await docRef.update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'completionPdfUrl': downloadUrl,
      'completionPdfStoragePath': storagePath,
    });
  }

  static Future<String?> _userField(String? uid, String field) async {
    if (uid == null || uid.isEmpty) return null;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!userDoc.exists) return null;
    return userDoc.data()?[field] as String?;
  }
}

enum _CompleterRole { donor, recipient }
