import 'package:firebase_auth/firebase_auth.dart'; // <--- 1. Import Firebase Auth
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/notifications/notification_service.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/login_page.dart'; // <--- 2. Import strony logowania
import 'package:grid_storage_nfc/features/inventory/presentation/pages/main_page.dart';
import 'package:grid_storage_nfc/injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  await di.sl<NotificationService>().init();
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
        BlocProvider(
          create: (_) => di.sl<ThemeCubit>(),
        ),
        BlocProvider(create: (_) => di.sl<ServerStatusCubit>()),
        BlocProvider(
          create: (_) => di.sl<LocalStorageCubit>()..loadStats(),
        ),
      ],
      // BlocBuilder nasłuchuje zmian motywu
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'Grid Storage NFC',
            themeMode: themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.blueGrey, brightness: Brightness.light),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blueGrey,
                brightness: Brightness.dark,
              ),
            ),
            // --- TUTAJ JEST ZMIANA (Auth Gate) ---
            home: StreamBuilder<User?>(
              // Nasłuchujemy zmian stanu logowania w czasie rzeczywistym
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                // 1. Jeśli Firebase sprawdza stan (np. przy starcie)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // 2. Jeśli mamy dane użytkownika -> JEST ZALOGOWANY
                if (snapshot.hasData) {
                  return const MainPage();
                }

                // 3. Jeśli nie ma danych -> NIEZALOGOWANY -> Pokaż ekran logowania
                return const LoginPage();
              },
            ),
          );
        },
      ),
    );
  }
}
