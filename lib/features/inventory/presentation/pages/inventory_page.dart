import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';
// WAŻNE: Import widgetu 3D, żeby model działał
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/box_3d_viewer.dart';
import 'package:intl/intl.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Główny przycisk skanowania (FAB)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<InventoryBloc>().add(const ScanTagRequested());
        },
        icon: const Icon(Icons.nfc),
        label: const Text('Scan Tag'),
        elevation: 4,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (previous, current) {
          // Przebuduj tylko jeśli zmieniło się ID lub ilość (optymalizacja)
          if (previous is InventoryLoaded && current is InventoryLoaded) {
            return previous.box.id != current.box.id ||
                previous.box.quantity != current.box.quantity;
          }
          return true;
        },
        builder: (context, state) {
          // --- 1. STAN STARTOWY (PUSTY) ---
          if (state is InventoryInitial || state is InventoryListLoaded) {
            return _buildEmptyState(context);
          }

          // --- 2. ŁADOWANIE ---
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- 3. BŁĄD ---
          if (state is InventoryError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () {
                      context.read<InventoryBloc>().add(const ResetInventory());
                    },
                    child: const Text('Go back'),
                  )
                ],
              ),
            );
          }

          // --- 4. ZAŁADOWANO PRZEDMIOT (WYNIK SKANU) ---
          if (state is InventoryLoaded) {
            return _buildLoadedState(context, state.box);
          }

          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }

  // --- WIDOK: PUSTY EKRAN SKANERA ---
  Widget _buildEmptyState(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(
          title: Text('Scanner'),
          centerTitle: false,
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.nfc,
                    size: 80,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Ready to Scan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the button below to start',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDOK: PRZEDMIOT ZAŁADOWANY ---
  Widget _buildLoadedState(BuildContext context, StorageBox box) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: ListTile(
            title: Text(box.itemName),
            subtitle: Text(
              'Last updated: ${_formatDate(box.lastUsed)}',
            ),
            enabled: false,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              24, 24, 24, 100), // Padding na dole dla FAB
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 1. KARTA Z MODELEM 3D (Naprawiona)
              _buildImageCard(context, box),

              const SizedBox(height: 32),

              // 2. STEPPER ILOŚCI
              const Center(
                child: Text(
                  "Quantity in stock",
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),

              _buildQuantityStepper(context, box),

              const SizedBox(height: 40),

              const SizedBox(height: 40),

              // 4. PRZYCISKI AKCJI (Edit & Delete - Tekstowe na dole)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SetupTagScreen(boxToEdit: box),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text("Edit Details"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _confirmDelete(context, box),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red.withOpacity(0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }

  // --- WIDGETY POMOCNICZE ---

  Widget _buildImageCard(BuildContext context, StorageBox box) {
    Color cardColor =
        box.hexColor != null ? _hexToColor(box.hexColor!) : Colors.grey;

    return Container(
      height: 250, // Więcej miejsca dla modelu
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // ClipRRect jest potrzebny, żeby model nie wystawał poza zaokrąglenia
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Tło ozdobne
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.inventory_2,
                  size: 150, color: Colors.white.withOpacity(0.1)),
            ),

            // WŁAŚCIWY WIDGET 3D (Naprawiony)
            Box3DViewer(
              modelPath: box.modelPath,
              hexColor: box.hexColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityStepper(BuildContext context, StorageBox box) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            context,
            icon: Icons.remove,
            onTap: () {
              if (box.quantity > 0) {
                context.read<InventoryBloc>().add(UpdateQuantity(
                      boxId: box.id.toString(),
                      newQuantity: box.quantity - 1,
                    ));
              }
            },
          ),
          Text(
            '${box.quantity}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          _buildCircleButton(
            context,
            icon: Icons.add,
            isPrimary: true,
            onTap: () {
              context.read<InventoryBloc>().add(UpdateQuantity(
                    boxId: box.id.toString(),
                    newQuantity: box.quantity + 1,
                  ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(BuildContext context,
      {required IconData icon,
      required VoidCallback onTap,
      bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrimary
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.4),
                      blurRadius: 10)
                ]
              : [],
        ),
        child: Icon(icon,
            color:
                isPrimary ? Colors.white : Theme.of(context).iconTheme.color),
      ),
    );
  }

  void _confirmDelete(BuildContext context, StorageBox box) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${box.itemName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<InventoryBloc>()
                  .add(DeleteBoxRequested(boxId: box.id.toString()));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd • HH:mm').format(date);
  }
}
