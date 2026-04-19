import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/core/notifications/notification_service.dart';
import 'package:grid_storage_nfc/core/services/export_service.dart'; // <--- NOWY IMPORT
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_list.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_last_used_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/save_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/delete_inventory_item.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';
import 'package:equatable/equatable.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/search_inventory_items.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  final GetInventoryList getInventoryList;
  final GetInventoryItem getInventoryItem;
  final SaveInventoryItem saveInventoryItem;
  final DeleteInventoryItem deleteInventoryItem;
  final GetLastUsedItem getLastUsedItem;
  final SearchInventoryItems searchInventoryItems;
  final NfcService _nfcService;
  final NotificationService notificationService;
  final ExportService exportService; // <--- NOWY SERWIS

  InventoryBloc({
    required this.getInventoryList,
    required this.getInventoryItem,
    required this.saveInventoryItem,
    required this.deleteInventoryItem,
    required this.getLastUsedItem,
    required this.searchInventoryItems,
    required NfcService nfcService,
    required this.notificationService,
    required this.exportService, // <--- DODANE DO KONSTRUKTORA
  })  : _nfcService = nfcService,
        super(const InventoryInitial()) {
    on<ScanTagRequested>(_onScanTagRequested);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<WriteTagRequested>(_onWriteTagRequested);
    on<DeleteBoxRequested>(_onDeleteBoxRequested);
    on<LoadAllItems>(_onLoadAllItems);
    on<ResetInventory>(_onResetInventory);
    on<ProcessScannedCode>(_onProcessScannedCode);
    on<SearchItems>(_onSearchItems);
    on<ExportItemsRequested>(
        _onExportItemsRequested); // <--- NASŁUCHIWANIE NA EKSPORT
  }

  // --- NOWA METODA EKSPORTU ---
  Future<void> _onExportItemsRequested(
    ExportItemsRequested event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      if (event.format == 'pdf') {
        await exportService.exportToPdf(event.itemsToExport);
      } else if (event.format == 'excel') {
        await exportService.exportToExcel(event.itemsToExport);
      }
      // Nie emitujemy nowego stanu, bo share_plus samo otwiera okienko systemowe.
      // Ewentualnie można by dodać SnackBar z sukcesem w UI.
    } catch (e) {
      emit(InventoryError('Failed to export: ${e.toString()}'));
    }
  }

  Future<void> _onSearchItems(
    SearchItems event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      final allBoxes = await getInventoryList();

      if (event.query.isEmpty) {
        emit(InventoryListLoaded(boxes: allBoxes));
        return;
      }

      final query = event.query.toLowerCase();
      final filteredBoxes = allBoxes.where((box) {
        final matchesName = box.itemName.toLowerCase().contains(query);
        final matchesBarcode =
            box.barcode?.toLowerCase().contains(query) ?? false;

        return matchesName || matchesBarcode;
      }).toList();

      emit(InventoryListLoaded(boxes: filteredBoxes));
    } catch (e) {
      emit(InventoryError('Search failed: ${e.toString()}'));
    }
  }

  Future<void> _onProcessScannedCode(
    ProcessScannedCode event,
    Emitter<InventoryState> emit,
  ) async {
    emit(const InventoryLoading());
    try {
      String cleanCode = event.rawCode;

      if (cleanCode.trim().startsWith('{')) {
        try {
          final Map<String, dynamic> data = jsonDecode(cleanCode);
          if (data.containsKey('id')) {
            cleanCode = data['id'].toString();
          }
        } catch (_) {}
      }

      final allItems = await getInventoryList();

      try {
        final box = allItems.firstWhere((b) {
          return b.id.toString() == cleanCode || b.barcode == cleanCode;
        });

        final isLowStock = box.quantity <= box.threshold;
        emit(InventoryLoaded(box: box, isLowStock: isLowStock));
      } catch (_) {
        emit(InventoryError(
          'Item not found for code: $cleanCode',
          scannedCode: cleanCode,
        ));
      }
    } catch (e) {
      emit(InventoryError('Error processing code: ${e.toString()}'));
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
        final existingBox = await getInventoryItem(event.id.toString());

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
          imagePath: event.imagePath,
        );
      } else {
        boxToSave = StorageBox()
          ..itemName = event.name
          ..quantity = event.quantity
          ..threshold = event.threshold
          ..hexColor = event.color
          ..modelPath = 'assets/models/box.glb'
          ..lastUsed = DateTime.now()
          ..isSynced = false
          ..barcode = event.barcode
          ..imagePath = event.imagePath;
      }

      final id = await saveInventoryItem(boxToSave);
      boxToSave = boxToSave.copyWith(id: id);

      if (event.id == null && event.writeToNfc) {
        await _nfcService.writeTag(id.toString());
      }

      emit(InventoryLoaded(
          box: boxToSave,
          isLowStock: boxToSave.quantity <= boxToSave.threshold,
          message: 'Item saved successfully!'));
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
        add(ProcessScannedCode(tagPayload!));
      } else {
        emit(const InventoryError('Could not read NFC tag.'));
      }
    } catch (e) {
      emit(InventoryError('Scan failed: ${e.toString()}'));
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

      await saveInventoryItem(updatedBox);

      if (updatedBox.quantity <= updatedBox.threshold &&
          updatedBox.quantity < currentBox.quantity) {
        await notificationService.showLowStockNotification(
            updatedBox.itemName, updatedBox.quantity);
      }

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
