import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http; // --- NOWE ---
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart'; // --- NOWE ---

import 'package:grid_storage_nfc/core/services/nfc_service.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/core/network/network_info.dart'; // --- NOWE ---

import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_remote_data_source.dart'; // --- NOWE ---
import 'package:grid_storage_nfc/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';

// Use Cases importy... (bez zmian)
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_list.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_last_used_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/save_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/delete_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/sync_pending_items.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- BLoC --- (bez zmian)
  sl.registerFactory(
    () => InventoryBloc(
      getInventoryList: sl(),
      getInventoryItem: sl(),
      saveInventoryItem: sl(),
      deleteInventoryItem: sl(),
      getLastUsedItem: sl(),
      nfcService: sl(),
    ),
  );

  // Core / Theme (bez zmian)
  sl.registerFactory(() => ThemeCubit());
  sl.registerFactory(() => ServerStatusCubit(
        client: sl(),
        syncPendingItems: sl(),
      ));

  // --- Core / Network ---
  // Rejestrujemy NetworkInfo
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // --- Use Cases --- (bez zmian)
  sl.registerLazySingleton(() => GetInventoryList(sl()));
  sl.registerLazySingleton(() => GetInventoryItem(sl()));
  sl.registerLazySingleton(() => SaveInventoryItem(sl()));
  sl.registerLazySingleton(() => DeleteInventoryItem(sl()));
  sl.registerLazySingleton(() => GetLastUsedItem(sl()));
  sl.registerLazySingleton(() => SyncPendingItems(sl()));
  sl.registerFactory(() => LocalStorageCubit(repository: sl()));

  // --- Repositories ---
  // Tutaj wstrzykniemy zaraz nowe zależności do konstruktora (zaktualizujemy to w następnym kroku)
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      networkInfo: sl(),
    ),
  );

  // --- Data Sources ---
  sl.registerLazySingleton<InventoryLocalDataSource>(
    () => InventoryLocalDataSourceImpl(sl()),
  );

  // Rejestracja Remote Data Source
  sl.registerLazySingleton<InventoryRemoteDataSource>(
    () => InventoryRemoteDataSourceImpl(client: sl()),
  );

  // --- External & Services ---
  final isar = await InventoryLocalDataSourceImpl.init();
  sl.registerLazySingleton(() => isar);
  sl.registerLazySingleton(() => NfcService());

  // Rejestracja HTTP Clienta i Internet Checkera
  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => InternetConnection());
}
