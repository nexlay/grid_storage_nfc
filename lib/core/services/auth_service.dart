import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print("Błąd logowania Google: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  // --- NOWA, POTĘŻNA METODA USUWANIA ---
  Future<void> deleteUserAccount() async {
    User? user = _firebaseAuth.currentUser;
    if (user == null) throw Exception("No user found");

    try {
      // 1. Wymuszamy ponowne pobranie świeżych tokenów z Google
      // To otworzy okno wyboru konta - użytkownik musi potwierdzić tożsamość
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("Re-authentication cancelled by user");
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 2. Re-autentykacja w Firebase (kluczowe dla user.delete!)
      await user.reauthenticateWithCredential(credential);

      // 3. Właściwe usunięcie konta z Firebase
      await user.delete();

      // 4. Zerwanie połączenia z aplikacją (żeby nie logowało automatycznie przy powrocie)
      await _googleSignIn.disconnect();
    } catch (e) {
      print("Błąd podczas usuwania konta: $e");
      rethrow; // Przekazujemy błąd dalej, żeby UI mógł go pokazać
    }
  }
}
