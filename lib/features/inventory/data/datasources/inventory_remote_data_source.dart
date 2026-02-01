import 'dart:async'; // <-- Dodaj ten import do obsługi TimeoutException
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';

abstract class InventoryRemoteDataSource {
  Future<List<StorageBox>> getAllBoxes();
  Future<String> createBox(StorageBox box);
  Future<void> updateBox(StorageBox box);
  Future<void> deleteBox(String remoteId);
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final http.Client client;
  // Upewnij się, że adres jest poprawny
  static const String baseUrl = 'http://192.168.1.40:3000/storage_boxes';

  InventoryRemoteDataSourceImpl({required this.client});

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    // DODANO: .timeout(Duration(seconds: 3))
    // Jeśli serwer nie odpowie w 3 sekundy, rzuć błąd i przestań kręcić kółkiem
    final response = await client
        .get(Uri.parse(baseUrl))
        .timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => StorageBox.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load remote boxes');
    }
  }

  @override
  Future<String> createBox(StorageBox box) async {
    final response = await client
        .post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: json.encode(box.toJson()),
        )
        .timeout(
            const Duration(seconds: 3)); // Też dodajemy timeout przy zapisie

    if (response.statusCode == 201) {
      final List<dynamic> result = json.decode(response.body);
      return result.first['id'].toString();
    } else {
      throw Exception('Failed to create remote box');
    }
  }

  // W metodach updateBox i deleteBox też warto dodać .timeout(...) analogicznie
  @override
  Future<void> updateBox(StorageBox box) async {
    if (box.remoteId == null) return;
    final url = '$baseUrl?id=eq.${box.remoteId}';

    await client
        .patch(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(box.toJson()),
        )
        .timeout(const Duration(seconds: 3));
  }

  @override
  Future<void> deleteBox(String remoteId) async {
    final url = '$baseUrl?id=eq.$remoteId';
    await client.delete(Uri.parse(url)).timeout(const Duration(seconds: 3));
  }
}
