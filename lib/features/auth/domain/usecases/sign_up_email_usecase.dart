import '../repositories/auth_repository.dart';

class SignUpEmailUseCase {
  final AuthRepository repository;

  SignUpEmailUseCase(this.repository);

  Future<String> call({
    required String email,
    required String password,
  }) {
    return repository.signUpWithEmail(email: email, password: password);
  }
}
