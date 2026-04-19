import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';

class QnapAuthRepository implements AuthRepository {
  final http.Client client;
  final FlutterSecureStorage storage;
  final String baseUrl = 'http://192.168.1.40:3000';

  QnapAuthRepository({required this.client, required this.storage});

  @override
  Future<void> login({String? email, String? password}) async {
    if (email == null || password == null) {
      throw Exception('Email and password are required.');
    }

    try {
      final response = await client.post(
        Uri.parse('$baseUrl/rpc/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'pass': password}),
      );

      if (response.statusCode == 200) {
        String token = "";
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is String) {
          token = decoded;
        } else if (decoded is List && decoded.isNotEmpty) {
          token = decoded[0]['token'];
        } else if (decoded is Map && decoded.containsKey('token')) {
          token = decoded['token'];
        }

        if (token.isNotEmpty) {
          await storage.write(key: 'jwt_token', value: token);
          return;
        }
      }
      throw Exception('Invalid email or password.');
    } catch (e) {
      throw Exception('Server connection error: $e');
    }
  }

  @override
  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: 'jwt_token');

    // Jeśli nie ma tokenu, na pewno jesteśmy wylogowani.
    if (token == null) return false;

    // --- NOWA LOGIKA ---
    // Nie usuwamy użytkownika z aplikacji, jeśli token po prostu "wygasł"
    // w oczach JwtDecoder, gdy jesteśmy w terenie bez dostępu do QNAPa.
    // Zostawiamy token w pamięci. Jeśli QNAP odrzuci połączenie (401),
    // to remote_data_source powinien wyrzucić błąd, a wtedy możemy wylogować.

    // Zwracamy TRUE po prostu na podstawie tego, że token istnieje w SecureStorage.
    return true;
  }

  @override
  Future<String?> getUserRole() async {
    final token = await storage.read(key: 'jwt_token');
    if (token == null) return null;

    try {
      final decoded = JwtDecoder.decode(token);
      return decoded['role'];
    } catch (e) {
      return 'user';
    }
  }

  @override
  Future<void> requestPasswordChange(String email) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/password_reset_requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'status': 'pending',
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to send request to the server.');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
