import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

// --- STANY ---
abstract class LocalStorageState {}

class LocalStorageInitial extends LocalStorageState {}

class LocalStorageLoading extends LocalStorageState {}

class LocalStorageLoaded extends LocalStorageState {
  final int totalItems;
  final int unsyncedItems;
  LocalStorageLoaded(this.totalItems, this.unsyncedItems);
}

// --- CUBIT ---
class LocalStorageCubit extends Cubit<LocalStorageState> {
  final InventoryRepository repository;

  LocalStorageCubit({required this.repository}) : super(LocalStorageInitial());

  Future<void> loadStats() async {
    emit(LocalStorageLoading());
    try {
      final stats = await repository.getLocalStats();
      emit(LocalStorageLoaded(stats['total'] ?? 0, stats['unsynced'] ?? 0));
    } catch (e) {
      // W razie błędu pokazujemy 0
      emit(LocalStorageLoaded(0, 0));
    }
  }
}
