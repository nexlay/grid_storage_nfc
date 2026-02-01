import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
// 1. Dodano import dla LocalStorageCubit
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeCubit>().state;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // --- APPEARANCE ---
              _buildSectionHeader(context, 'Appearance'),

              ListTile(
                leading: const Icon(Icons.brightness_6),
                title: const Text('App Theme'),
                subtitle: Text(_getThemeName(themeMode)),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox(),
                  onChanged: (ThemeMode? newValue) {
                    if (newValue != null) {
                      context.read<ThemeCubit>().updateTheme(newValue);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                        value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(
                        value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(
                        value: ThemeMode.dark, child: Text('Dark')),
                  ],
                ),
              ),

              const Divider(),

              // --- NOWA SEKCJA: LOCAL STORAGE ---
              _buildSectionHeader(context, 'Local Storage'),

              BlocBuilder<LocalStorageCubit, LocalStorageState>(
                builder: (context, state) {
                  int total = 0;
                  int pending = 0;
                  String subtitle = 'Checking database...';
                  IconData icon = Icons.storage;
                  Color iconColor = Colors.blueGrey;

                  if (state is LocalStorageLoaded) {
                    total = state.totalItems;
                    pending = state.unsyncedItems;

                    if (pending > 0) {
                      subtitle =
                          '$total items stored ($pending pending sync ⏳)';
                      iconColor = Colors.orange; // Ostrzeżenie: coś czeka
                    } else {
                      subtitle = '$total items stored (All synced ✅)';
                      iconColor = Colors.blue; // Wszystko OK
                    }
                  }

                  return ListTile(
                    leading: Icon(icon, color: iconColor),
                    title: const Text('Isar Database'),
                    subtitle: Text(subtitle),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        // Ręczne odświeżenie statystyk
                        context.read<LocalStorageCubit>().loadStats();
                      },
                    ),
                  );
                },
              ),

              const Divider(),

              // --- CONNECTION (QNAP) ---
              _buildSectionHeader(context, 'Remote Storage'),

              BlocBuilder<ServerStatusCubit, ServerStatusState>(
                builder: (context, state) {
                  // Domyślne wartości UI
                  bool isSwitchOn = false;
                  String subtitle = "Disabled";
                  Color iconColor = Colors.grey;
                  IconData icon = Icons.cloud_off;

                  // Logika wyświetlania w zależności od stanu
                  if (state is ServerStatusDisabled) {
                    isSwitchOn = false;
                    subtitle = "Connection disabled";
                    iconColor = Colors.grey;
                    icon = Icons.cloud_off;
                  } else if (state is ServerStatusChecking) {
                    isSwitchOn = true;
                    subtitle = "Connecting...";
                    iconColor = Colors.orange;
                    icon = Icons.sync;
                  } else if (state is ServerStatusOnline) {
                    isSwitchOn = true;
                    subtitle = "Online (192.168.1.40)";
                    iconColor = Colors.green;
                    icon = Icons.cloud_done;
                  } else if (state is ServerStatusOffline) {
                    isSwitchOn = true;
                    subtitle = "Offline (VPN required?)";
                    iconColor = Colors.red;
                    icon = Icons.error_outline;
                  } else {
                    isSwitchOn = true;
                    subtitle = "Initializing...";
                  }

                  return SwitchListTile(
                    secondary: Icon(icon, color: iconColor),
                    title: const Text("QNAP Sync"),
                    subtitle:
                        Text(subtitle, style: TextStyle(color: iconColor)),
                    value: isSwitchOn,
                    onChanged: (bool value) {
                      context.read<ServerStatusCubit>().toggleSync(value);
                    },
                  );
                },
              ),

              const Divider(),

              // --- ABOUT ---
              _buildSectionHeader(context, 'About'),

              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Version'),
                subtitle: Text('1.0.0 (Clean Architecture)'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow System';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }
}
