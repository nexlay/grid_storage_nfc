import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/box_3d_viewer.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FAB (Floating Action Button) do skanowania
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<InventoryBloc>().add(const ScanTagRequested());
        },
        icon: const Icon(Icons.nfc),
        label: const Text('Scan Tag'),
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (previous, current) {
          if (previous is InventoryLoaded && current is InventoryLoaded) {
            return previous.box.id != current.box.id ||
                previous.box.quantity != current.box.quantity;
          }
          return true;
        },
        builder: (context, state) {
          // --- 1. Stan startowy lub powrót z listy (Pusty ekran "Ready to Scan") ---
          if (state is InventoryInitial || state is InventoryListLoaded) {
            return CustomScrollView(
              slivers: [
                const SliverAppBar.large(title: Text('Scanner')),
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nfc,
                            size: 100, color: Theme.of(context).disabledColor),
                        const SizedBox(height: 16),
                        const Text('Ready to Scan',
                            style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 8),
                        const Text('Tap the button below to start',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // --- 2. Ładowanie ---
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- 3. Błąd ---
          if (state is InventoryError) {
            return Center(child: Text(state.message));
          }

          // --- 4. Załadowano Przedmiot (Pełny Widok) ---
          if (state is InventoryLoaded) {
            final box = state.box;

            return CustomScrollView(
              slivers: [
                // Nagłówek
                SliverAppBar.large(
                  title: Text(box.itemName),
                  actions: [
                    // Przycisk Edycji
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SetupTagScreen(boxToEdit: box),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Lista elementów (Slivers)
                SliverList(
                  delegate: SliverChildListDelegate([
                    // --- Model 3D ---
                    Card(
                      margin: const EdgeInsets.all(16),
                      elevation: 4,
                      child: Box3DViewer(
                        modelPath: box.modelPath,
                        hexColor: box.hexColor,
                      ),
                    ),

                    // --- Sekcja Tytułu i Usuwania ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Quantity: ${box.quantity}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Confirm Deletion'),
                                  content: Text('Delete ${box.itemName}?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete')),
                                  ],
                                ),
                              );

                              if (confirmed == true && context.mounted) {
                                context.read<InventoryBloc>().add(
                                    DeleteBoxRequested(
                                        boxId: box.id.toString()));
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- Przyciski Kontroli Ilości (+ / -) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.tonal(
                          onPressed: () {
                            context.read<InventoryBloc>().add(UpdateQuantity(
                                  boxId: box.id.toString(),
                                  newQuantity: box.quantity - 1,
                                ));
                          },
                          child: const Icon(Icons.remove, size: 32),
                        ),
                        const SizedBox(width: 32),
                        FilledButton.tonal(
                          onPressed: () {
                            context.read<InventoryBloc>().add(UpdateQuantity(
                                  boxId: box.id.toString(),
                                  newQuantity: box.quantity + 1,
                                ));
                          },
                          child: const Icon(Icons.add, size: 32),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(),

                    // --- Metadane (Data i Kolor) ---
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Last Used'),
                      subtitle: Text(DateFormat('yyyy-MM-dd – HH:mm')
                          .format(box.lastUsed)),
                    ),

                    const SizedBox(height: 80),
                  ]),
                ),
              ],
            );
          }

          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }
}
