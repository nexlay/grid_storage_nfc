import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // Do zapisu pobranych zdjęć
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';

abstract class InventoryRemoteDataSource {
  Future<List<StorageBox>> getAllBoxes();
  Future<String> createBox(StorageBox box);
  Future<void> updateBox(StorageBox box);
  Future<void> deleteBox(String remoteId);
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final http.Client client;
  // Upewnij się, że adres IP jest poprawny
  static const String baseUrl = 'http://192.168.1.40:3000/storage_boxes';

  InventoryRemoteDataSourceImpl({required this.client});

  // --- POMOCNIK: Konwersja PLIK -> BASE64 ---
  Future<Map<String, dynamic>> _prepareBoxForUpload(StorageBox box) async {
    final jsonMap = box.toJson();

    // Jeśli mamy lokalne zdjęcie, zamieniamy je na tekst (Base64)
    if (box.imagePath != null && box.imagePath!.isNotEmpty) {
      final file = File(box.imagePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        jsonMap['image_base64'] = base64String; // Pole w bazie SQL
      }
    }
    return jsonMap;
  }

  // --- POMOCNIK: Konwersja BASE64 -> PLIK ---
  Future<StorageBox> _parseBoxFromDownload(Map<String, dynamic> json) async {
    StorageBox box = StorageBox.fromJson(json);

    // Jeśli serwer przysłał zdjęcie w Base64, zapiszmy je lokalnie
    if (json['image_base64'] != null &&
        json['image_base64'].toString().isNotEmpty) {
      try {
        final base64String = json['image_base64'].toString();
        final bytes = base64Decode(base64String);

        // Zapisujemy w katalogu aplikacji z unikalną nazwą (np. ID.jpg)
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'remote_${box.remoteId}.jpg';
        final file = File('${appDir.path}/$fileName');

        await file.writeAsBytes(bytes);

        // Aktualizujemy ścieżkę w obiekcie, żeby UI mogło go wyświetlić
        box.imagePath = file.path;
      } catch (e) {
        print('Błąd dekodowania zdjęcia z serwera: $e');
      }
    }
    return box;
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    final response = await client
        .get(Uri.parse(baseUrl))
        .timeout(const Duration(seconds: 5)); // Wydłużamy czas, bo zdjęcia ważą

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      // Musimy asynchronicznie przetworzyć każdy element (zapisać zdjęcia)
      List<StorageBox> boxes = [];
      for (var item in data) {
        boxes.add(await _parseBoxFromDownload(item));
      }
      return boxes;
    } else {
      throw Exception('Failed to load remote boxes');
    }
  }

  @override
  Future<String> createBox(StorageBox box) async {
    // Przygotuj dane (z zakodowanym zdjęciem)
    final bodyData = await _prepareBoxForUpload(box);

    print("📤 Wysyłam nowy box z obrazkiem...");

    final response = await client
        .post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          body: json.encode(bodyData),
        )
        .timeout(const Duration(seconds: 10)); // Upload trwa dłużej

    if (response.statusCode == 201) {
      final List result = json.decode(response.body);
      return result.first['id'].toString();
    } else {
      print('❌ Błąd createBox: ${response.statusCode} ${response.body}');
      throw Exception('Failed to create remote box');
    }
  }

  @override
  Future<void> updateBox(StorageBox box) async {
    if (box.remoteId == null) return;

    final bodyData = await _prepareBoxForUpload(box);
    final url = '$baseUrl?id=eq.${box.remoteId}';

    print("📤 Aktualizuję box ID ${box.remoteId}...");

    final response = await client
        .patch(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(bodyData),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Sukces
    } else {
      throw Exception('Failed to update remote box');
    }
  }

  @override
  Future<void> deleteBox(String remoteId) async {
    final url = '$baseUrl?id=eq.$remoteId';
    await client.delete(Uri.parse(url));
  }
}
