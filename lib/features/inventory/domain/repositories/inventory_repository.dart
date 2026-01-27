import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';

abstract class InventoryRepository {
  Future<int> saveBox(StorageBox box); // Changed to return int
  Future<StorageBox?> getBox(String id);
  Future<List<StorageBox>> getAllBoxes();
  Future<void> deleteBox(String id);
  Future<StorageBox?> getLastUsedBox();
}
