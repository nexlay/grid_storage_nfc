import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // <--- Dodaj ten import
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/notifications/notification_service.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/login_page.dart';
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
    // 1. Sprawdzamy bezpiecznie, czy Firebase jest gotowy
    final serverCubit = di.sl<ServerStatusCubit>();
    bool useFirebase = false;

    try {
      // Jeśli w injection_container.dart zainicjowaliśmy Firebase, to lista apps nie będzie pusta
      useFirebase =
          Firebase.apps.isNotEmpty && serverCubit.serviceName == 'Firebase';
    } catch (_) {
      useFirebase = false;
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => di.sl<InventoryBloc>()..add(const ResetInventory()),
        ),
        BlocProvider(create: (_) => di.sl<ThemeCubit>()),
        BlocProvider(create: (_) => serverCubit),
        BlocProvider(create: (_) => di.sl<LocalStorageCubit>()..loadStats()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'Grid Storage NFC',
            themeMode: themeMode,
            theme:
                ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
            darkTheme: ThemeData(
                useMaterial3: true,
                colorSchemeSeed: Colors.blueGrey,
                brightness: Brightness.dark),

            // 2. Warunek: Jeśli nie ma Firebase, idź prosto do MainPage
            home: useFirebase ? const AuthGate() : const MainPage(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? const MainPage() : const LoginPage();
      },
    );
  }
}
