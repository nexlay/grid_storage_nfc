import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/sync_pending_items.dart';

// ==========================================
// CZĘŚĆ 1: DEFINICJE STANÓW (Tego brakowało)
// ==========================================

abstract class ServerStatusState {}

class ServerStatusInitial extends ServerStatusState {}

// Stan: Użytkownik ręcznie wyłączył synchronizację
class ServerStatusDisabled extends ServerStatusState {}

// Stan: Trwa sprawdzanie połączenia (kręciołek)
class ServerStatusChecking extends ServerStatusState {}

// Stan: Połączono z QNAP (Zielona chmurka)
class ServerStatusOnline extends ServerStatusState {}

// Stan: Błąd połączenia (Czerwona chmurka)
class ServerStatusOffline extends ServerStatusState {}

// ==========================================
// CZĘŚĆ 2: LOGIKA (CUBIT)
// ==========================================

class ServerStatusCubit extends Cubit<ServerStatusState> {
  final http.Client client;
  final SyncPendingItems syncPendingItems; // Nasz UseCase do synchronizacji

  static const String _url = 'http://192.168.1.40:3000/storage_boxes';
  static const String _prefKey = 'sync_enabled';

  ServerStatusCubit({required this.client, required this.syncPendingItems})
      : super(ServerStatusInitial()) {
    _init();
  }

  // 1. Start: Sprawdź co użytkownik ustawił ostatnio
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_prefKey) ?? true; // Domyślnie włączone

    if (isEnabled) {
      checkConnection();
    } else {
      emit(ServerStatusDisabled());
    }
  }

  // 2. Przełącznik (To podepniemy pod guzik w ustawieniach)
  Future<void> toggleSync(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enable);

    if (enable) {
      checkConnection(); // Jak włączył -> sprawdź połączenie
    } else {
      emit(ServerStatusDisabled()); // Jak wyłączył -> ustaw stan disabled
    }
  }

  // 3. Sprawdzanie połączenia (Ping) + Synchronizacja
  Future<void> checkConnection() async {
    emit(ServerStatusChecking());

    try {
      final response = await client.get(Uri.parse(_url)).timeout(
            const Duration(seconds: 2),
          );

      if (response.statusCode == 200) {
        // Połączenie jest OK.
        // Teraz uruchamiamy synchronizację zaległych danych (jeśli są)
        await syncPendingItems();

        emit(ServerStatusOnline());
      } else {
        emit(ServerStatusOffline());
      }
    } catch (e) {
      emit(ServerStatusOffline());
    }
  }
}
