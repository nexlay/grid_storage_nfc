import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart'; // Do sprawdzania czy Firebase żyje
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/services/auth_service.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/theme_selector_card.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/about_card.dart';
import 'package:grid_storage_nfc/injection_container.dart' as di;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // --- LOGIKA WYLOGOWANIA ---
  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
            'Are you sure you want to log out?\nThis will clear local data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      try {
        await di.sl<InventoryLocalDataSource>().clearAll();
      } catch (e) {
        debugPrint("Błąd czyszczenia bazy: $e");
      }

      if (context.mounted) {
        context.read<InventoryBloc>().add(const ResetInventory());
        // Wylogowujemy tylko jeśli Firebase działa
        try {
          if (Firebase.apps.isNotEmpty) {
            await AuthService().signOut();
          }
        } catch (_) {}
      }
    }
  }

  // --- LOGIKA USUWANIA KONTA ---
  Future<void> _handleDeleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE ACCOUNT'),
        content: const Text(
            'Warning: This action cannot be undone.\n\n'
            'We will ask you to confirm your Google Account one last time before deletion.',
            style: TextStyle(color: Colors.red)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final navigator = Navigator.of(context);

      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        await di.sl<InventoryLocalDataSource>().clearAll();
        if (context.mounted) {
          context.read<InventoryBloc>().add(const ResetInventory());
        }

        await AuthService().deleteUserAccount();
        navigator.pop();
      } catch (e) {
        navigator.pop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Account deletion failed: ${e.toString()}"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- BEZPIECZNE POBIERANIE DANYCH UŻYTKOWNIKA ---
    String displayName = 'Local User';
    String email = 'Offline / QNAP Mode';
    String? photoUrl;
    bool isFirebase = false;

    try {
      if (Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          displayName = user.displayName ?? 'User';
          email = user.email ?? '';
          photoUrl = user.photoURL;
          isFirebase = true;
        }
      }
    } catch (_) {
      // Ignorujemy błędy Firebase w trybie Office
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader(context, 'Data & Synchronization'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // LOCAL DATABASE
                    BlocBuilder<LocalStorageCubit, LocalStorageState>(
                      builder: (context, state) {
                        int total =
                            state is LocalStorageLoaded ? state.totalItems : 0;
                        int pending = state is LocalStorageLoaded
                            ? state.unsyncedItems
                            : 0;

                        return ListTile(
                          leading: const Icon(Icons.storage_rounded,
                              color: Colors.blue),
                          title: const Text('Local Database'),
                          subtitle: Text(pending > 0
                              ? '$total items stored\n($pending pending sync)'
                              : '$total items stored'),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () =>
                                context.read<LocalStorageCubit>().loadStats(),
                          ),
                        );
                      },
                    ),

                    const Divider(height: 1),

                    // --- REMOTE STORAGE (QNAP / FIREBASE) ---
                    // Tutaj przywrócono logikę wyświetlania błędu VPN
                    BlocBuilder<ServerStatusCubit, ServerStatusState>(
                      builder: (context, state) {
                        final cubit = context.read<ServerStatusCubit>();
                        final serviceName = cubit.serviceName;

                        bool isSwitchOn = false;
                        String subtitle = "$serviceName Sync is off";
                        Color iconColor = Colors.grey;
                        IconData icon = Icons.cloud_off_rounded;

                        if (state is ServerStatusDisabled) {
                          isSwitchOn = false;
                          subtitle = "Sync is disabled";
                          iconColor = Colors.grey;
                        } else if (state is ServerStatusChecking) {
                          isSwitchOn = true;
                          subtitle = "Connecting to $serviceName...";
                          iconColor = Colors.orange;
                          icon = Icons.sync;
                        } else if (state is ServerStatusOnline) {
                          isSwitchOn = true;
                          subtitle = "Connected";
                          iconColor = Colors.green;
                          if (serviceName == 'Firebase') {
                            icon = Icons.local_fire_department_rounded;
                          } else {
                            icon = Icons.dns_rounded;
                          }
                        } else if (state is ServerStatusOffline) {
                          // <--- TU JEST PRZYWRÓCONA LOGIKA DLA BRAKU VPN --->
                          isSwitchOn = true;
                          subtitle = "Offline (Check Internet/VPN)";
                          iconColor = Colors.red;
                          icon = Icons.signal_wifi_off;
                        } else {
                          isSwitchOn = true;
                          subtitle = "Initializing...";
                        }

                        return SwitchListTile(
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: iconColor, size: 24),
                          ),
                          title: Text("$serviceName Sync"),
                          subtitle: Text(subtitle,
                              style: TextStyle(
                                  color: iconColor,
                                  // Jeśli offline/błąd, pogrubiamy tekst
                                  fontWeight: (state is ServerStatusOffline)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12)),
                          value: isSwitchOn,
                          onChanged: (val) =>
                              context.read<ServerStatusCubit>().toggleSync(val),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildSectionHeader(context, 'Appearance'),
              const ThemeSelectorCard(),
              const SizedBox(height: 8),
              _buildSectionHeader(context, 'About'),
              const AboutCard(),
              const SizedBox(height: 8),
              _buildSectionHeader(context, 'Account'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Text(displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U')
                            : null,
                      ),
                      title: Text(displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                    ),
                    // Przyciski widoczne tylko jeśli mamy Firebase (Flavor HOME)
                    if (isFirebase) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.orange),
                        title: const Text('Log Out',
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                        onTap: () => _handleLogout(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Delete Account',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        subtitle: const Text("Permanently delete data & user"),
                        onTap: () => _handleDeleteAccount(context),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
