import 'package:grid_storage_nfc/core/network/network_info.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';
// 1. NOWOŚĆ: Import potrzebny do sprawdzania ustawień
import 'package:shared_preferences/shared_preferences.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryLocalDataSource localDataSource;
  final InventoryRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  InventoryRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // 2. NOWOŚĆ: Metoda pomocnicza sprawdzająca Twój przełącznik
  Future<bool> _isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // 'sync_enabled' to ten sam klucz, którego użyliśmy w ServerStatusCubit
    return prefs.getBool('sync_enabled') ?? true;
  }

  @override
  Future<List<StorageBox>> getAllBoxes() async {
    // 1. Pobierz dane z telefonu (Isar)
    var localBoxes = await localDataSource.getAllBoxes();

    // 2. Jeśli telefon jest pusty, mamy internet ORAZ włączoną synchronizację
    if (localBoxes.isEmpty &&
        await networkInfo.isConnected &&
        await _isSyncEnabled()) {
      // <-- ZMIANA
      try {
        final remoteBoxes = await remoteDataSource.getAllBoxes();
        for (var box in remoteBoxes) {
          // Zapisz pobrane z serwera pudełka do lokalnej bazy
          await localDataSource.saveBox(box);
        }
        // Odśwież listę lokalną
        localBoxes = await localDataSource.getAllBoxes();
      } catch (e) {
        // Ignorujemy błąd pobierania, zwracamy pustą listę
        print('Błąd pobierania wstępnego: $e');
      }
    }

    return localBoxes;
  }

  @override
  Future<StorageBox?> getBox(String id) async {
    return await localDataSource.getBox(id);
  }

  @override
  Future<int> saveBox(StorageBox box) async {
    // KROK 1: Zapisz lokalnie (Zawsze!)
    // Ustawiamy flagę na false, bo jeszcze nie wiemy, czy wyślemy
    box.isSynced = false;
    box.lastUsed = DateTime.now();

    final localId = await localDataSource.saveBox(box);

    // Aktualizujemy ID w obiekcie, żeby mieć pewność, że pracujemy na zapisanym
    box.id = localId;

    // KROK 2: Próba wysyłki online (w tle)
    try {
      // 3. NOWOŚĆ: Sprawdzamy oba warunki: Internet + Zgoda użytkownika
      if (await networkInfo.isConnected && await _isSyncEnabled()) {
        String remoteId;

        if (box.remoteId == null) {
          // A. Nowy przedmiot -> POST
          remoteId = await remoteDataSource.createBox(box);
        } else {
          // B. Istniejący przedmiot -> PATCH
          await remoteDataSource.updateBox(box);
          remoteId = box.remoteId!;
        }

        // KROK 3: Sukces! Aktualizujemy flagi lokalnie
        box.isSynced = true;
        box.remoteId = remoteId;

        // Nadpisz w Isar (teraz już z zieloną flagą synced)
        await localDataSource.saveBox(box);
      } else {
        print(
            'Info: Synchronizacja pominięta (Brak sieci lub wyłączona w opcjach).');
      }
    } catch (e) {
      // Błąd sieci? Trudno.
      // Użytkownik i tak widzi sukces (bo zapisało się lokalnie).
      print('Ostrzeżenie: Nie udało się zapisać na serwerze: $e');
    }

    return localId;
  }

  @override
  Future<void> deleteBox(String id) async {
    // Najpierw pobierzmy boxa, żeby sprawdzić, czy ma remoteId
    final box = await localDataSource.getBox(id);

    // 1. Usuń z serwera (jeśli jest net, box był tam zapisany I synchronizacja włączona)
    if (box != null &&
        box.remoteId != null &&
        await networkInfo.isConnected &&
        await _isSyncEnabled()) {
      // <-- ZMIANA
      try {
        await remoteDataSource.deleteBox(box.remoteId!);
      } catch (e) {
        print('Ostrzeżenie: Nie udało się usunąć z serwera: $e');
      }
    }

    // 2. Usuń lokalnie (Zawsze)
    await localDataSource.deleteBox(id);
  }

  @override
  Future<StorageBox?> getLastUsedBox() async {
    return await localDataSource.getLastUsedBox();
  }

  // Wewnątrz InventoryRepositoryImpl

  // Nowa metoda do synchronizacji zaległych danych
  // (Tę metodę wywołuje Cubit celowo, więc tu nie musimy dodawać blokady,
  // bo wywołanie jej oznacza, że użytkownik właśnie włączył synchronizację)
  @override
  Future<void> syncPendingItems() async {
    print('📦 Rozpoczynam synchronizację zaległych danych...');

    // 1. Pobierz wszystkie lokalne pudełka
    final allBoxes = await localDataSource.getAllBoxes();

    // 2. Wybierz tylko te, które NIE są zsynchronizowane (isSynced == false)
    final pendingBoxes =
        allBoxes.where((box) => box.isSynced == false).toList();

    if (pendingBoxes.isEmpty) {
      print('✅ Brak danych do wysłania.');
      return;
    }

    print('🚀 Znaleziono ${pendingBoxes.length} elementów do wysłania.');

    // 3. Pętla wysyłająca
    for (var box in pendingBoxes) {
      try {
        String remoteId;

        // Logika: Jeśli nie ma remoteId -> Tworzymy nowy (POST)
        // Jeśli ma remoteId (np. edytowaliśmy go offline) -> Aktualizujemy (PATCH)
        if (box.remoteId == null) {
          remoteId = await remoteDataSource.createBox(box);
        } else {
          await remoteDataSource.updateBox(box);
          remoteId = box.remoteId!;
        }

        // 4. Oznaczamy jako zsynchronizowane
        box.isSynced = true;
        box.remoteId = remoteId;
        await localDataSource.saveBox(box);

        print(' - Wysłano: ${box.itemName}');
      } catch (e) {
        print(' - Błąd wysyłki ${box.itemName}: $e');
        // Nie przerywamy pętli, próbujemy wysłać kolejne
      }
    }
    print('🏁 Synchronizacja zakończona.');
  }
  // W InventoryRepositoryImpl:

  @override
  Future<Map<String, int>> getLocalStats() async {
    final allBoxes = await localDataSource.getAllBoxes();

    final totalCount = allBoxes.length;
    // Liczymy te, które mają flagę isSynced = false
    final unsyncedCount = allBoxes.where((b) => !b.isSynced).length;

    return {
      'total': totalCount,
      'unsynced': unsyncedCount,
    };
  }

  @override
  Future<List<StorageBox>> searchBoxes(String query) async {
    // Przekazujemy zapytanie prosto do lokalnej bazy (Isar)
    return await localDataSource.searchBoxes(query);
  }
}
