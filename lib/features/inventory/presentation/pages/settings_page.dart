import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';
import 'package:grid_storage_nfc/core/server_status/server_status_cubit.dart';
import 'package:grid_storage_nfc/core/local_storage/local_storage_cubit.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/theme_selector_card.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/about_card.dart';

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
              // --- DATA & SYNC (ZGRUPOWANE) ---
              _buildSectionHeader(context, 'Data & Synchronization'),

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 0, // Styl "Flat"
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    // 1. LOCAL STORAGE (ISAR)
                    BlocBuilder<LocalStorageCubit, LocalStorageState>(
                      builder: (context, state) {
                        int total = 0;
                        int pending = 0;
                        String subtitle = 'Checking database...';
                        IconData icon = Icons.storage_rounded;
                        Color iconColor = Theme.of(context).colorScheme.primary;

                        if (state is LocalStorageLoaded) {
                          total = state.totalItems;
                          pending = state.unsyncedItems;

                          if (pending > 0) {
                            subtitle =
                                '$total items stored\n($pending pending sync)';
                            iconColor = Colors.orange;
                          } else {
                            subtitle = '$total items stored (All synced)';
                            iconColor = Colors.blue;
                          }
                        }

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: iconColor, size: 24),
                          ),
                          title: const Text('Local Database'),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              context.read<LocalStorageCubit>().loadStats();
                            },
                          ),
                        );
                      },
                    ),

                    // Linia oddzielająca
                    Divider(
                      height: 1,
                      indent: 56, // Wcięcie, żeby nie przecinało ikony
                      endIndent: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.5),
                    ),

                    // 2. REMOTE STORAGE (QNAP)
                    BlocBuilder<ServerStatusCubit, ServerStatusState>(
                      builder: (context, state) {
                        bool isSwitchOn = false;
                        String subtitle = "Disabled";
                        Color iconColor = Colors.grey;
                        IconData icon = Icons.cloud_off_rounded;

                        if (state is ServerStatusDisabled) {
                          isSwitchOn = false;
                          subtitle = "Sync is off";
                          iconColor = Colors.grey;
                        } else if (state is ServerStatusChecking) {
                          isSwitchOn = true;
                          subtitle = "Connecting...";
                          iconColor = Colors.orange;
                          icon = Icons.sync;
                        } else if (state is ServerStatusOnline) {
                          isSwitchOn = true;
                          subtitle = "Connected (192.168.1.40)";
                          iconColor = Colors.green;
                          icon = Icons.cloud_done_rounded;
                        } else if (state is ServerStatusOffline) {
                          isSwitchOn = true;
                          subtitle = "Offline (Check VPN)";
                          iconColor = Colors.red;
                          icon = Icons.cloud_off_rounded;
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
                          title: const Text("QNAP Sync"),
                          subtitle: Text(subtitle,
                              style: TextStyle(color: iconColor)),
                          value: isSwitchOn,
                          onChanged: (bool value) {
                            context.read<ServerStatusCubit>().toggleSync(value);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              // --- APPEARANCE ---

              _buildSectionHeader(context, 'Appearance'),

              const ThemeSelectorCard(),

              const SizedBox(height: 8),

              // --- ABOUT ---
              _buildSectionHeader(context, 'About'),

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
