abstract class AuthRepository {
  /// Logowanie.
  /// Parametry są opcjonalne, ponieważ w trybie Home (Google) ich nie potrzebujemy,
  /// a w trybie Office (QNAP) będą wymagane.
  Future<void> login({String? email, String? password});

  /// Wylogowanie użytkownika
  Future<void> logout();

  /// Sprawdzenie, czy użytkownik jest aktualnie zalogowany
  Future<bool> isLoggedIn();

  /// Pobranie roli użytkownika (np. 'admin' lub 'user')
  Future<String?> getUserRole();

  /// Wysłanie prośby do administratora o zmianę hasła
  Future<void> requestPasswordChange(String email);
}
