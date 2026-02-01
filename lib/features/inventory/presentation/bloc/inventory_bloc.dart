import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:grid_storage_nfc/core/notifications/notification_service.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
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
  final NotificationService notificationService;

  InventoryBloc({
    required this.getInventoryList,
    required this.getInventoryItem,
    required this.saveInventoryItem,
    required this.deleteInventoryItem,
    required this.getLastUsedItem,
    required NfcService nfcService,
    required this.notificationService,
  })  : _nfcService = nfcService,
        super(const InventoryInitial()) {
    on<ScanTagRequested>(_onScanTagRequested);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<WriteTagRequested>(_onWriteTagRequested);
    on<DeleteBoxRequested>(_onDeleteBoxRequested);
    on<LoadAllItems>(_onLoadAllItems);
    on<ResetInventory>(_onResetInventory);
    on<ProcessScannedCode>(_onProcessScannedCode);
  }

  Future<void> _onProcessScannedCode(
    ProcessScannedCode event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      String cleanCode = event.rawCode;

      // Logika JSON (bez zmian)
      if (cleanCode.trim().startsWith('{')) {
        try {
          final Map<String, dynamic> data = jsonDecode(cleanCode);
          if (data.containsKey('id')) {
            cleanCode = data['id'].toString();
          }
        } catch (e) {}
      }

      print("🔍 SKANOWANIE: Szukam kodu '$cleanCode'...");

      final allItems = await getInventoryList();

      // --- DEBUGOWANIE ---
      // To pokaże w konsoli co masz w bazie
      print("📦 ZAWARTOŚĆ BAZY (${allItems.length} elementów):");
      for (var b in allItems) {
        print(
            "   - Item: '${b.itemName}', ID: ${b.id}, Barcode: '${b.barcode}'");
      }
      // -------------------

      try {
        final box = allItems.firstWhere((b) {
          return b.id.toString() == cleanCode || b.barcode == cleanCode;
        });

        print("✅ ZNALEZIONO: ${box.itemName}");
        final isLowStock = box.quantity <= box.threshold;
        emit(InventoryLoaded(box: box, isLowStock: isLowStock));
      } catch (_) {
        print("❌ NIE ZNALEZIONO pasującego elementu.");
        emit(InventoryError(
          'Item not found for code: $cleanCode',
          scannedCode: cleanCode,
        ));
      }
    } catch (e) {
      emit(InventoryError('Error processing code: ${e.toString()}'));
    }
  }

  Future<void> _onResetInventory(
    ResetInventory event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      final lastBox = await getLastUsedItem();

      if (lastBox != null) {
        final isLowStock = lastBox.quantity <= lastBox.threshold;
        emit(InventoryLoaded(box: lastBox, isLowStock: isLowStock));
      } else {
        emit(const InventoryInitial());
      }
    } catch (e) {
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
        // --- EDYCJA ---
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
          // Przy edycji zazwyczaj nie nadpisujemy barcode, chyba że dodasz taką opcję w UI
          // barcode: event.barcode ?? existingBox.barcode,
        );
      } else {
        // --- NOWY PRZEDMIOT ---
        boxToSave = StorageBox()
          ..itemName = event.name
          ..quantity = event.quantity
          ..threshold = event.threshold
          ..hexColor = event.color
          ..modelPath = 'assets/models/box.glb'
          ..lastUsed = DateTime.now()
          ..isSynced = false
          ..barcode = event.barcode; // <--- WAŻNE: Zapisujemy kod kreskowy/QR
      }

      // 1. Zapis do bazy
      final id = await saveInventoryItem(boxToSave);
      boxToSave = boxToSave.copyWith(id: id);

      // 2. Zapis na tag NFC (tylko jeśli wymagane i to nowy item)
      if (event.id == null && event.writeToNfc) {
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

        var box = await getInventoryItem(cleanId);

        if (box == null) {
          emit(const InventoryError('Box not found for this tag.'));
          return;
        }

        final isLowStock = box.quantity <= box.threshold;
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

      // 1. Zapis do bazy (Lokalnej + QNAP jeśli jest sieć)
      await saveInventoryItem(updatedBox);

      // 2. --- LOGIKA POWIADOMIENIA ---
      if (updatedBox.quantity <= updatedBox.threshold &&
          updatedBox.quantity < currentBox.quantity) {
        await notificationService.showLowStockNotification(
            updatedBox.itemName, updatedBox.quantity);
      }

      // 3. Aktualizacja UI
      final isLowStock = updatedBox.quantity <= updatedBox.threshold;
      emit(InventoryLoaded(box: updatedBox, isLowStock: isLowStock));
    }
  }

  Future<void> _onLoadAllItems(
    LoadAllItems event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
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
      await deleteInventoryItem(event.boxId);
      add(const LoadAllItems());
    } catch (e) {
      emit(InventoryError('Failed to delete box: ${e.toString()}'));
    }
  }
}
