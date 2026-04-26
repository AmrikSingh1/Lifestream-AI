import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/save_user_usecase.dart';
import '../../domain/usecases/sign_in_email_usecase.dart';
import '../../domain/usecases/sign_in_google_usecase.dart';
import '../../domain/usecases/sign_up_email_usecase.dart';

// ──────────────────────────────────────────────
// Repository Provider
// ──────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

// ──────────────────────────────────────────────
// Use Case Providers
// ──────────────────────────────────────────────
final signUpEmailUseCaseProvider = Provider<SignUpEmailUseCase>((ref) {
  return SignUpEmailUseCase(ref.read(authRepositoryProvider));
});

final signInEmailUseCaseProvider = Provider<SignInEmailUseCase>((ref) {
  return SignInEmailUseCase(ref.read(authRepositoryProvider));
});

final signInGoogleUseCaseProvider = Provider<SignInGoogleUseCase>((ref) {
  return SignInGoogleUseCase(ref.read(authRepositoryProvider));
});

final saveUserUseCaseProvider = Provider<SaveUserUseCase>((ref) {
  return SaveUserUseCase(ref.read(authRepositoryProvider));
});

// ──────────────────────────────────────────────
// Signup form state
// ──────────────────────────────────────────────
class SignupFormState {
  final String fullName;
  final String email;
  final String password;

  const SignupFormState({
    this.fullName = '',
    this.email = '',
    this.password = '',
  });

  SignupFormState copyWith({
    String? fullName,
    String? email,
    String? password,
  }) {
    return SignupFormState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
    );
  }
}

final signupFormProvider =
    StateNotifierProvider<SignupFormNotifier, SignupFormState>((ref) {
  return SignupFormNotifier();
});

class SignupFormNotifier extends StateNotifier<SignupFormState> {
  SignupFormNotifier() : super(const SignupFormState());

  void updateFullName(String value) => state = state.copyWith(fullName: value);
  void updateEmail(String value) => state = state.copyWith(email: value);
  void updatePassword(String value) => state = state.copyWith(password: value);
}

// ──────────────────────────────────────────────
// Auth State Notifier (Login/Signup/Google)
// ──────────────────────────────────────────────
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, bool>(() => AuthNotifier());

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<bool> signUp() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final signUpUseCase = ref.read(signUpEmailUseCaseProvider);
      final saveUseCase = ref.read(saveUserUseCaseProvider);
      final formState = ref.read(signupFormProvider);

      // 1 — Register with Email/Password
      final uid = await signUpUseCase(
        email: formState.email,
        password: formState.password,
      );

      // 2 — Save user to Firestore with default empty profile and null role
      final user = UserEntity(
        uid: uid,
        fullName: formState.fullName,
        phoneNumber: '', // Ask in onboarding
        bloodGroup: '',  // Ask in onboarding
        city: '',        // Ask in onboarding
        role: '',        // Let user pick role next
        createdAt: DateTime.now(),
      );

      await saveUseCase(user);
      return true;
    });

    return state.valueOrNull ?? false;
  }

  Future<bool> updateUserRole({required String role}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      final authRepo = ref.read(authRepositoryProvider);
      final existingData = await authRepo.getUserData(user.uid);
      if (existingData == null) throw Exception("User data not found in database.");

      final updatedUser = existingData.copyWith(role: role);
      await authRepo.saveUserData(updatedUser);
      return true;
    });

    return state.valueOrNull ?? false;
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final signInUseCase = ref.read(signInEmailUseCaseProvider);
      await signInUseCase(email: email, password: password);
      return true;
    });
    return state.valueOrNull ?? false;
  }

  Future<bool> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final signInGoogleUseCase = ref.read(signInGoogleUseCaseProvider);
      final uid = await signInGoogleUseCase();
      if (uid == null) return false; // Cancelled by user

      // Check if user exists in Firestore
      final authRepo = ref.read(authRepositoryProvider);
      final existingUser = await authRepo.getUserData(uid);

      if (existingUser == null) {
        // If it's a new Google user, we should ideally ask for their role, blood group, etc.
        // For now, we'll save a default profile and they can update it later.
        final fbUser = FirebaseAuth.instance.currentUser;
        final user = UserEntity(
          uid: uid,
          fullName: fbUser?.displayName ?? 'Google User',
          phoneNumber: fbUser?.phoneNumber ?? '',
          bloodGroup: '',
          city: '',
          role: '', // Let user pick role next
          createdAt: DateTime.now(),
        );
        await authRepo.saveUserData(user);
      }
      return true;
    });
    return state.valueOrNull ?? false;
  }
}

