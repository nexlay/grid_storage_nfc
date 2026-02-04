import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';

class FirebaseInventoryRemoteDataSource implements InventoryRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;

  FirebaseInventoryRemoteDataSource({
    required this.firestore,
    required this.storage,
  });

  static const String _collection = 'boxes';

  /// Pomocnicza metoda: Wysyła zdjęcie do Storage (jeśli to plik lokalny)
  /// i zwraca URL do pobrania. Jeśli ścieżka to już URL, zwraca go bez zmian.
  Future<String?> _uploadImageIfNecessary(
      String? imagePath, String boxId) async {
    // 1. Jeśli brak ścieżki, zwracamy null
    if (imagePath == null || imagePath.isEmpty) return null;

    // 2. Jeśli ścieżka zaczyna się od http, to znaczy, że to już jest link (nie trzeba wysyłać)
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // 3. Sprawdzamy, czy plik lokalny fizycznie istnieje
    final file = File(imagePath);
    if (!file.existsSync()) {
      return null;
    }

    try {
      // 4. Tworzymy referencję w folderze 'boxes_images' z nazwą pliku równą ID pudełka
      final ref = storage.ref().child('boxes_images').child('$boxId.jpg');

      // 5. Wysyłamy plik
      await ref.putFile(file);

      // 6. Pobieramy publiczny link URL
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Błąd wysyłania zdjęcia do Storage: $e');
      // W razie błędu zwracamy null (zapiszemy przedmiot bez zdjęcia w chmurze)
      return null;
    }
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    try {
      final snapshot = await firestore.collection(_collection).get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        if (data['last_used'] is Timestamp) {
          data['last_used'] =
              (data['last_used'] as Timestamp).toDate().toIso8601String();
        }

        return StorageBox.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load firebase boxes: $e');
    }
  }

  @override
  Future<String> createBox(StorageBox box) async {
    try {
      // 1. Generujemy ID dokumentu ręcznie przed zapisem,
      // aby użyć tego samego ID do nazwy pliku zdjęcia.
      final docRef = firestore.collection(_collection).doc();
      final newId = docRef.id;

      // 2. Próba wysyłki zdjęcia
      final imageUrl = await _uploadImageIfNecessary(box.imagePath, newId);

      // 3. Przygotowanie danych JSON
      final boxData = box.toJson();
      boxData.removeWhere((key, value) => value == null);

      // 4. Jeśli udało się uzyskać URL, nadpisujemy pole image_path
      if (imageUrl != null) {
        boxData['image_path'] = imageUrl;
      } else {
        // Jeśli nie ma zdjęcia lub błąd wysyłki -> null w bazie
        boxData['image_path'] = null;
      }

      // 5. Zapisujemy dokument pod wygenerowanym ID (używamy .set zamiast .add)
      await docRef.set(boxData);

      return newId;
    } catch (e) {
      throw Exception('Failed to create firebase box: $e');
    }
  }

  @override
  Future<void> updateBox(StorageBox box) async {
    if (box.remoteId == null) return;
    try {
      // 1. Wysyłka zdjęcia (jeśli użytkownik zmienił je na nowe lokalne)
      final imageUrl =
          await _uploadImageIfNecessary(box.imagePath, box.remoteId!);

      final boxData = box.toJson();

      // 2. Aktualizacja pola image_path w danych wysyłanych do bazy
      if (imageUrl != null) {
        boxData['image_path'] = imageUrl;
      }

      await firestore.collection(_collection).doc(box.remoteId).update(boxData);
    } catch (e) {
      throw Exception('Failed to update firebase box: $e');
    }
  }

  @override
  Future<void> deleteBox(String remoteId) async {
    try {
      // 1. Usuń dokument z bazy danych
      await firestore.collection(_collection).doc(remoteId).delete();

      // 2. Spróbuj usunąć zdjęcie ze Storage (żeby nie zostawiać śmieci)
      try {
        final ref = storage.ref().child('boxes_images').child('$remoteId.jpg');
        await ref.delete();
      } catch (e) {
        // Ignorujemy błąd, jeśli plik nie istniał (np. przedmiot nie miał zdjęcia)
      }
    } catch (e) {
      throw Exception('Failed to delete firebase box: $e');
    }
  }
}
