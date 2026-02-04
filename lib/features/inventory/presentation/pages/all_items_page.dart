import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';

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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  // --- HELPER DLA OBRAZKA W AVATARZE ---
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
                                  // --- ULEPSZONY AVATAR Z OBRAZKIEM ---
                                  CircleAvatar(
                                    backgroundColor: _hexToColor(box.hexColor),
                                    backgroundImage:
                                        _getImageProvider(box.imagePath),
                                    child: _getImageProvider(box.imagePath) ==
                                            null
                                        ? Text(
                                            box.itemName.isNotEmpty
                                                ? box.itemName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final inventoryBloc = context.read<InventoryBloc>();

          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SetupTagScreen()),
          );

          inventoryBloc.add(const LoadAllItems());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
