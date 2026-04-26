import '../repositories/auth_repository.dart';

class SignInEmailUseCase {
  final AuthRepository repository;

  SignInEmailUseCase(this.repository);

  Future<String> call({
    required String email,
    required String password,
  }) {
    return repository.signInWithEmail(email: email, password: password);
  }
}
