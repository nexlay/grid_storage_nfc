abstract class AuthRepository {
  Future<void> login({String? email, String? password});

  Future<void> logout();

  Future<void> deleteAccount();

  Future<bool> isLoggedIn();

  Future<String?> getUserRole();
}
