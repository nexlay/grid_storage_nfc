import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

class QnapAuthRepository implements AuthRepository {
  final http.Client client;
  final FlutterSecureStorage storage;
  final String baseUrl = 'http://192.168.1.40:3000'; // IP Twojego QNAP

  QnapAuthRepository({required this.client, required this.storage});

  @override
  Future<void> login({String? email, String? password}) async {
    try {
      final response = await client.post(
        Uri.parse('$baseUrl/rpc/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'pass': password}),
      );

      if (response.statusCode == 200) {
        // Logika wyciągania tokena (taka sama jak ustaliliśmy wcześniej)
        String token = "";
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List && decoded.isNotEmpty) {
          token = decoded[0]['token'];
        } else if (decoded is Map && decoded.containsKey('token')) {
          token = decoded['token'];
        } else if (decoded is String) {
          token = decoded;
        }

        if (token.isNotEmpty) {
          await storage.write(key: 'jwt_token', value: token);
          return;
        }
      }
      throw Exception('Błąd logowania QNAP: ${response.statusCode}');
    } catch (e) {
      throw Exception('Błąd połączenia z QNAP: $e');
    }
  }

  @override
  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: 'jwt_token');
    if (token == null) return false;
    return !JwtDecoder.isExpired(token);
  }

  @override
  Future<String?> getUserRole() async {
    final token = await storage.read(key: 'jwt_token');
    if (token == null) return null;
    final decoded = JwtDecoder.decode(token);
    return decoded['role']; // 'web_admin' lub 'web_user'
  }

  @override
  Future<void> deleteAccount() {
    throw UnimplementedError();
  }
}
