import '../entities/user_entity.dart';

abstract class AuthRepository {
  /// Sign up with Email and Password
  Future<String> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Sign in with Email and Password
  Future<String> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign in with Google
  Future<String?> signInWithGoogle();

  /// Save or update user data in Firestore
  Future<void> saveUserData(UserEntity user);

  /// Fetch user data by UID
  Future<UserEntity?> getUserData(String uid);

  /// Sign out the current user
  Future<void> signOut();
}
