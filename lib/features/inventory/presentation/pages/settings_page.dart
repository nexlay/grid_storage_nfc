import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
        await AuthService().signOut();
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
      // ZAPAMIĘTUJEMY NAWIGATOR, aby móc zamknąć loader po zniszczeniu strony
      final navigator = Navigator.of(context);

      try {
        // Pokazujemy loader
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        // 1. Czyścimy lokalnie
        await di.sl<InventoryLocalDataSource>().clearAll();
        if (context.mounted) {
          context.read<InventoryBloc>().add(const ResetInventory());
        }

        // 2. Usuwamy konto i zrywamy sesję Google (disconnect)
        await AuthService().deleteUserAccount();

        // 3. ZAMYKAMY LOADER (używając zapamiętanego navigatora)
        navigator.pop();
      } catch (e) {
        // Zamykamy loader w razie błędu
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
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? 'User';
    final String email = user?.email ?? '';
    final String? photoUrl = user?.photoURL;

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
                    BlocBuilder<LocalStorageCubit, LocalStorageState>(
                      builder: (context, state) {
                        int total =
                            state is LocalStorageLoaded ? state.totalItems : 0;
                        return ListTile(
                          leading: const Icon(Icons.storage_rounded,
                              color: Colors.blue),
                          title: const Text('Local Database'),
                          subtitle: Text('$total items stored'),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () =>
                                context.read<LocalStorageCubit>().loadStats(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    BlocBuilder<ServerStatusCubit, ServerStatusState>(
                      builder: (context, state) {
                        final serviceName =
                            context.read<ServerStatusCubit>().serviceName;
                        bool isSwitchOn = state is! ServerStatusDisabled;
                        return SwitchListTile(
                          secondary:
                              const Icon(Icons.cloud_sync, color: Colors.green),
                          title: Text("$serviceName Sync"),
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
                            ? Text(
                                displayName.isNotEmpty ? displayName[0] : 'U')
                            : null,
                      ),
                      title: Text(displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                    ),
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
                              color: Colors.red, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Permanently delete data & user"),
                      onTap: () => _handleDeleteAccount(context),
                    ),
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
