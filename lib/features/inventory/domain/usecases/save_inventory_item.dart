import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

class SaveInventoryItem {
  final InventoryRepository repository;

  SaveInventoryItem(this.repository);

  // UseCases używają metody call, aby można je było wywoływać jak funkcje
  Future<int> call(StorageBox box) async {
    // Tutaj w przyszłości dodasz logikę: "Czy zapisać też do chmury?"
    return await repository.saveBox(box);
  }
}
