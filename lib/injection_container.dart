import 'package:get_it/get_it.dart';
import 'package:grid_storage_nfc/core/services/nfc_service.dart';
import 'package:grid_storage_nfc/features/inventory/data/repositories/inventory_repository_impl.dart';
import 'package:grid_storage_nfc/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:isar/isar.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // BLoC
  sl.registerFactory(
    () => InventoryBloc(
      sl(),
      sl(),
    ),
  );

  // Repositories
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(sl()),
  );

  // Services
  sl.registerLazySingleton(() => NfcService());

  // External
  final isar = await InventoryRepositoryImpl.init();
  sl.registerLazySingleton<Isar>(() => isar);
}
