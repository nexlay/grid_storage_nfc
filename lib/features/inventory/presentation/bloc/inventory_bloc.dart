import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
// Importujemy Use Cases zamiast Repozytorium
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_list.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_last_used_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/save_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/delete_inventory_item.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final GetInventoryList getInventoryList;
  final GetInventoryItem getInventoryItem;
  final SaveInventoryItem saveInventoryItem;
  final DeleteInventoryItem deleteInventoryItem;
  final GetLastUsedItem getLastUsedItem;
  final NfcService _nfcService;

  InventoryBloc({
    required this.getInventoryList,
    required this.getInventoryItem,
    required this.saveInventoryItem,
    required this.deleteInventoryItem,
    required this.getLastUsedItem,
    required NfcService nfcService,
  })  : _nfcService = nfcService,
        super(const InventoryInitial()) {
    on<ScanTagRequested>(_onScanTagRequested);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<WriteTagRequested>(_onWriteTagRequested);
    on<DeleteBoxRequested>(_onDeleteBoxRequested);
    on<LoadAllItems>(_onLoadAllItems);
    on<ResetInventory>(_onResetInventory);
  }
  Future<void> _onResetInventory(
    ResetInventory event,
    Emitter<InventoryState> emit,
  ) async {
    // Próbujemy załadować ostatni element
    try {
      final lastBox = await getLastUsedItem();

      if (lastBox != null) {
        // Jeśli mamy element, pokazujemy go
        final isLowStock = lastBox.quantity < lastBox.threshold;
        emit(InventoryLoaded(box: lastBox, isLowStock: isLowStock));
      } else {
        // Jeśli baza jest pusta, pokazujemy "Ready to Scan"
        emit(const InventoryInitial());
      }
    } catch (e) {
      // W razie błędu bezpiecznie wracamy do ekranu startowego
      emit(const InventoryInitial());
    }
  }

  Future<void> _onWriteTagRequested(
    WriteTagRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      StorageBox boxToSave;
      if (event.id != null) {
        // Używamy Use Case zamiast repozytorium
        final existingBox = await getInventoryItem(event.id!);

        if (existingBox == null) {
          emit(const InventoryError('Box not found for editing.'));
          return;
        }

        boxToSave = existingBox.copyWith(
          itemName: event.name,
          quantity: event.quantity,
          threshold: event.threshold,
          hexColor: event.color,
          lastUsed: DateTime.now(),
          isSynced: false,
        );
      } else {
        boxToSave = StorageBox()
          ..itemName = event.name
          ..quantity = event.quantity
          ..threshold = event.threshold
          ..hexColor = event.color
          ..modelPath = 'assets/models/box.glb'
          ..lastUsed = DateTime.now()
          ..isSynced = false;
      }

      // Zapis przez Use Case
      final id = await saveInventoryItem(boxToSave);

      boxToSave = boxToSave.copyWith(id: id);

      if (event.id == null) {
        await _nfcService.writeTag(id.toString());
      }

      emit(
          InventoryLoaded(box: boxToSave, message: 'Item saved successfully!'));
    } catch (e) {
      emit(InventoryError('Failed to save item: ${e.toString()}'));
    }
  }

  Future<void> _onScanTagRequested(
    ScanTagRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      String? tagPayload;
      await _nfcService.startSession((payload) {
        tagPayload = payload;
      });

      await Future.delayed(const Duration(seconds: 2));
      await _nfcService.stopSession();

      if (tagPayload != null) {
        String cleanId = tagPayload!;
        if (cleanId.trim().startsWith('{')) {
          try {
            final Map<String, dynamic> data = jsonDecode(cleanId);
            if (data.containsKey('id')) {
              cleanId = data['id'].toString();
            }
          } catch (e) {
            // ignore
          }
        }

        // Pobranie przez Use Case
        var box = await getInventoryItem(cleanId);

        if (box == null) {
          emit(const InventoryError('Box not found for this tag.'));
          return;
        }

        final isLowStock = box.quantity < box.threshold;
        emit(InventoryLoaded(box: box, isLowStock: isLowStock));
      } else {
        emit(const InventoryError('Could not read NFC tag.'));
      }
    } catch (e) {
      emit(InventoryError('Scan failed: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateQuantity(
    UpdateQuantity event,
    Emitter<InventoryState> emit,
  ) async {
    final currentState = state;
    if (currentState is InventoryLoaded) {
      final currentBox = currentState.box;
      final updatedBox = currentBox.copyWith(
        quantity: event.newQuantity,
        lastUsed: DateTime.now(),
        isSynced: false,
      );

      // Zapis przez Use Case
      await saveInventoryItem(updatedBox);

      final isLowStock = updatedBox.quantity < updatedBox.threshold;
      emit(InventoryLoaded(box: updatedBox, isLowStock: isLowStock));
    }
  }

  Future<void> _onLoadAllItems(
    LoadAllItems event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      // Pobranie listy przez Use Case
      final boxes = await getInventoryList();
      emit(InventoryListLoaded(boxes: boxes));
    } catch (e) {
      emit(InventoryError('Failed to load inventory: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteBoxRequested(
    DeleteBoxRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      // Usunięcie przez Use Case
      await deleteInventoryItem(event.boxId);
      add(const LoadAllItems());
    } catch (e) {
      emit(InventoryError('Failed to delete box: ${e.toString()}'));
    }
  }
}
