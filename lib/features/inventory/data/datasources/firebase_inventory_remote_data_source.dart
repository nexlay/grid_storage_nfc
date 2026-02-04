import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';

class FirebaseInventoryRemoteDataSource implements InventoryRemoteDataSource {
  final FirebaseFirestore firestore;

  FirebaseInventoryRemoteDataSource({required this.firestore});

  static const String _collection = 'boxes';

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
      final boxData = box.toJson();

      boxData.removeWhere((key, value) => value == null);

      final docRef = await firestore.collection(_collection).add(boxData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create firebase box: $e');
    }
  }

  @override
  Future<void> updateBox(StorageBox box) async {
    if (box.remoteId == null) return;
    try {
      final boxData = box.toJson();

      await firestore.collection(_collection).doc(box.remoteId).update(boxData);
    } catch (e) {
      throw Exception('Failed to update firebase box: $e');
    }
  }

  @override
  Future<void> deleteBox(String remoteId) async {
    try {
      await firestore.collection(_collection).doc(remoteId).delete();
    } catch (e) {
      throw Exception('Failed to delete firebase box: $e');
    }
  }
}
