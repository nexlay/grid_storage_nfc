import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/widgets/box_3d_viewer.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SetupTagScreen()),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        builder: (context, state) {
          if (state is InventoryInitial) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.nfc, size: 100, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Ready to Scan', style: TextStyle(fontSize: 24)),
                ],
              ),
            );
          }
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is InventoryError) {
            return Center(child: Text(state.message));
          }
          if (state is InventoryLoaded) {
            final box = state.box;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Box3DViewer(
                      modelPath: box.modelPath,
                      hexColor: box.hexColor,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          box.itemName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          'Quantity: ${box.quantity}',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            context.read<InventoryBloc>().add(UpdateQuantity(
                                  boxId: box.id.toString(),
                                  newQuantity: box.quantity - 1,
                                ));
                          },
                          child: const Icon(Icons.remove, size: 32),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
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
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Last Used: ${DateFormat('yyyy-MM-dd – HH:mm').format(box.lastUsed)}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Text('Color Indicator: '),
                        CircleAvatar(
                          backgroundColor: HexColor(box.hexColor),
                          radius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.read<InventoryBloc>().add(const ScanTagRequested());
        },
        child: const Icon(Icons.nfc),
      ),
    );
  }
}
