import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class GetLastUsedItem {
  final InventoryRepository repository;

  GetLastUsedItem(this.repository);

  Future<StorageBox?> call() async {
    return await repository.getLastUsedBox();
  }
}
