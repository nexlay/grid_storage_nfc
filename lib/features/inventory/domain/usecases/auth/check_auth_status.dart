import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';

class CheckAuthStatus {
  final AuthRepository repository;

  CheckAuthStatus(this.repository);

  Future<bool> call() async {
    return await repository.isLoggedIn();
  }
}
