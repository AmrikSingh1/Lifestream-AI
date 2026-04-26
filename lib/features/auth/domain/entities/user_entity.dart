import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String fullName;
  final String phoneNumber;
  final String bloodGroup;
  final String city;
  final String role;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  // Profile extras
  final int? age;
  final String? profileImageUrl;
  final String? address;
  final bool onboardingComplete;
  // Donor Hero fields
  final bool isAvailable;
  final int donationCount;
  final int livesSaved;
  final DateTime? lastDonationDate;

  const UserEntity({
    required this.uid,
    required this.fullName,
    required this.phoneNumber,
    required this.bloodGroup,
    required this.city,
    required this.role,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.age,
    this.profileImageUrl,
    this.address,
    this.onboardingComplete = false,
    this.isAvailable = false,
    this.donationCount = 0,
    this.livesSaved = 0,
    this.lastDonationDate,
  });

  UserEntity copyWith({
    String? uid,
    String? fullName,
    String? phoneNumber,
    String? bloodGroup,
    String? city,
    String? role,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    int? age,
    String? profileImageUrl,
    String? address,
    bool? onboardingComplete,
    bool? isAvailable,
    int? donationCount,
    int? livesSaved,
    DateTime? lastDonationDate,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      city: city ?? this.city,
      role: role ?? this.role,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      age: age ?? this.age,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      address: address ?? this.address,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isAvailable: isAvailable ?? this.isAvailable,
      donationCount: donationCount ?? this.donationCount,
      livesSaved: livesSaved ?? this.livesSaved,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
    );
  }

  @override
  List<Object?> get props => [
        uid, fullName, phoneNumber, bloodGroup, city, role,
        latitude, longitude, createdAt, age, profileImageUrl,
        address, onboardingComplete, isAvailable, donationCount,
        livesSaved, lastDonationDate,
      ];
}
