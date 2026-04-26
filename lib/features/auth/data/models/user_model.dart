import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.fullName,
    required super.phoneNumber,
    required super.bloodGroup,
    required super.city,
    required super.role,
    super.latitude,
    super.longitude,
    required super.createdAt,
    super.age,
    super.profileImageUrl,
    super.address,
    super.onboardingComplete = false,
    super.isAvailable = false,
    super.donationCount = 0,
    super.livesSaved = 0,
    super.lastDonationDate,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      bloodGroup: data['bloodGroup'] as String? ?? '',
      city: data['city'] as String? ?? '',
      role: data['role'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      age: data['age'] as int?,
      profileImageUrl: data['profileImageUrl'] as String?,
      address: data['address'] as String?,
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      isAvailable: data['isAvailable'] as bool? ?? false,
      donationCount: data['donationCount'] as int? ?? 0,
      livesSaved: data['livesSaved'] as int? ?? 0,
      lastDonationDate: data['lastDonationDate'] != null
          ? (data['lastDonationDate'] as Timestamp).toDate()
          : null,
    );
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      fullName: data['fullName'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      bloodGroup: data['bloodGroup'] as String? ?? '',
      city: data['city'] as String? ?? '',
      role: data['role'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      age: data['age'] as int?,
      profileImageUrl: data['profileImageUrl'] as String?,
      address: data['address'] as String?,
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      isAvailable: data['isAvailable'] as bool? ?? false,
      donationCount: data['donationCount'] as int? ?? 0,
      livesSaved: data['livesSaved'] as int? ?? 0,
      lastDonationDate: data['lastDonationDate'] != null
          ? (data['lastDonationDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'bloodGroup': bloodGroup,
      'city': city,
      'role': role,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'age': age,
      'profileImageUrl': profileImageUrl,
      'address': address,
      'onboardingComplete': onboardingComplete,
      'isAvailable': isAvailable,
      'donationCount': donationCount,
      'livesSaved': livesSaved,
      'lastDonationDate':
          lastDonationDate != null ? Timestamp.fromDate(lastDonationDate!) : null,
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      fullName: entity.fullName,
      phoneNumber: entity.phoneNumber,
      bloodGroup: entity.bloodGroup,
      city: entity.city,
      role: entity.role,
      latitude: entity.latitude,
      longitude: entity.longitude,
      createdAt: entity.createdAt,
      age: entity.age,
      profileImageUrl: entity.profileImageUrl,
      address: entity.address,
      onboardingComplete: entity.onboardingComplete,
      isAvailable: entity.isAvailable,
      donationCount: entity.donationCount,
      livesSaved: entity.livesSaved,
      lastDonationDate: entity.lastDonationDate,
    );
  }
}
