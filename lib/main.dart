import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// --- IMPORTS BLOC/CUBIT ---
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/auth/auth_bloc.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';

// --- IMPORTS PAGES ---
import 'package:grid_storage_nfc/features/inventory/presentation/pages/main_page.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/login_page.dart';

// --- IMPORT DI ---
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicjalizacja zależności (Firebase, Isar, API, itp.)
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rejestrujemy wszystkie Bloc i Cubity na najwyższym poziomie aplikacji
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(AuthCheckRequested()),
        ),
        BlocProvider<InventoryBloc>(
          create: (_) => di.sl<InventoryBloc>(),
        ),
        // --- BRAKUJĄCE CUBITY DODANE TUTAJ ---
        BlocProvider<LocalStorageCubit>(
          create: (_) => di.sl<LocalStorageCubit>()
            ..loadStats(), // od razu ładujemy statystyki
        ),
        BlocProvider<ServerStatusCubit>(
          create: (_) => di.sl<ServerStatusCubit>(),
        ),
        BlocProvider<ThemeCubit>(
          create: (_) => di.sl<ThemeCubit>(),
        ),
      ],
      // BlocBuilder dla motywu (jasny/ciemny)
      child: BlocBuilder<ThemeCubit, ThemeMode>(builder: (context, themeMode) {
        return MaterialApp(
          title: 'Grid Storage',
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue, brightness: Brightness.dark),
          ),
          home: const AuthWrapper(),
        );
      }),
    );
  }
}

// Widget decydujący, czy pokazać LoginPage czy aplikację
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          // Zalogowany -> idziemy do głównego ekranu z nawigacją
          return const MainPage();
        } else if (state is Unauthenticated || state is AuthError) {
          // Niezalogowany lub błąd -> Ekran logowania
          return const LoginPage();
        }

        // Ładowanie
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
