import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class GetInventoryItem {
  final InventoryRepository repository;

  GetInventoryItem(this.repository);

  Future<StorageBox?> call(String id) async {
    return await repository.getBox(id);
  }
}
