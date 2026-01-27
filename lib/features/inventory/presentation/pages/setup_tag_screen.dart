import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:hexcolor/hexcolor.dart';

class SetupTagScreen extends StatefulWidget {
  final StorageBox? boxToEdit;

  const SetupTagScreen({Key? key, this.boxToEdit}) : super(key: key);

  @override
  State<SetupTagScreen> createState() => _SetupTagScreenState();
}

class _SetupTagScreenState extends State<SetupTagScreen> {
  final _formKey = GlobalKey<FormState>();

  // Kontrolery
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _thresholdController;

  String _selectedColor = '#FFFFFF';
  bool _isLoading = false;

  final List<String> _colors = [
    '#FFFFFF', // Biały
    '#FF0000', // Czerwony
    '#00FF00', // Zielony
    '#0000FF', // Niebieski
    '#FFFF00', // Żółty
    '#FF00FF', // Magenta
    '#00FFFF', // Cyan
  ];

  @override
  void initState() {
    super.initState();
    // Inicjalizacja kontrolerów
    _nameController = TextEditingController();
    _quantityController = TextEditingController();
    _thresholdController = TextEditingController();

    // Wypełnienie danymi, jeśli edytujemy istniejący przedmiot
    if (widget.boxToEdit != null) {
      _nameController.text = widget.boxToEdit!.itemName;
      _quantityController.text = widget.boxToEdit!.quantity.toString();
      _thresholdController.text = widget.boxToEdit!.threshold.toString();
      _selectedColor = widget.boxToEdit!.hexColor;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  // Funkcja obsługująca zatwierdzenie formularza
  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Ukryj klawiaturę
      FocusScope.of(context).unfocus();

      context.read<InventoryBloc>().add(
            WriteTagRequested(
              id: widget.boxToEdit?.id
                  .toString(), // Przekaż ID tylko przy edycji
              name: _nameController.text,
              description: '', // Puste, zgodnie z Twoją logiką
              quantity: int.parse(_quantityController.text),
              threshold: int.parse(_thresholdController.text),
              color: _selectedColor,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Używamy Theme, aby kolory pasowały do trybu ciemnego/jasnego
    final theme = Theme.of(context);

    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        setState(() {
          _isLoading = state is InventoryLoading;
        });

        if (state is InventoryLoaded && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context)
              .pop(); // Wróć do poprzedniego ekranu po sukcesie
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.boxToEdit == null ? 'Setup New Tag' : 'Edit Item'),
          centerTitle: true,
          elevation: 0,
        ),
        body: Stack(
          children: [
            // Główna zawartość formularza
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: AbsorbPointer(
                  absorbing: _isLoading, // Blokuj interakcję podczas ładowania
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Sekcja 1: Informacje Podstawowe ---
                      Text(
                        "Item Details",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pole Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          hintText: 'e.g. Screws M4',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter a name'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Wiersz z Ilością i Progiem
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                prefixIcon: const Icon(Icons.numbers),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme
                                    .colorScheme.surfaceContainerHighest
                                    .withOpacity(0.3),
                              ),
                              validator: (value) =>
                                  value == null || int.tryParse(value) == null
                                      ? 'Invalid number'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _thresholdController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Min. Alert',
                                prefixIcon:
                                    const Icon(Icons.warning_amber_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme
                                    .colorScheme.surfaceContainerHighest
                                    .withOpacity(0.3),
                              ),
                              validator: (value) =>
                                  value == null || int.tryParse(value) == null
                                      ? 'Invalid number'
                                      : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // --- Sekcja 2: Wybór Koloru ---
                      Text(
                        "Tag Appearance",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: 80,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _colors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final colorHex = _colors[index];
                            final isSelected = _selectedColor == colorHex;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = colorHex;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isSelected ? 56 : 48,
                                height: isSelected ? 56 : 48,
                                decoration: BoxDecoration(
                                  color: HexColor(colorHex),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade800,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color:
                                            HexColor(colorHex).withOpacity(0.6),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      )
                                  ],
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.black54, size: 30)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                              widget.boxToEdit == null ? Icons.nfc : Icons.save,
                              size: 28),
                          label: Text(
                            widget.boxToEdit == null
                                ? "Write to Tag"
                                : "Update Database",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Loader overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
