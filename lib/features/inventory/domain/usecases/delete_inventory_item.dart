import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class DeleteInventoryItem {
  final InventoryRepository repository;

  DeleteInventoryItem(this.repository);

  Future<void> call(String id) async {
    await repository.deleteBox(id);
  }
}
