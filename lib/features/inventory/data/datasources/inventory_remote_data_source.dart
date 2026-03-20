import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Dodane dla tokena

abstract class InventoryRemoteDataSource {
  Future<List<StorageBox>> getAllBoxes();
  Future<String> createBox(StorageBox box);
  Future<void> updateBox(StorageBox box);
  Future<void> deleteBox(String remoteId);
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final http.Client client;
  static const String baseUrl = 'http://192.168.1.40:3000/storage_boxes';

  InventoryRemoteDataSourceImpl({required this.client});

  // POMOCNIK: Pobieranie tokena JWT zapisanego podczas logowania
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(
        'auth_token'); // Upewnij się, że tak nazywasz klucz przy logowaniu
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _prepareBoxForUpload(StorageBox box) async {
    final jsonMap = box.toJson();
    if (box.imagePath != null && box.imagePath!.isNotEmpty) {
      final file = File(box.imagePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        jsonMap['image_base64'] = base64Encode(bytes);
      }
    }
    return jsonMap;
  }

  Future<StorageBox> _parseBoxFromDownload(Map<String, dynamic> json) async {
    StorageBox box = StorageBox.fromJson(json);
    if (json['image_base64'] != null &&
        json['image_base64'].toString().isNotEmpty) {
      try {
        final bytes = base64Decode(json['image_base64'].toString());
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'remote_${box.remoteId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        box.imagePath = file.path;
      } catch (e) {
        print('Błąd dekodowania zdjęcia: $e');
      }
    }
    return box;
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    try {
      final headers = await _getHeaders();
      final response = await client
          .get(Uri.parse(baseUrl), headers: headers)
          .timeout(const Duration(
              seconds: 30)); // ZWIĘKSZONO: Zdjęcia + VPN wymagają czasu

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<StorageBox> boxes = [];
        for (var item in data) {
          boxes.add(await _parseBoxFromDownload(item));
        }
        return boxes;
      } else if (response.statusCode == 401) {
        throw Exception('Sesja wygasła. Zaloguj się ponownie.');
      } else {
        throw Exception('Błąd serwera: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Serwer QNAP nie odpowiedział na czas (VPN?).');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> createBox(StorageBox box) async {
    final bodyData = await _prepareBoxForUpload(box);
    final headers = await _getHeaders();
    headers['Prefer'] = 'return=representation';

    final response = await client
        .post(Uri.parse(baseUrl), headers: headers, body: json.encode(bodyData))
        .timeout(const Duration(seconds: 30)); // ZWIĘKSZONO

    if (response.statusCode == 201) {
      final List result = json.decode(response.body);
      return result.first['id'].toString();
    }
    throw Exception('Błąd tworzenia przedmiotu');
  }

  @override
  Future<void> updateBox(StorageBox box) async {
    if (box.remoteId == null) return;
    final bodyData = await _prepareBoxForUpload(box);
    final headers = await _getHeaders();
    final url = '$baseUrl?id=eq.${box.remoteId}';

    final response = await client
        .patch(Uri.parse(url), headers: headers, body: json.encode(bodyData))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Błąd aktualizacji');
    }
  }

  @override
  Future<void> deleteBox(String remoteId) async {
    final headers = await _getHeaders();
    final url = '$baseUrl?id=eq.$remoteId';
    await client.delete(Uri.parse(url), headers: headers);
  }
}
