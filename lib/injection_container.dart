import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- Dodaj import
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/network/network_info.dart';
import 'package:grid_storage_nfc/core/notifications/notification_service.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/firebase_inventory_remote_data_source.dart';
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
  // 1. EXTERNAL & SERVICES
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

  final packageInfo = await PackageInfo.fromPlatform();
  final packageName = packageInfo.packageName;

  print('🚀 Uruchamianie aplikacji. Pakiet: $packageName');

  // Sprawdzamy czy to wersja HOME (z Firebase)
  final bool isHomeMode = packageName.endsWith('.home') ||
      packageName == 'com.pryhodskyimykola.gridstorage';

  if (isHomeMode) {
    // ----------------------------------------------------
    // ŚCIEŻKA A: HOME (FIREBASE)
    // ----------------------------------------------------
    print('🏠 Tryb HOME wykryty. Inicjalizacja Firebase...');

    try {
      // 1. Inicjalizacja Aplikacji Firebase
      await Firebase.initializeApp();

      // 2. Rejestracja usług Firebase (Dostępne przez sl<T>())
      sl.registerLazySingleton(
          () => FirebaseAuth.instance); // <--- Ważne dla Auth
      sl.registerLazySingleton(() => FirebaseFirestore.instance);
      sl.registerLazySingleton(() => FirebaseStorage.instance);

      // 3. Rejestracja DataSource dla Firebase
      sl.registerLazySingleton<InventoryRemoteDataSource>(
        () => FirebaseInventoryRemoteDataSource(
          firestore: sl(),
          storage: sl(),
          // auth: sl(), // Opcjonalnie, jeśli wstrzykniesz auth do DataSource
        ),
      );
    } catch (e) {
      print('🔥 CRITICAL: Błąd inicjalizacji Firebase w trybie HOME: $e');
      // W razie awarii fallback do QNAP lub pustej implementacji?
      // Na razie zostawiamy, app pewnie się wysypie przy próbie użycia
    }
  } else {
    // ----------------------------------------------------
    // ŚCIEŻKA B: OFFICE (QNAP / OFFLINE)
    // ----------------------------------------------------
    print('🏢 Tryb OFFICE wykryty. Pomijam Firebase. Używanie QNAP API.');

    // UWAGA: Nie inicjujemy Firebase. Nie rejestrujemy FirebaseAuth.

    // Rejestracja DataSource dla QNAP (HTTP)
    sl.registerLazySingleton<InventoryRemoteDataSource>(
      () => InventoryRemoteDataSourceImpl(client: sl()),
    );
  }

  // ==========================================================
  // 3. CORE (Niezależne od Flavora)
  // ==========================================================

  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerFactory(() => ThemeCubit());

  // ServerStatusCubit - Decyduje o nazwie usługi w SettingsPage
  sl.registerFactory(() {
    if (isHomeMode) {
      return ServerStatusCubit(
        client: sl(),
        syncPendingItems: sl(),
        serviceName: 'Firebase',
        checkUrl: null, // Firebase ma własny status
      );
    } else {
      return ServerStatusCubit(
        client: sl(),
        syncPendingItems: sl(),
        serviceName: 'QNAP',
        checkUrl: 'http://192.168.1.40:3000/storage_boxes',
      );
    }
  });

  sl.registerFactory(() => LocalStorageCubit(repository: sl()));

  // ==========================================================
  // 4. DATA LAYER
  // ==========================================================

  sl.registerLazySingleton<InventoryLocalDataSource>(
    () => InventoryLocalDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // ==========================================================
  // 5. DOMAIN & PRESENTATION
  // ==========================================================

  sl.registerLazySingleton(() => GetInventoryList(sl()));
  sl.registerLazySingleton(() => GetInventoryItem(sl()));
  sl.registerLazySingleton(() => SaveInventoryItem(sl()));
  sl.registerLazySingleton(() => DeleteInventoryItem(sl()));
  sl.registerLazySingleton(() => GetLastUsedItem(sl()));
  sl.registerLazySingleton(() => SyncPendingItems(sl()));

  sl.registerFactory(
    () => InventoryBloc(
      getInventoryList: sl(),
      getInventoryItem: sl(),
      saveInventoryItem: sl(),
      deleteInventoryItem: sl(),
      getLastUsedItem: sl(),
      notificationService: sl(),
      nfcService: sl(),
    ),
  );
}
