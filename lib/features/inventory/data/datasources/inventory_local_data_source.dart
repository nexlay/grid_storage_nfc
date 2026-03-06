import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

abstract class InventoryLocalDataSource {
  Future<List<StorageBox>> getAllBoxes();
  Future<StorageBox?> getBox(String id);
  Future<int> saveBox(StorageBox box);
  Future<void> deleteBox(String id);
  Future<StorageBox?> getLastUsedBox();

  // --- NOWA METODA: Wyszukiwanie ---
  Future<List<StorageBox>> searchBoxes(String query);

  Future<void> clearAll();
}

class InventoryLocalDataSourceImpl implements InventoryLocalDataSource {
  // Isar jest teraz zarządzany tutaj, nie w repozytorium (Twój oryginalny kod)
  static Future<Isar> init() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [StorageBoxSchema],
      directory: dir.path,
    );
  }

  final Isar isar;

  InventoryLocalDataSourceImpl(this.isar);

  @override
  Future<StorageBox?> getLastUsedBox() async {
    // Sortujemy malejąco po dacie użycia i bierzemy pierwszy element
    return await isar.storageBoxs.where().sortByLastUsedDesc().findFirst();
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    try {
      final result = await isar.storageBoxs.where().findAll();
      return result;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<StorageBox?> getBox(String id) async {
    // Uwaga: zakładamy, że id to String parsujący się na int (dla Isar)
    return await isar.storageBoxs.get(int.parse(id));
  }

  @override
  Future<int> saveBox(StorageBox box) async {
    return await isar.writeTxn(() async {
      return await isar.storageBoxs.put(box);
    });
  }

  @override
  Future<void> deleteBox(String id) async {
    await isar.writeTxn(() async {
      await isar.storageBoxs.delete(int.parse(id));
    });
  }

  // --- IMPLEMENTACJA WYSZUKIWANIA (NOWE) ---
  @override
  Future<List<StorageBox>> searchBoxes(String query) async {
    if (query.isEmpty) {
      return getAllBoxes();
    }

    // Wyszukiwanie Case-Insensitive w polach itemName LUB barcode
    return await isar.storageBoxs
        .filter()
        .itemNameContains(query, caseSensitive: false)
        .or()
        .barcodeContains(query, caseSensitive: false)
        .findAll();
  }

  @override
  Future<void> clearAll() async {
    await isar.writeTxn(() async {
      await isar.storageBoxs.clear();
    });
  }
}
