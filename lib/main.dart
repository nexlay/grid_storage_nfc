import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/main_page.dart';
import 'package:grid_storage_nfc/injection_container.dart' as di;
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => di.sl<InventoryBloc>()..add(const ResetInventory()),
        ),
        // Rejestracja ThemeCubit
        BlocProvider(
          create: (_) => di.sl<ThemeCubit>(),
        ),
        BlocProvider(
          create: (_) => di.sl<ServerStatusCubit>()
            ..checkConnection(), // Od razu sprawdź przy starcie
        ),
        BlocProvider(
          create: (_) => di.sl<LocalStorageCubit>()
            ..loadStats(), // Od razu ładujemy statystyki
        ),
      ],
      // BlocBuilder nasłuchuje zmian motywu
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'Grid Storage NFC',
            themeMode: themeMode, // Dynamiczny motyw
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blueGrey, brightness: Brightness.light),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blueGrey,
                  brightness: Brightness.dark // Tryb ciemny
                  ),
            ),
            home: const MainPage(), // Startujemy od MainPage
          );
        },
      ),
    );
  }
}
