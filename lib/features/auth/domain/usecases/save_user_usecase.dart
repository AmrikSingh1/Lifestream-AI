import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SaveUserUseCase {
  final AuthRepository repository;

  SaveUserUseCase(this.repository);

  Future<void> call(UserEntity user) {
    return repository.saveUserData(user);
  }
}
