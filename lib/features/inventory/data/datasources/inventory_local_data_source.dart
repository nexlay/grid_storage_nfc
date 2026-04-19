import 'package:flutter/foundation.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

abstract class InventoryLocalDataSource {
  Future<List<StorageBox>> getAllBoxes();
  Future<StorageBox?> getBox(String id);
  Future<int> saveBox(StorageBox box);
  Future<void> deleteBox(String id);
  Future<StorageBox?> getLastUsedBox();
  Future<List<StorageBox>> searchBoxes(String query);
  Future<void> clearAll();
}

class InventoryLocalDataSourceImpl implements InventoryLocalDataSource {
  final Isar? isar;
  final List<StorageBox> _webCache = []; // <-- Nasza mini-baza dla Weba

  InventoryLocalDataSourceImpl(this.isar);

  static Future<InventoryLocalDataSource> init() async {
    // --- BEZPIECZEŃSTWO WEB ---
    if (kIsWeb) {
      // Na Webie Isar 3.x wyrzuca błąd, więc go omijamy
      return InventoryLocalDataSourceImpl(null);
    }

    final dir = await getApplicationDocumentsDirectory();
    final isarInstance = await Isar.open(
      [StorageBoxSchema],
      directory: dir.path,
    );
    return InventoryLocalDataSourceImpl(isarInstance);
  }

  @override
  Future<StorageBox?> getLastUsedBox() async {
    if (kIsWeb) {
      if (_webCache.isEmpty) return null;
      final sorted = List<StorageBox>.from(_webCache)
        ..sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      return sorted.first;
    }
    return await isar!.storageBoxs.where().sortByLastUsedDesc().findFirst();
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    if (kIsWeb) return _webCache;
    return await isar!.storageBoxs.where().findAll();
  }

  @override
  Future<StorageBox?> getBox(String id) async {
    if (kIsWeb) {
      try {
        return _webCache.firstWhere((box) => box.id.toString() == id);
      } catch (_) {
        return null;
      }
    }
    return await isar!.storageBoxs.get(int.parse(id));
  }

  @override
  Future<int> saveBox(StorageBox box) async {
    if (kIsWeb) {
      final index = _webCache.indexWhere((b) => b.id == box.id);
      if (index >= 0) {
        _webCache[index] = box;
      } else {
        if (box.id == Isar.autoIncrement) {
          box.id = _webCache.isEmpty
              ? 1
              : (_webCache.map((b) => b.id).reduce((a, b) => a > b ? a : b) +
                  1);
        }
        _webCache.add(box);
      }
      return box.id;
    }
    return await isar!.writeTxn(() async {
      return await isar!.storageBoxs.put(box);
    });
  }

  @override
  Future<void> deleteBox(String id) async {
    if (kIsWeb) {
      _webCache.removeWhere((box) => box.id.toString() == id);
      return;
    }
    await isar!.writeTxn(() async {
      await isar!.storageBoxs.delete(int.parse(id));
    });
  }

  @override
  Future<List<StorageBox>> searchBoxes(String query) async {
    if (query.isEmpty) return getAllBoxes();

    if (kIsWeb) {
      final lowerQuery = query.toLowerCase();
      return _webCache.where((box) {
        final matchName = box.itemName.toLowerCase().contains(lowerQuery);
        final matchBarcode =
            box.barcode?.toLowerCase().contains(lowerQuery) ?? false;
        return matchName || matchBarcode;
      }).toList();
    }

    return await isar!.storageBoxs
        .filter()
        .itemNameContains(query, caseSensitive: false)
        .or()
        .barcodeContains(query, caseSensitive: false)
        .findAll();
  }

  @override
  Future<void> clearAll() async {
    if (kIsWeb) {
      _webCache.clear();
      return;
    }
    await isar!.writeTxn(() async {
      await isar!.storageBoxs.clear();
    });
  }
}
