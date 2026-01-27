import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart'; // Import SetupTagScreen

class AllItemsPage extends StatefulWidget {
  const AllItemsPage({Key? key}) : super(key: key);

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> {
  @override
  void initState() {
    super.initState();
    // Dispatch LoadAllItems event when the page initializes
    context.read<InventoryBloc>().add(const LoadAllItems());
  }

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
          TextButton(
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
      appBar: AppBar(
        title: const Text('All Items'),
      ),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state is InventoryError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is InventoryInitial) {
            // After successful deletion, reload the list
            context.read<InventoryBloc>().add(const LoadAllItems());
          }
        },
        builder: (context, state) {
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InventoryListLoaded) {
            if (state.boxes.isEmpty) {
              return const Center(child: Text('No items in inventory.'));
            }
            return ListView.builder(
              itemCount: state.boxes.length,
              itemBuilder: (context, index) {
                final box = state.boxes[index];
                return Dismissible(
                  key: ValueKey(box.id), // Unique key for Dismissible
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    return await _showDeleteConfirmationDialog(
                        context, box.itemName);
                  },
                  onDismissed: (direction) {
                    if (direction == DismissDirection.endToStart) {
                      context
                          .read<InventoryBloc>()
                          .add(DeleteBoxRequested(boxId: box.id.toString()));
                    }
                  },
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: HexColor(box.hexColor),
                        child: Text(box.itemName[0]),
                      ),
                      title: Text(box.itemName),
                      subtitle: Text('Quantity: ${box.quantity}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SetupTagScreen(boxToEdit: box),
                            ),
                          );
                          // After returning from edit screen, refresh the list
                          context
                              .read<InventoryBloc>()
                              .add(const LoadAllItems());
                        },
                      ),
                      onTap: () {
                        // Optionally load individual box details on tap
                        // If we want to show details, we might dispatch a LoadBoxDetails event
                        // For now, doing nothing or reusing ScanTag for demo purposes if it leads to detail view
                      },
                    ),
                  ),
                );
              },
            );
          }
          return const Center(
              child: Text('Please load items or an error occurred.'));
        },
      ),
    );
  }
}
