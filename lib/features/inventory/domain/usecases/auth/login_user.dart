import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository repository;

  LoginUser(this.repository);

  Future<void> call({String? email, String? password}) async {
    return await repository.login(email: email, password: password);
  }
}
