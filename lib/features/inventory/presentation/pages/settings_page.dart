import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/core/services/auth_service.dart';
import 'package:grid_storage_nfc/features/inventory/data/datasources/inventory_local_data_source.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/theme_selector_card.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/about_card.dart';
import 'package:grid_storage_nfc/injection_container.dart' as di;
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/auth/auth_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // --- LOGOUT LOGIC ---
  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
            'Are you sure you want to log out?\nLocal data will be cleared.'),
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
        debugPrint("Database clear error: $e");
      }

      if (context.mounted) {
        context.read<InventoryBloc>().add(const ResetInventory());
        context.read<AuthBloc>().add(LogoutRequested());
      }
    }
  }

  // --- DELETE ACCOUNT LOGIC (Only for HOME/Firebase) ---
  Future<void> _handleDeleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE ACCOUNT'),
        content: const Text(
            'Warning: This action is irreversible.\n\n'
            'You will be asked to confirm your Google account before deletion.',
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
        if (context.mounted) {
          context.read<AuthBloc>().add(LogoutRequested());
        }
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

  // --- UNIVERSAL STATUS WIDGET ---
  Widget _buildStatusTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isSwitch,
    bool switchValue = false,
    Function(bool)? onSwitchChanged,
    VoidCallback? onTap,
    bool isBold = false,
  }) {
    final leadingIcon = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );

    final titleWidget = Text(title);
    final subtitleWidget = Text(
      subtitle,
      style: TextStyle(
        color: color,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );

    if (isSwitch) {
      return SwitchListTile(
        secondary: leadingIcon,
        title: titleWidget,
        subtitle: subtitleWidget,
        value: switchValue,
        onChanged: onSwitchChanged,
      );
    } else {
      return ListTile(
        leading: leadingIcon,
        title: titleWidget,
        subtitle: subtitleWidget,
        trailing: onTap != null
            ? IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: onTap,
              )
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final bool isAuthenticated = authState is Authenticated;

    // --- AUTH DATA EXTRACTION ---
    String displayName = 'Corporate Account (QNAP)';
    String email = '';
    String roleInfo = 'Role: USER';
    String? photoUrl;
    bool isFirebase = false;

    // 1. Check for QNAP Auth Data (AuthBloc)
    if (isAuthenticated) {
      roleInfo = 'Role: ${authState.role.toUpperCase()}';
      // In QNAP mode, we often use the email from AuthBloc if available
      email = authState.email;
    }

    // 2. Check for Firebase Auth Data (if exists)
    try {
      if (Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          displayName = user.displayName ?? 'Home User';
          email = user.email ?? '';
          photoUrl = user.photoURL;
          isFirebase = true;
          // In Firebase mode, role isn't typically stored in state like QNAP
          roleInfo = '';
        }
      }
    } catch (_) {}

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Settings')),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader(context, 'Account & Login'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isFirebase
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                        backgroundImage:
                            photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Icon(
                                isFirebase ? Icons.home : Icons.business,
                                color: isFirebase ? Colors.orange : Colors.blue,
                              )
                            : null,
                      ),
                      title: Text(displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      // --- UPDATED SUBTITLE TO SHOW EMAIL AND ROLE ---
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (email.isNotEmpty)
                            Text(email, style: const TextStyle(fontSize: 13)),
                          if (roleInfo.isNotEmpty)
                            Text(roleInfo,
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (isAuthenticated)
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.orange),
                        title: const Text('Log Out',
                            style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                        onTap: () => _handleLogout(context),
                      ),
                    if (isFirebase) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Delete Account',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                        onTap: () => _handleDeleteAccount(context),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildSectionHeader(context, 'Database & Synchronization'),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    BlocBuilder<LocalStorageCubit, LocalStorageState>(
                      builder: (context, state) {
                        int total = 0;
                        int pending = 0;

                        if (state is LocalStorageLoaded) {
                          total = state.totalItems;
                          pending = state.unsyncedItems;
                        }

                        final bool hasPending = pending > 0;
                        final Color color =
                            hasPending ? Colors.orange : Colors.blue;
                        final IconData icon = hasPending
                            ? Icons.cloud_upload_outlined
                            : Icons.storage_rounded;
                        final String statusText = hasPending
                            ? '$total in database\n($pending pending sync)'
                            : '$total in database (Synced)';

                        return _buildStatusTile(
                          icon: icon,
                          color: color,
                          title: 'Local Database',
                          subtitle: statusText,
                          isSwitch: false,
                          onTap: () =>
                              context.read<LocalStorageCubit>().loadStats(),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    BlocBuilder<ServerStatusCubit, ServerStatusState>(
                      builder: (context, state) {
                        final cubit = context.read<ServerStatusCubit>();
                        final serviceName = cubit.serviceName;

                        bool isSwitchOn = true;
                        String subtitle = "Initializing...";
                        Color color = Colors.grey;
                        IconData icon = Icons.help_outline;
                        bool isBold = false;

                        if (state is ServerStatusDisabled) {
                          isSwitchOn = false;
                          subtitle = "Synchronization disabled";
                          color = Colors.grey;
                          icon = Icons.cloud_off_rounded;
                        } else if (state is ServerStatusChecking) {
                          isSwitchOn = true;
                          subtitle = "Connecting...";
                          color = Colors.orange;
                          icon = Icons.sync;
                        } else if (state is ServerStatusOnline) {
                          isSwitchOn = true;
                          subtitle = "Connected";
                          color = Colors.green;
                          icon = serviceName == 'Firebase'
                              ? Icons.local_fire_department_rounded
                              : Icons.dns_rounded;
                        } else if (state is ServerStatusOffline) {
                          isSwitchOn = true;
                          subtitle = serviceName == 'QNAP'
                              ? "No connection (Check VPN)"
                              : "No internet connection";
                          color = Colors.red;
                          icon = Icons.signal_wifi_off;
                          isBold = true;
                        }

                        return _buildStatusTile(
                          icon: icon,
                          color: color,
                          title: "$serviceName Sync",
                          subtitle: subtitle,
                          isSwitch: true,
                          switchValue: isSwitchOn,
                          isBold: isBold,
                          onSwitchChanged: (val) =>
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
              _buildSectionHeader(context, 'About App'),
              const AboutCard(),
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
