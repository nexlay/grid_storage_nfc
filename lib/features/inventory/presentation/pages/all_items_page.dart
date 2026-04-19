import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // NOWOŚĆ: Wymagane dla flagi kIsWeb
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/auth/auth_bloc.dart';

class AllItemsPage extends StatefulWidget {
  const AllItemsPage({super.key});

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    context.read<InventoryBloc>().add(const LoadAllItems());
  }

  void _onSearchChanged(String query) {
    context.read<InventoryBloc>().add(SearchItems(query));
  }

  String _generateLocalId() {
    return 'LOC-${DateTime.now().millisecondsSinceEpoch}';
  }

  Widget _buildOverviewCard(int itemsCount, int totalQuantity) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.analytics_outlined,
                color: Theme.of(context).colorScheme.primary, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Overview',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total items: $itemsCount',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Total quantity: $totalQuantity units',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                    color: '#9E9E9E',
                    writeToNfc: false,
                    barcode: generatedId,
                  ));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added "${nameController.text}"')),
              );
              if (_isSearching) {
                _stopSearch();
              } else {
                context.read<InventoryBloc>().add(const LoadAllItems());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    // --- BEZPIECZEŃSTWO WEB ---
    if (kIsWeb) {
      // Na Webie NFC nie działa, więc całkowicie pomijamy menu wyboru
      // i od razu pokazujemy dialog do wpisywania ręcznego.
      _showManualAddDialog(context);
      return;
    }

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
      } else if (!kIsWeb) {
        // --- BEZPIECZEŃSTWO WEB ---
        // Używamy klasy File tylko na platformach mobilnych/desktopowych
        if (File(path).existsSync()) {
          return FileImage(File(path));
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.role == 'admin';

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
          List<Widget> slivers = [];

          // 1. AppBar
          slivers.add(
            SliverAppBar.large(
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search items...',
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    )
                  : const Text('All Items'),
              centerTitle: false,
              actions: [
                if (_isSearching)
                  IconButton(
                      icon: const Icon(Icons.close), onPressed: _stopSearch)
                else
                  IconButton(
                      icon: const Icon(Icons.search), onPressed: _startSearch),
              ],
            ),
          );

          if (state is InventoryLoading) {
            slivers.add(const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ));
          } else if (state is InventoryListLoaded) {
            // Calculate Stats
            final int itemsCount = state.boxes.length;
            final int totalQty =
                state.boxes.fold(0, (sum, item) => sum + item.quantity);

            // 2. Overview Card (ONLY IF NOT EMPTY)
            if (state.boxes.isNotEmpty && !_isSearching) {
              slivers.add(_buildOverviewCard(itemsCount, totalQty));
            }

            // 3. Content
            if (state.boxes.isEmpty) {
              slivers.add(SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSearching ? Icons.search_off : Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSearching
                            ? 'No items found matching "${_searchController.text}"'
                            : 'No items in inventory.',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ));
            } else {
              slivers.add(
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final box = state.boxes[index];
                        final bool isLowStock = box.quantity <= box.threshold;
                        final bool isManual =
                            box.barcode?.startsWith('LOC-') ?? false;

                        return Dismissible(
                          key: ValueKey(box.id),
                          direction: isAdmin
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
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
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SetupTagScreen(boxToEdit: box),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isManual
                                          ? Colors.orange.shade100
                                          : _hexToColor(box.hexColor),
                                      backgroundImage:
                                          _getImageProvider(box.imagePath),
                                      child: _getImageProvider(box.imagePath) ==
                                              null
                                          ? Icon(
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
                                    if (isAdmin)
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => SetupTagScreen(
                                                  boxToEdit: box),
                                            ),
                                          );
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
                ),
              );
            }
          } else {
            slivers.add(const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ));
          }

          return CustomScrollView(slivers: slivers);
        },
      ),
      floatingActionButton: (!_isSearching && isAdmin)
          ? FloatingActionButton(
              onPressed: () => _showAddOptions(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
