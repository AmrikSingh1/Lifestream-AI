import '../repositories/auth_repository.dart';

class SignInGoogleUseCase {
  final AuthRepository repository;

  SignInGoogleUseCase(this.repository);

  Future<String?> call() {
    return repository.signInWithGoogle();
  }
}
