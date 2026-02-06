import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/barcode_scanner_page.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';
import 'package:intl/intl.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  // --- GENERATOR ID (Wirtualny kod) ---
  String _generateLocalId() {
    return 'LOC-${DateTime.now().millisecondsSinceEpoch}';
  }

  // --- DIALOG DODAWANIA RĘCZNEGO ---
  void _showManualAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final thresholdController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Item Manually'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No NFC tag? A virtual ID will be generated for future printing.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
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
                  const SizedBox(width: 12),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isEmpty) return;

              final generatedId = _generateLocalId();

              // Wysyłamy zdarzenie zapisu do Bloca
              context.read<InventoryBloc>().add(WriteTagRequested(
                    name: nameController.text,
                    quantity: int.tryParse(qtyController.text) ?? 1,
                    threshold: int.tryParse(thresholdController.text) ?? 0,
                    color: '#2196F3', // Domyślny niebieski
                    writeToNfc: false, // WAŻNE: Nie próbuj pisać na NFC
                    barcode: generatedId, // Zapisz nasz wirtualny kod
                  ));

              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Added "${nameController.text}" (ID: $generatedId)')),
              );
            },
            child: const Text('Save Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- DOLNY PASEK PRZYCISKÓW ---
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. SKANER QR
          FloatingActionButton(
            heroTag: 'qr_scan',
            onPressed: () async {
              final String? code = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
              );

              if (code != null && context.mounted) {
                context.read<InventoryBloc>().add(ProcessScannedCode(code));
              }
            },
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(width: 16),

          // 2. NOWOŚĆ: DODAJ RĘCZNIE
          FloatingActionButton(
            heroTag: 'manual_add',
            onPressed: () => _showManualAddDialog(context),
            backgroundColor: Colors.orange.shade100,
            foregroundColor: Colors.orange.shade900,
            child: const Icon(Icons.edit_note),
          ),
          const SizedBox(width: 16),

          // 3. SKANER NFC
          FloatingActionButton.extended(
            heroTag: 'nfc_scan',
            onPressed: () {
              context.read<InventoryBloc>().add(const ScanTagRequested());
            },
            icon: const Icon(Icons.nfc),
            label: const Text('Scan Tag'),
            elevation: 4,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ],
      ),
      body: BlocBuilder<InventoryBloc, InventoryState>(
        buildWhen: (previous, current) {
          if (previous is InventoryLoaded && current is InventoryLoaded) {
            return previous.box.id != current.box.id ||
                previous.box.quantity != current.box.quantity ||
                previous.box.imagePath != current.box.imagePath;
          }
          return true;
        },
        builder: (context, state) {
          if (state is InventoryInitial || state is InventoryListLoaded) {
            return _buildEmptyState(context);
          }
          if (state is InventoryLoading) {
            return const Center(child: CircularProgressIndicator());
          }
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
                  ),
                  // Jeśli nie znaleziono przedmiotu po skanie, proponujemy utworzenie
                  if (state.message.contains('not found')) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SetupTagScreen(
                              isNfcMode: false,
                              scannedCode: state.scannedCode,
                            ),
                          ),
                        );
                        context
                            .read<InventoryBloc>()
                            .add(const ResetInventory());
                      },
                      child: const Text('Create New Item'),
                    ),
                  ]
                ],
              ),
            );
          }
          if (state is InventoryLoaded) {
            return _buildLoadedState(context, state.box);
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
    );
  }

  // --- UI POMOCNICZE (Zachowane z Twojego kodu) ---

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
                    Icons.qr_code_scanner,
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
                  'Scan NFC tag or Barcode/QR',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadedState(BuildContext context, StorageBox box) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: ListTile(
            title: Text(box.itemName),
            subtitle: Text(
              'Last updated: ${_formatDate(box.lastUsed)}',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildImageCard(context, box),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  "Quantity in stock",
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500),
                ),
              ),
              _buildQuantityStepper(context, box),
              const SizedBox(height: 80),
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

  Widget _buildImageCard(BuildContext context, StorageBox box) {
    Color cardColor = _hexToColor(box.hexColor);
    final imagePath = box.imagePath;
    final bool hasPath = imagePath != null && imagePath.isNotEmpty;
    final bool isNetwork = hasPath && imagePath.startsWith('http');
    final bool isLocal = hasPath && !isNetwork && File(imagePath).existsSync();
    final bool showImage = isNetwork || isLocal;

    return Container(
      height: 300,
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: showImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  if (isNetwork)
                    Image.network(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildNoPhotoPlaceholder(isError: true),
                    )
                  else
                    Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, _, __) =>
                          _buildNoPhotoPlaceholder(isError: true),
                    ),
                ],
              )
            : _buildNoPhotoPlaceholder(),
      ),
    );
  }

  Widget _buildNoPhotoPlaceholder({bool isError = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: -20,
          top: -20,
          child: Icon(Icons.image_not_supported_outlined,
              size: 150, color: Colors.black.withOpacity(0.05)),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.broken_image_outlined : Icons.camera_alt_outlined,
              size: 64,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              isError ? "Error loading photo" : "No photo added",
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityStepper(BuildContext context, StorageBox box) {
    final bool isLowStock = box.quantity <= box.threshold;
    final Color quantityColor = isLowStock
        ? Colors.red
        : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final Color containerColor = isLowStock
        ? Colors.red.withOpacity(0.1)
        : Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(50),
        border:
            isLowStock ? Border.all(color: Colors.red.withOpacity(0.5)) : null,
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
          Row(
            children: [
              if (isLowStock)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 28),
                ),
              Text(
                '${box.quantity}',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: quantityColor),
              ),
            ],
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
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd • HH:mm').format(date);
  }
}
