import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryLocalDataSource localDataSource;

  // Wstrzykujemy DataSource zamiast Isar bezpośrednio
  InventoryRepositoryImpl({required this.localDataSource});

  @override
  Future<void> deleteBox(String id) async {
    await localDataSource.deleteBox(id);
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    return await localDataSource.getAllBoxes();
  }

  @override
  Future<StorageBox?> getBox(String id) async {
    return await localDataSource.getBox(id);
  }

  @override
  Future<int> saveBox(StorageBox box) async {
    return await localDataSource.saveBox(box);
  }

  @override
  Future<StorageBox?> getLastUsedBox() async {
    return await localDataSource.getLastUsedBox();
  }
}
