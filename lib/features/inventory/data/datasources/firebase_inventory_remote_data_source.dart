import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';

class FirebaseInventoryRemoteDataSource implements InventoryRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseInventoryRemoteDataSource({
    required this.firestore,
    required this.storage,
  });

  static const String _collection = 'boxes';

  /// Pomocniczy getter do pobierania ID zalogowanego użytkownika
  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("Błąd: Użytkownik nie jest zalogowany!");
    }
    return user.uid;
  }

  /// Pomocnicza metoda: Wysyła zdjęcie do Storage
  Future<String?> _uploadImageIfNecessary(
      String? imagePath, String boxId) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    // Jeśli ścieżka to już URL, nie wysyłamy ponownie
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    final file = File(imagePath);
    if (!file.existsSync()) {
      return null;
    }

    try {
      final ref = storage.ref().child('boxes_images').child('$boxId.jpg');

      // Dodajemy metadane właściciela pliku (dla bezpieczeństwa Storage Rules)
      await ref.putFile(
        file,
        SettableMetadata(customMetadata: {'userId': _userId}),
      );

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Błąd wysyłania zdjęcia do Storage: $e');
      return null;
    }
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    try {
      // FILTROWANIE: Pobieramy TYLKO pudełka należące do zalogowanego użytkownika
      final snapshot = await firestore
          .collection(_collection)
          .where('userId', isEqualTo: _userId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Przypisujemy ID dokumentu

        // Konwersja Timestamp na String (jeśli jest potrzebna)
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
      final docRef = firestore.collection(_collection).doc();
      final newId = docRef.id;

      // Najpierw zdjęcie, żeby mieć URL
      final imageUrl = await _uploadImageIfNecessary(box.imagePath, newId);

      final boxData = box.toJson();
      boxData.removeWhere((key, value) => value == null);

      if (imageUrl != null) {
        boxData['image_path'] = imageUrl;
      } else {
        boxData['image_path'] = null;
      }

      // PODPISYWANIE DOKUMENTU: To pole sprawia, że przedmiot należy do Ciebie
      boxData['userId'] = _userId;

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
      final imageUrl =
          await _uploadImageIfNecessary(box.imagePath, box.remoteId!);

      final boxData = box.toJson();

      if (imageUrl != null) {
        boxData['image_path'] = imageUrl;
      }

      // Upewniamy się, że przy edycji ID użytkownika jest zachowane
      boxData['userId'] = _userId;

      await firestore.collection(_collection).doc(box.remoteId).update(boxData);
    } catch (e) {
      throw Exception('Failed to update firebase box: $e');
    }
  }

  @override
  Future<void> deleteBox(String remoteId) async {
    try {
      // Usuwamy dokument z bazy
      await firestore.collection(_collection).doc(remoteId).delete();

      // Próbujemy usunąć zdjęcie (jeśli istnieje)
      try {
        final ref = storage.ref().child('boxes_images').child('$remoteId.jpg');
        await ref.delete();
      } catch (e) {
        // Ignorujemy błąd braku pliku
      }
    } catch (e) {
      throw Exception('Failed to delete firebase box: $e');
    }
  }
}
