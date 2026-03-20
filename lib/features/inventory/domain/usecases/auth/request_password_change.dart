import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';

class RequestPasswordChange {
  final AuthRepository repository;

  RequestPasswordChange(this.repository);

  Future<void> call(String email) async {
    return await repository.requestPasswordChange(email);
  }
}
