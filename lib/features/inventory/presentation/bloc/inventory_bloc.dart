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
  }

  Future<void> _onWriteTagRequested(
    WriteTagRequested event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      // 1. Create the new box object
      final newBox = StorageBox()
        ..itemName = event.name
        ..quantity = event.quantity
        ..threshold = event.threshold
        ..hexColor = event.color
        ..modelPath = 'assets/models/box.glb'
        ..lastUsed = DateTime.now();

      // 2. Save to DB and get the generated ID
      final id = await _inventoryRepository.saveBox(newBox);
      newBox.id = id;

      // 3. Write just the ID to the NFC tag (simple string)
      await _nfcService.writeTag(id.toString());

      // 4. Update UI
      emit(InventoryLoaded(box: newBox, message: 'Tag written successfully!'));
    } catch (e) {
      emit(InventoryError('Failed to write tag: ${e.toString()}'));
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

        // FIX: Handle Legacy JSON payloads (extract ID if present)
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

        // Now 'cleanId' should be just the number string (e.g., "15")
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
      final updatedBox = StorageBox()
        ..id = currentBox.id
        ..itemName = currentBox.itemName
        ..quantity = event.newQuantity
        ..threshold = currentBox.threshold
        ..hexColor = currentBox.hexColor
        ..modelPath = currentBox.modelPath
        ..lastUsed = DateTime.now();

      await _inventoryRepository.saveBox(updatedBox);
      final isLowStock = updatedBox.quantity < updatedBox.threshold;
      emit(InventoryLoaded(box: updatedBox, isLowStock: isLowStock));
    }
  }
}
