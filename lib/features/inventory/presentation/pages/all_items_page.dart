import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';

class AllItemsPage extends StatefulWidget {
  const AllItemsPage({super.key});

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> {
  // --- NOWOŚĆ: Generator ID ---
  String _generateLocalId() {
    return 'LOC-${DateTime.now().millisecondsSinceEpoch}';
  }

  // --- NOWOŚĆ: Dialog Manualny ---
  void _showManualAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final thresholdController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Item Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A virtual ID will be generated for future printing.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Min Limit',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;

              final generatedId = _generateLocalId();

              context.read<InventoryBloc>().add(WriteTagRequested(
                    name: nameController.text,
                    quantity: int.tryParse(qtyController.text) ?? 1,
                    threshold: int.tryParse(thresholdController.text) ?? 0,
                    color: '#9E9E9E', // Szary dla manualnych
                    writeToNfc: false, // Brak zapisu NFC
                    barcode: generatedId, // Kod wirtualny
                  ));

              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added "${nameController.text}"')),
              );

              // Odświeżamy listę, żeby od razu zobaczyć nowy element
              context.read<InventoryBloc>().add(const LoadAllItems());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- NOWOŚĆ: Menu wyboru (NFC vs Manual) ---
  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.nfc, color: Colors.blue),
              title: const Text('Write to NFC Tag'),
              subtitle: const Text('Scan a tag to create a new item'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SetupTagScreen()),
                ).then((_) {
                  if (context.mounted) {
                    context.read<InventoryBloc>().add(const LoadAllItems());
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.orange),
              title: const Text('Add Manually (No Tag)'),
              subtitle: const Text('Generate a virtual ID for printing later'),
              onTap: () {
                Navigator.pop(ctx);
                _showManualAddDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- STARE METODY POMOCNICZE (Bez zmian) ---
  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, String itemName) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  ImageProvider? _getImageProvider(String? path) {
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return NetworkImage(path);
      } else if (File(path).existsSync()) {
        return FileImage(File(path));
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Items'),
        actions: [
          // Zmodyfikowany przycisk w nagłówku
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddOptions(context),
          ),
        ],
      ),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is InventoryInitial) {
            context.read<InventoryBloc>().add(const LoadAllItems());
          }
        },
        builder: (context, state) {
          Widget content;

          if (state is InventoryLoading) {
            content = const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (state is InventoryListLoaded) {
            if (state.boxes.isEmpty) {
              content = const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No items in inventory.',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            } else {
              content = SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final box = state.boxes[index];
                      final bool isLowStock = box.quantity <= box.threshold;

                      // Sprawdzamy czy to item wirtualny (po prefiksie LOC-)
                      final bool isManual =
                          box.barcode?.startsWith('LOC-') ?? false;

                      return Dismissible(
                        key: ValueKey(box.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await _showDeleteConfirmationDialog(
                              context, box.itemName);
                        },
                        onDismissed: (direction) {
                          context.read<InventoryBloc>().add(
                              DeleteBoxRequested(boxId: box.id.toString()));
                        },
                        background: Container(
                          color: Colors.red.shade100,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(Icons.delete_outline,
                              color: Colors.red.shade900),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isLowStock
                                ? BorderSide(
                                    color: Colors.red.withOpacity(0.6),
                                    width: 1.5)
                                : BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final inventoryBloc =
                                  context.read<InventoryBloc>();

                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SetupTagScreen(boxToEdit: box),
                                ),
                              );

                              inventoryBloc.add(const LoadAllItems());
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // --- AVATAR ROZRÓŻNIAJĄCY NFC I MANUAL ---
                                  CircleAvatar(
                                    backgroundColor: isManual
                                        ? Colors.orange
                                            .shade100 // Kolor dla ręcznych
                                        : _hexToColor(
                                            box.hexColor), // Kolor dla NFC
                                    backgroundImage:
                                        _getImageProvider(box.imagePath),
                                    child:
                                        _getImageProvider(box.imagePath) == null
                                            ? Icon(
                                                // Ikona ołówka dla ręcznych, NFC dla tagów
                                                isManual
                                                    ? Icons.edit_note
                                                    : Icons.nfc,
                                                color: isManual
                                                    ? Colors.orange.shade900
                                                    : Colors.white,
                                              )
                                            : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          box.itemName,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              'Quantity: ${box.quantity}',
                                              style: TextStyle(
                                                color: isLowStock
                                                    ? Colors.red
                                                    : Colors.grey[600],
                                                fontWeight: isLowStock
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            if (isLowStock) ...[
                                              const SizedBox(width: 8),
                                              const Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Colors.red,
                                                  size: 18),
                                            ]
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      final inventoryBloc =
                                          context.read<InventoryBloc>();

                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SetupTagScreen(boxToEdit: box),
                                        ),
                                      );

                                      inventoryBloc.add(const LoadAllItems());
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: state.boxes.length,
                  ),
                ),
              );
            }
          } else if (state is InventoryError) {
            content = SliverFillRemaining(
                child: Center(
                    child: Text('Error loading data: ${state.message}')));
          } else {
            content = const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()));
          }

          return CustomScrollView(
            slivers: [
              const SliverAppBar.large(
                title: Text('All Items'),
                centerTitle: false,
              ),
              content,
            ],
          );
        },
      ),
      // --- FAB DLA LISTY WSZYSTKICH PRZEDMIOTÓW ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
