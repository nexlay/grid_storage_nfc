import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // <--- 1. IMPORT
import 'package:get_it/get_it.dart';
// import 'package:grid_storage_nfc/features/inventory/data/repositories/qnap_auth_repository_impl';
// import 'package:grid_storage_nfc/features/inventory/domain/usecases/search_inventory_items';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/auth/auth_bloc.dart';

import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/network/network_info.dart';
import 'package:grid_storage_nfc/core/notifications/notification_service.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';
import 'package:grid_storage_nfc/core/services/auth_service.dart'; // <--- 2. Core Auth Service
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';

// --- IMPORTS: AUTH REPOSITORIES (z Twojego folderu inventory) ---
import 'package:grid_storage_nfc/features/inventory/domain/repositories/auth_repository.dart';
import 'package:grid_storage_nfc/features/inventory/data/repositories/firebase_auth_repository_impl.dart';

// --- IMPORTS: AUTH USECASES ---
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/login_user.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/logout_user.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/check_auth_status.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/auth/get_user_role.dart';

// --- IMPORTS: AUTH BLOC ---

// --- IMPORTS: INVENTORY ---

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

  // Secure Storage (dla tokena QNAP)
  sl.registerLazySingleton(() => const FlutterSecureStorage());

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
      await Firebase.initializeApp();

      // Firebase Services
      sl.registerLazySingleton(() => FirebaseAuth.instance);
      sl.registerLazySingleton(() => FirebaseFirestore.instance);
      sl.registerLazySingleton(() => FirebaseStorage.instance);

      // --- AUTHENTICATION (HOME) ---
      // Rejestrujemy Twój AuthService (Core Wrapper)
      sl.registerLazySingleton(() => AuthService());

      // Rejestrujemy Repozytorium (Adapter Firebase)
      sl.registerLazySingleton<AuthRepository>(
        () => FirebaseAuthRepository(sl()),
      );

      // Inventory DataSource
      sl.registerLazySingleton<InventoryRemoteDataSource>(
        () => FirebaseInventoryRemoteDataSource(
          firestore: sl(),
          storage: sl(),
        ),
      );
    } catch (e) {
      print('🔥 CRITICAL: Błąd inicjalizacji Firebase w trybie HOME: $e');
    }
  } else {
    // ----------------------------------------------------
    // ŚCIEŻKA B: OFFICE (QNAP / OFFLINE)
    // ----------------------------------------------------
    print('🏢 Tryb OFFICE wykryty. Pomijam Firebase. Używanie QNAP API.');

    // --- AUTHENTICATION (OFFICE) ---
    // Rejestrujemy Repozytorium (Adapter QNAP)
      // TODO: Implement QNAP auth repository
      // sl.registerLazySingleton<AuthRepository>(
      //   () => QnapAuthRepository(client: sl(), storage: sl()) as AuthRepository,
      // );

    // Inventory DataSource
    sl.registerLazySingleton<InventoryRemoteDataSource>(
      () => InventoryRemoteDataSourceImpl(client: sl()),
    );
  }

  // ==========================================================
  // 3. CORE (Niezależne od Flavora)
  // ==========================================================

  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerFactory(() => ThemeCubit());

  // ServerStatusCubit
  sl.registerFactory(() {
    if (isHomeMode) {
      return ServerStatusCubit(
        client: sl(),
        syncPendingItems: sl(),
        serviceName: 'Firebase',
        checkUrl: null,
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
  // 4. DATA LAYER (Inventory)
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
  // 5. DOMAIN (UseCases)
  // ==========================================================

  // --- INVENTORY USECASES ---
  sl.registerLazySingleton(() => GetInventoryList(sl()));
  sl.registerLazySingleton(() => GetInventoryItem(sl()));
  sl.registerLazySingleton(() => SaveInventoryItem(sl()));
  sl.registerLazySingleton(() => DeleteInventoryItem(sl()));
  sl.registerLazySingleton(() => GetLastUsedItem(sl()));
  sl.registerLazySingleton(() => SyncPendingItems(sl()));
  // sl.registerLazySingleton(() => SearchInventoryItems(sl()));

  // --- AUTH USECASES (NOWE) ---
  sl.registerLazySingleton(() => LoginUser(sl()));
  sl.registerLazySingleton(() => LogoutUser(sl()));
  sl.registerLazySingleton(() => CheckAuthStatus(sl()));
  sl.registerLazySingleton(() => GetUserRole(sl()));

  // ==========================================================
  // 6. PRESENTATION (Blocs)
  // ==========================================================

  // --- AUTH BLOC ---
  sl.registerFactory(
    () => AuthBloc(
      loginUser: sl(),
      logoutUser: sl(),
      checkAuthStatus: sl(),
      getUserRole: sl(),
    ),
  );

  // --- INVENTORY BLOC ---
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
