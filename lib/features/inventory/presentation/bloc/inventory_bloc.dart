import 'dart:convert'; // Added for jsonDecode
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final InventoryRepository _inventoryRepository;
  final NfcService _nfcService;

  InventoryBloc(this._inventoryRepository, this._nfcService)
      : super(const InventoryInitial()) {
    on<ScanTagRequested>(_onScanTagRequested);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<WriteTagRequested>(_onWriteTagRequested);
    on<DeleteBoxRequested>(_onDeleteBoxRequested);
    on<LoadAllItems>(_onLoadAllItems);
    on<ResetInventory>((event, emit) => emit(const InventoryInitial()));
  }

  Future<void> _onWriteTagRequested(
    WriteTagRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      StorageBox boxToSave;

      if (event.id != null) {
        // Editing an existing item
        final existingBox = await _inventoryRepository.getBox(event.id!);
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
          isSynced: false, // Set to false on update
        );
      } else {
        // Creating a new item
        boxToSave = StorageBox()
          ..itemName = event.name
          ..quantity = event.quantity
          ..threshold = event.threshold
          ..hexColor = event.color
          ..modelPath = 'assets/models/box.glb'
          ..lastUsed = DateTime.now()
          ..isSynced = false; // New item is not synced
      }

      final id = await _inventoryRepository.saveBox(boxToSave);
      // It's important to update the id of boxToSave as Isar might assign a new one
      boxToSave = boxToSave.copyWith(id: id);

      // Only write to NFC if it's a NEW item (id was null)
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

      // Allow time for NFC read
      await Future.delayed(const Duration(seconds: 2));
      await _nfcService.stopSession();

      if (tagPayload != null) {
        String cleanId = tagPayload!;

        // Handle Legacy JSON payloads (extract ID if present)
        if (cleanId.trim().startsWith('{')) {
          try {
            final Map<String, dynamic> data = jsonDecode(cleanId);
            if (data.containsKey('id')) {
              cleanId = data['id'].toString();
            }
          } catch (e) {
            // If JSON parse fails, attempt to use string as is
          }
        }

        var box = await _inventoryRepository.getBox(cleanId);

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
        isSynced: false, // Quantity update also marks as not synced
      );

      await _inventoryRepository.saveBox(updatedBox);
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
      final boxes = await _inventoryRepository.getAllBoxes();
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
      await _inventoryRepository.deleteBox(event.boxId);
      add(const LoadAllItems()); // Refresh the list after deletion
    } catch (e) {
      emit(InventoryError('Failed to delete box: ${e.toString()}'));
    }
  }
}
