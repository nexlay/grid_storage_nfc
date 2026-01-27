import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class GetInventoryList {
  final InventoryRepository repository;

  GetInventoryList(this.repository);

  Future<List<StorageBox>> call() async {
    return await repository.getAllBoxes();
  }
}
