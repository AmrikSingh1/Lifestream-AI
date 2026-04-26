import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDatasource _authDatasource;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    FirebaseAuthDatasource? authDatasource,
    FirebaseFirestore? firestore,
  })  : _authDatasource = authDatasource ?? FirebaseAuthDatasource(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _authDatasource.signUpWithEmail(email: email, password: password);

  @override
  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _authDatasource.signInWithEmail(email: email, password: password);

  @override
  Future<String?> signInWithGoogle() => _authDatasource.signInWithGoogle();

  @override
  Future<void> saveUserData(UserEntity user) async {
    final model = UserModel.fromEntity(user);
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(model.toFirestore(), SetOptions(merge: true))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Firestore write timed out. Please verify Firestore is enabled in Firebase Console.'),
        );
  }

  @override
  Future<UserEntity?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  @override
  Future<void> signOut() => _authDatasource.signOut();
}
