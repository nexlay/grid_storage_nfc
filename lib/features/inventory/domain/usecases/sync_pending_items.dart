import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class SyncPendingItems {
  final InventoryRepository repository;

  SyncPendingItems(this.repository);

  Future<void> call() async {
    return await repository.syncPendingItems();
  }
}
