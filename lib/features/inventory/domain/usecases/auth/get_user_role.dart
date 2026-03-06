import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';

class GetUserRole {
  final AuthRepository repository;

  GetUserRole(this.repository);

  Future<String?> call() async {
    return await repository.getUserRole();
  }
}
