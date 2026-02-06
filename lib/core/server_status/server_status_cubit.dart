import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/sync_pending_items.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

// --- DEFINICJE STANÓW ---
abstract class ServerStatusState {}

class ServerStatusInitial extends ServerStatusState {}

class ServerStatusDisabled extends ServerStatusState {}

class ServerStatusChecking extends ServerStatusState {}

class ServerStatusOnline extends ServerStatusState {}

class ServerStatusOffline extends ServerStatusState {}

// --- CUBIT ---
class ServerStatusCubit extends Cubit<ServerStatusState> {
  final http.Client client;
  final SyncPendingItems syncPendingItems;
  final String serviceName; // 'QNAP' lub 'Firebase'
  final String? checkUrl; // URL dla QNAP

  static const String _prefKey = 'sync_enabled';
  Timer? _statusTimer;
  bool _isSyncEnabled = true;

  ServerStatusCubit({
    required this.client,
    required this.syncPendingItems,
    required this.serviceName,
    this.checkUrl,
  }) : super(ServerStatusInitial()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isSyncEnabled = prefs.getBool(_prefKey) ?? true;

    if (_isSyncEnabled) {
      _startAutoRefresh();
    } else {
      emit(ServerStatusDisabled());
    }
  }

  void _startAutoRefresh() {
    checkConnection(); // Sprawdź od razu

    // Co 10 sekund sprawdzaj połączenie w tle
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isSyncEnabled) {
        checkConnection(isBackground: true);
      }
    });
  }

  Future<void> toggleSync(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enable);
    _isSyncEnabled = enable;

    if (enable) {
      _startAutoRefresh();
    } else {
      _statusTimer?.cancel();
      emit(ServerStatusDisabled());
    }
  }

  Future<void> checkConnection({bool isBackground = false}) async {
    if (!_isSyncEnabled) return;

    if (!isBackground) {
      emit(ServerStatusChecking());
    }

    try {
      bool isConnected = false;

      if (checkUrl != null) {
        // --- TRYB QNAP (Ping URL) ---
        try {
          final response = await client.get(Uri.parse(checkUrl!)).timeout(
                const Duration(seconds: 3),
              );
          // 200-299 uznajemy za sukces
          if (response.statusCode >= 200 && response.statusCode < 300) {
            isConnected = true;
          }
        } catch (_) {
          isConnected = false;
        }
      } else {
        // --- TRYB FIREBASE (Internet Check) ---
        isConnected = await InternetConnection().hasInternetAccess;
      }

      if (isConnected) {
        _tryAutoSync();
        emit(ServerStatusOnline());
      } else {
        emit(ServerStatusOffline());
      }
    } catch (_) {
      emit(ServerStatusOffline());
    }
  }

  Future<void> _tryAutoSync() async {
    try {
      await syncPendingItems();
    } catch (e) {
      // Błąd w tle - ignorujemy
    }
  }

  @override
  Future<void> close() {
    _statusTimer?.cancel();
    return super.close();
  }
}
