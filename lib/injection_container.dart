import 'package:get_it/get_it.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';
// Import Use Cases
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_list.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/get_last_used_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/save_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/domain/usecases/delete_inventory_item.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // --- BLoC ---
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

  // Core / Theme
  sl.registerFactory(() => ThemeCubit());

  // --- Use Cases ---
  sl.registerLazySingleton(() => GetInventoryList(sl()));
  sl.registerLazySingleton(() => GetInventoryItem(sl()));
  sl.registerLazySingleton(() => SaveInventoryItem(sl()));
  sl.registerLazySingleton(() => DeleteInventoryItem(sl()));
  sl.registerLazySingleton(() => GetLastUsedItem(sl()));

  // --- Repositories ---
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(localDataSource: sl()),
  );

  // --- Data Sources ---
  sl.registerLazySingleton<InventoryLocalDataSource>(
    () => InventoryLocalDataSourceImpl(sl()),
  );

  // --- External & Services ---
  final isar = await InventoryLocalDataSourceImpl.init();
  sl.registerLazySingleton(() => isar);
  sl.registerLazySingleton(() => NfcService());
}
