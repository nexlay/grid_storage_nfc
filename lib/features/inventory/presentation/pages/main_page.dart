import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Dodane dla kIsWeb
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/inventory_page.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/all_items_page.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/settings_page.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const InventoryPage(),
    const AllItemsPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });

          if (index == 0) {
            context.read<InventoryBloc>().add(const ResetInventory());
          } else if (index == 1) {
            context.read<InventoryBloc>().add(const LoadAllItems());
          }
        },
        destinations: [
          // --- BEZPIECZEŃSTWO WEB --- Zmiana ikony z NFC na QR Scanner
          NavigationDestination(
            icon: Icon(
                kIsWeb ? Icons.qr_code_scanner_outlined : Icons.nfc_outlined),
            selectedIcon: Icon(kIsWeb ? Icons.qr_code_scanner : Icons.nfc),
            label: kIsWeb ? 'Scan Code' : 'Scan NFC',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Items',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
