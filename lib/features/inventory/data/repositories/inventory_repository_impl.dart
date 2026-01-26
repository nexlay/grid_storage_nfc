import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final Isar isar;

  InventoryRepositoryImpl(this.isar);

  static Future<Isar> init() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [StorageBoxSchema],
      directory: dir.path,
    );
  }

  @override
  Future<void> deleteBox(String id) async {
    await isar.writeTxn(() async {
      await isar.storageBoxs.delete(int.parse(id));
    });
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    return await isar.storageBoxs.where().findAll();
  }

  @override
  Future<StorageBox?> getBox(String id) async {
    return await isar.storageBoxs.get(int.parse(id));
  }

  @override
  Future<int> saveBox(StorageBox box) async {
    return await isar.writeTxn(() async {
      return await isar.storageBoxs.put(box);
    });
  }
}
