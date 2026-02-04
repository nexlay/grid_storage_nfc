import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/sync_pending_items.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'; // Dodaj import!

// ==========================================
// CZĘŚĆ 1: DEFINICJE STANÓW
// ==========================================

abstract class ServerStatusState {}

class ServerStatusInitial extends ServerStatusState {}

class ServerStatusDisabled extends ServerStatusState {}

class ServerStatusChecking extends ServerStatusState {}

class ServerStatusOnline extends ServerStatusState {}

class ServerStatusOffline extends ServerStatusState {}

// ==========================================
// CZĘŚĆ 2: LOGIKA (CUBIT)
// ==========================================

class ServerStatusCubit extends Cubit<ServerStatusState> {
  final http.Client client;
  final SyncPendingItems syncPendingItems;
  final String serviceName; // np. "QNAP" lub "Firebase"
  final String? checkUrl; // np. "http://192..." dla QNAP, null dla Firebase

  static const String _prefKey = 'sync_enabled';

  ServerStatusCubit({
    required this.client,
    required this.syncPendingItems,
    required this.serviceName,
    this.checkUrl,
  }) : super(ServerStatusInitial()) {
    _init();
  }

  // 1. Start: Sprawdź co użytkownik ustawił ostatnio
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_prefKey) ?? true;

    if (isEnabled) {
      checkConnection();
    } else {
      emit(ServerStatusDisabled());
    }
  }

  // 2. Przełącznik w ustawieniach
  Future<void> toggleSync(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enable);

    if (enable) {
      checkConnection();
    } else {
      emit(ServerStatusDisabled());
    }
  }

  // 3. Sprawdzanie połączenia
  Future<void> checkConnection() async {
    emit(ServerStatusChecking());

    try {
      bool isConnected = false;

      if (checkUrl != null) {
        // --- TRYB QNAP (Pingujemy konkretny serwer) ---
        try {
          final response = await client.get(Uri.parse(checkUrl!)).timeout(
                const Duration(seconds: 2),
              );
          if (response.statusCode == 200) {
            isConnected = true;
          }
        } catch (e) {
          isConnected = false;
        }
      } else {
        // --- TRYB FIREBASE (Sprawdzamy tylko czy jest internet) ---
        // Firebase sam dba o resztę, ważne żeby telefon miał sieć
        isConnected = await InternetConnection().hasInternetAccess;
      }

      if (isConnected) {
        // Połączenie jest OK.
        // Teraz uruchamiamy synchronizację zaległych itemów w tle
        // (nie czekamy aż się skończy, żeby nie blokować UI)
        syncPendingItems().then((_) {
          print('🔄 Auto-sync ($serviceName) triggered from StatusCubit');
        });

        emit(ServerStatusOnline());
      } else {
        emit(ServerStatusOffline());
      }
    } catch (e) {
      emit(ServerStatusOffline());
    }
  }
}
