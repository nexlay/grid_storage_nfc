import 'dart:io'; // --- 1. Dodano import do obsługi plików
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/barcode_scanner_page.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/pages/setup_tag_screen.dart';
// Box3DViewer nie jest już konieczny w głównej karcie, ale zostawiam import, gdybyś chciał go użyć gdzieś indziej
import 'package:intl/intl.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // PRZYCISKI SKANOWANIA (QR + NFC)
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Przycisk QR / Barcode
          FloatingActionButton(
            heroTag: 'qr_scan', // Unikalny tag dla animacji
            onPressed: () async {
              // Otwieramy skaner i czekamy na wynik
              final String? code = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
              );

              // Jeśli coś zeskanowano, wysyłamy do Bloca
              if (code != null && context.mounted) {
                context.read<InventoryBloc>().add(ProcessScannedCode(code));
              }
            },
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: const Icon(Icons.qr_code_scanner),
          ),

          const SizedBox(width: 16), // Odstęp

          // 2. Główny przycisk NFC
          FloatingActionButton.extended(
            heroTag: 'nfc_scan', // Unikalny tag
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
          // Przebuduj tylko jeśli zmieniło się ID, ilość lub zdjęcie (optymalizacja)
          if (previous is InventoryLoaded && current is InventoryLoaded) {
            return previous.box.id != current.box.id ||
                previous.box.quantity != current.box.quantity ||
                previous.box.imagePath != current.box.imagePath;
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

                  // Przycisk powrotu
                  FilledButton.tonal(
                    onPressed: () {
                      context.read<InventoryBloc>().add(const ResetInventory());
                    },
                    child: const Text('Go back'),
                  ),

                  // BONUS: Jeśli przedmiot nie istnieje, pozwól go dodać!
                  if (state.message.contains('not found')) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        // Otwórz formularz dodawania
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SetupTagScreen(
                              isNfcMode: false, // Wyłączamy NFC
                              // Przekazujemy zeskanowany kod z błędu do formularza
                              scannedCode: state.scannedCode,
                            ),
                          ),
                        );
                        // Reset stanu po wyjściu z formularza
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
                    Icons.qr_code_scanner, // Zmiana ikony na bardziej ogólną
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
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              24, 24, 24, 100), // Padding na dole dla FAB
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 1. KARTA ZE ZDJĘCIEM (LUB PLACEHOLDEREM)
              _buildImageCard(context, box),

              const SizedBox(height: 40),

              // 2. STEPPER ILOŚCI (Zaktualizowany o logikę Low Stock)
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

              // 3. PRZYCISKI AKCJI (Edit & Delete - Tekstowe na dole)
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
    Color cardColor = _hexToColor(box.hexColor);

    // --- 2. LOGIKA SPRAWDZANIA ZDJĘCIA ---
    // Sprawdzamy czy ścieżka istnieje i czy plik fizycznie jest na dysku
    bool hasImage = box.imagePath != null &&
        box.imagePath!.isNotEmpty &&
        File(box.imagePath!).existsSync();

    return Container(
      height: 300, // Zwiększyłem nieco wysokość dla lepszego podglądu zdjęcia
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
      // ClipRRect przycina zdjęcie do zaokrągleń kontenera
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(box.imagePath!),
                    fit: BoxFit.cover, // Wypełnia cały obszar
                    errorBuilder: (ctx, _, __) =>
                        _buildNoPhotoPlaceholder(isError: true),
                  ),
                  // Opcjonalnie: Gradient na dole, żeby tekst był czytelniejszy (jeśli dodasz tekst na zdjęciu)
                ],
              )
            : _buildNoPhotoPlaceholder(), // Jeśli brak zdjęcia -> Placeholder
      ),
    );
  }

  // --- 3. WIDOK BRAKU ZDJĘCIA (ZAMIAST 3D BOX) ---
  Widget _buildNoPhotoPlaceholder({bool isError = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Tło ozdobne (ikona w tle)
        Positioned(
          right: -20,
          top: -20,
          child: Icon(Icons.image_not_supported_outlined,
              size: 150, color: Colors.black.withOpacity(0.05)),
        ),
        // Treść główna
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

  // --- ZMODYFIKOWANY STEPPER (OSTRZEŻENIA) ---
  Widget _buildQuantityStepper(BuildContext context, StorageBox box) {
    // 1. Sprawdzenie czy stan jest niski
    final bool isLowStock = box.quantity <= box.threshold;

    // 2. Ustalenie kolorów na podstawie stanu
    final Color quantityColor = isLowStock
        ? Colors.red
        : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    final Color containerColor = isLowStock
        ? Colors.red.withOpacity(0.1) // Czerwone tło ostrzegawcze
        : Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(50),
        // Opcjonalnie: Czerwona ramka
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

          // Środek: Ilość + ewentualna ikona ostrzegawcza
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
                    color: quantityColor // Dynamiczny kolor tekstu
                    ),
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
    return Color(int.parse(hex, radix: 16));
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd • HH:mm').format(date);
  }
}
