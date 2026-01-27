import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';
import 'package:hexcolor/hexcolor.dart';

class AllItemsPage extends StatefulWidget {
  const AllItemsPage({super.key});

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is InventoryInitial) {
            // Po usunięciu odświeżamy listę
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
                padding: const EdgeInsets.only(bottom: 80), // Miejsce na FAB
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final box = state.boxes[index];
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
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          elevation: 0, // Styl "flat" jak w nowoczesnych UI
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: HexColor(box.hexColor),
                              child: Text(
                                box.itemName.isNotEmpty
                                    ? box.itemName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              box.itemName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('Quantity: ${box.quantity}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SetupTagScreen(boxToEdit: box),
                                  ),
                                );
                                // Po powrocie odświeżamy listę
                                if (mounted) {
                                  context
                                      .read<InventoryBloc>()
                                      .add(const LoadAllItems());
                                }
                              },
                            ),
                            onTap: () {
                              // Tu w przyszłości można dodać nawigację do szczegółów
                            },
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
            // W razie błędu pokaż komunikat, ale nie blokuj całego UI
            content = SliverFillRemaining(
                child: Center(
                    child: Text('Error loading data: ${state.message}')));
          } else {
            // Fallback dla innych stanów (np. InventoryInitial zanim załaduje)
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SetupTagScreen()),
          );
          if (mounted) {
            context.read<InventoryBloc>().add(const LoadAllItems());
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
