import 'package:grid_storage_nfc/core/services/auth_service.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final AuthService _authService;

  FirebaseAuthRepository(this._authService);

  @override
  Future<void> login({String? email, String? password}) async {
    await _authService.signInWithGoogle();
  }

  @override
  Future<void> logout() async {
    await _authService.signOut();
  }

  @override
  Future<bool> isLoggedIn() async {
    return _authService.currentUser != null;
  }

  @override
  Future<String?> getUserRole() async {
    if (_authService.currentUser != null) {
      return 'admin';
    }
    return null;
  }

  @override
  Future<void> requestPasswordChange(String email) async {
    throw Exception(
        'Password change is not available when signing in with Google.');
  }
}
