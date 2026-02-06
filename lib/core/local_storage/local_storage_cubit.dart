import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

// --- DEFINICJE STANÓW (Wewnątrz pliku) ---
abstract class LocalStorageState {}

class LocalStorageInitial extends LocalStorageState {}

class LocalStorageLoading extends LocalStorageState {}

class LocalStorageLoaded extends LocalStorageState {
  final int totalItems;
  final int unsyncedItems;
  LocalStorageLoaded({required this.totalItems, required this.unsyncedItems});
}

class LocalStorageError extends LocalStorageState {
  final String message;
  LocalStorageError(this.message);
}

// --- CUBIT ---
class LocalStorageCubit extends Cubit<LocalStorageState> {
  final InventoryRepository repository;
  Timer? _refreshTimer;

  LocalStorageCubit({required this.repository}) : super(LocalStorageInitial()) {
    // Startujemy monitoring
    _startMonitoring();
  }

  void _startMonitoring() {
    loadStats();
    // Live Updates: Co 2 sekundy sprawdzamy stan bazy
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      loadStats();
    });
  }

  Future<void> loadStats() async {
    try {
      // Używamy getAllBoxes(), bo tak nazywa się metoda w Twoim repozytorium
      final boxes = await repository.getAllBoxes();

      final total = boxes.length;
      final unsynced = boxes.where((box) => !box.isSynced).length;

      // Optymalizacja: Emituj tylko jeśli dane się zmieniły
      if (state is LocalStorageLoaded) {
        final current = state as LocalStorageLoaded;
        if (current.totalItems == total && current.unsyncedItems == unsynced) {
          return;
        }
      }

      emit(LocalStorageLoaded(totalItems: total, unsyncedItems: unsynced));
    } catch (e) {
      if (state is LocalStorageInitial) {
        emit(LocalStorageError(e.toString()));
      }
    }
  }

  @override
  Future<void> close() {
    _refreshTimer?.cancel();
    return super.close();
  }
}
