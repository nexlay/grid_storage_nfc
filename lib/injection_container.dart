import 'package:cloud_firestore/cloud_firestore.dart'; // --- NOWE (Firebase)
import 'package:firebase_core/firebase_core.dart'; // --- NOWE (Firebase Core)
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:package_info_plus/package_info_plus.dart'; // --- NOWE (Do sprawdzania wersji Home/Office)

import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/network/network_info.dart';
import 'package:grid_storage_nfc/core/notifications/notification_service.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/firebase_inventory_remote_data_source.dart'; // --- NOWE
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_remote_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/delete_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_list.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_last_used_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/save_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/sync_pending_items.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ==========================================================
  // 1. EXTERNAL & SERVICES (Muszą być pierwsze)
  // ==========================================================

  // Isar (Baza lokalna)
  final isar = await InventoryLocalDataSourceImpl.init();
  sl.registerLazySingleton(() => isar);

  // Podstawowe usługi
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => InternetConnection());
  sl.registerLazySingleton(() => NfcService());
  sl.registerLazySingleton(() => NotificationService());

  // ==========================================================
  // 2. LOGIKA WYBORU FLAVORA (HOME vs OFFICE)
  // ==========================================================

  // Sprawdzamy nazwę pakietu
  final packageInfo = await PackageInfo.fromPlatform();
  final packageName = packageInfo.packageName;

  print('🚀 Uruchamianie aplikacji. Pakiet: $packageName');

  if (packageName.endsWith('.home')) {
    // ----------------------------------------------------
    // ŚCIEŻKA A: HOME (FIREBASE)
    // ----------------------------------------------------
    print('🏠 Tryb HOME wykryty. Inicjalizacja Firebase...');

    // Inicjalizacja Firebase
    await Firebase.initializeApp();

    // Rejestracja Firestore
    sl.registerLazySingleton(() => FirebaseFirestore.instance);

    // Rejestracja DataSource dla Firebase
    sl.registerLazySingleton<InventoryRemoteDataSource>(
      () => FirebaseInventoryRemoteDataSource(firestore: sl()),
    );
  } else {
    // ----------------------------------------------------
    // ŚCIEŻKA B: OFFICE (QNAP)
    // ----------------------------------------------------
    print('🏢 Tryb OFFICE wykryty. Używanie QNAP API.');

    // Rejestracja DataSource dla QNAP (HTTP)
    sl.registerLazySingleton<InventoryRemoteDataSource>(
      () => InventoryRemoteDataSourceImpl(client: sl()),
    );
  }

  // ==========================================================
  // 3. CORE (Niezależne od Flavora)
  // ==========================================================

  // Network Info
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // Core Cubits
  sl.registerFactory(() => ThemeCubit());

  // UWAGA: ServerStatusCubit jest zoptymalizowany pod QNAP.
  // W wersji Home będzie działać, ale 'checkConnection' może zawsze zwracać błąd pingowania QNAPa.
  // To nie wywali aplikacji, ale warto o tym pamiętać.
  sl.registerFactory(() {
    if (packageName.endsWith('.home')) {
      // === KONFIGURACJA DLA FIREBASE ===
      return ServerStatusCubit(
        client: sl(),
        syncPendingItems: sl(),
        serviceName: 'Firebase', // To wyświetlimy w ustawieniach
        checkUrl: null, // Null oznacza "sprawdzaj tylko internet"
      );
    } else {
      // === KONFIGURACJA DLA QNAP ===
      return ServerStatusCubit(
        client: sl(),
        syncPendingItems: sl(),
        serviceName: 'QNAP',
        checkUrl: 'http://192.168.1.40:3000/storage_boxes', // Adres biurowy
      );
    }
  });

  sl.registerFactory(() => LocalStorageCubit(repository: sl()));

  // ==========================================================
  // 4. DATA LAYER (Repozytoria i Źródła danych)
  // ==========================================================

  // Data Sources (Lokalne zawsze to samo)
  sl.registerLazySingleton<InventoryLocalDataSource>(
    () => InventoryLocalDataSourceImpl(sl()),
  );

  // Repositories
  // InventoryRepositoryImpl otrzyma odpowiednie remoteDataSource (Firebase lub HTTP)
  // w zależności od tego, co zarejestrowaliśmy w punkcie 2.
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // ==========================================================
  // 5. DOMAIN & PRESENTATION (Use Cases i BloC)
  // ==========================================================

  // Use Cases
  sl.registerLazySingleton(() => GetInventoryList(sl()));
  sl.registerLazySingleton(() => GetInventoryItem(sl()));
  sl.registerLazySingleton(() => SaveInventoryItem(sl()));
  sl.registerLazySingleton(() => DeleteInventoryItem(sl()));
  sl.registerLazySingleton(() => GetLastUsedItem(sl()));
  sl.registerLazySingleton(() => SyncPendingItems(sl()));

  // Bloc
  sl.registerFactory(
    () => InventoryBloc(
      getInventoryList: sl(),
      getInventoryItem: sl(),
      saveInventoryItem: sl(),
      deleteInventoryItem: sl(),
      getLastUsedItem: sl(),
      notificationService: sl(),
      nfcService: sl(), // Dodane (brakowało w Twoim wklejeniu)
    ),
  );
}
