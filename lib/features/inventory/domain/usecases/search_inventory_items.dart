import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class SearchInventoryItems {
  final InventoryRepository repository;

  SearchInventoryItems(this.repository);

  Future<List<StorageBox>> call(String query) async {
    return await repository.searchBoxes(query);
  }
}