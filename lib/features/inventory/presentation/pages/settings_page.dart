import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/core/theme/theme_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Pobieramy aktualny motyw
    final themeMode = context.watch<ThemeCubit>().state;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('Settings'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader(context, 'Appearance'),

              // Theme Selector
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
              _buildSectionHeader(context, 'Data'),

              ListTile(
                leading: const Icon(Icons.cloud_off),
                title: const Text('Sync Status'),
                subtitle: const Text('Local Storage Only (Offline)'),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),

              const Divider(),
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
