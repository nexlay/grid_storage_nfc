import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:hexcolor/hexcolor.dart';

// Importy do drukowania (pdf & printing)
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SetupTagScreen extends StatefulWidget {
  final StorageBox? boxToEdit;
  final bool isNfcMode;
  final String? scannedCode;

  const SetupTagScreen({
    super.key,
    this.boxToEdit,
    this.isNfcMode = true,
    this.scannedCode,
  });

  @override
  State<SetupTagScreen> createState() => _SetupTagScreenState();
}

class _SetupTagScreenState extends State<SetupTagScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _thresholdController;

  String _selectedColor = '#FFFFFF';
  String? _imagePath;
  bool _isLoading = false;

  final List<String> _colors = [
    '#FFFFFF',
    '#000000',
    '#9E9E9E',
    '#795548',
    '#FF0000',
    '#FF9800',
    '#FFEB3B',
    '#4CAF50',
    '#009688',
    '#2196F3',
    '#3F51B5',
    '#9C27B0',
    '#E91E63',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityController = TextEditingController();
    _thresholdController = TextEditingController();

    if (widget.boxToEdit != null) {
      _nameController.text = widget.boxToEdit!.itemName;
      _quantityController.text = widget.boxToEdit!.quantity.toString();
      _thresholdController.text = widget.boxToEdit!.threshold.toString();
      _selectedColor = widget.boxToEdit!.hexColor;
      _imagePath = widget.boxToEdit!.imagePath;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  // --- LOGIKA DRUKOWANIA ---
  Future<void> _printLabel() async {
    final barcodeData = widget.boxToEdit?.barcode ?? widget.scannedCode;
    final itemName =
        _nameController.text.isNotEmpty ? _nameController.text : "Item";

    if (barcodeData == null || barcodeData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No barcode to print.")),
      );
      return;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(itemName,
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: barcodeData,
                  width: 150,
                  height: 150,
                ),
                pw.SizedBox(height: 5),
                pw.Text(barcodeData, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Label_${itemName}_$barcodeData',
    );
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1024,
    );

    if (image == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(image.path);
    final savedImage = await File(image.path).copy('${appDir.path}/$fileName');

    setState(() {
      _imagePath = savedImage.path;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      int? idToSend;
      if (widget.boxToEdit != null) {
        idToSend = widget.boxToEdit!.id;
      }

      context.read<InventoryBloc>().add(
            WriteTagRequested(
              id: idToSend,
              name: _nameController.text,
              quantity: int.parse(_quantityController.text),
              threshold: int.parse(_thresholdController.text),
              color: _selectedColor,
              writeToNfc: widget.isNfcMode,
              barcode: widget.boxToEdit?.barcode ?? widget.scannedCode,
              imagePath: _imagePath,
            ),
          );
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text(
            'Are you sure you want to delete "${widget.boxToEdit?.itemName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InventoryBloc>().add(
                    DeleteBoxRequested(boxId: widget.boxToEdit!.id.toString()),
                  );
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getImageProvider() {
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      if (_imagePath!.startsWith('http')) {
        return NetworkImage(_imagePath!);
      } else if (File(_imagePath!).existsSync()) {
        return FileImage(File(_imagePath!));
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isEditing = widget.boxToEdit != null;
    final bool useNfc = widget.isNfcMode && !isEditing;

    String appBarTitle =
        isEditing ? 'Edit Item' : (useNfc ? 'Setup New Tag' : 'Setup New Item');
    String buttonText =
        isEditing ? 'Update Database' : (useNfc ? 'Write to Tag' : 'Save Item');
    IconData buttonIcon =
        isEditing ? Icons.save_as : (useNfc ? Icons.nfc : Icons.save);

    final bgImage = _getImageProvider();

    // Sprawdzamy, czy jest dostępny kod (z bazy lub ze skanera)
    final hasBarcode =
        widget.boxToEdit?.barcode != null || widget.scannedCode != null;

    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        setState(() {
          _isLoading = state is InventoryLoading;
        });

        if (state is InventoryLoaded && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message!), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.error),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          centerTitle: true,
          // USUNIĘTO actions z AppBar, aby ikona była tylko przy kodzie
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: AbsorbPointer(
                  absorbing: _isLoading,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- ZIELONY PASEK Z KODEM I IKONĄ DRUKOWANIA ---
                      if (hasBarcode)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.qr_code, color: Colors.green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Associated Code:',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.green)),
                                    Text(
                                        widget.boxToEdit?.barcode ??
                                            widget.scannedCode!,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ],
                                ),
                              ),
                              // TUTAJ JEST PRZYCISK DRUKOWANIA
                              IconButton(
                                icon: const Icon(Icons.print,
                                    color: Colors.green),
                                onPressed: _printLabel,
                                tooltip: 'Print Label',
                              ),
                            ],
                          ),
                        ),

                      Text("Item Details",
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Item Name',
                          prefixIcon: const Icon(Icons.label_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 20),
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
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true),
                            validator: (v) =>
                                v == null || int.tryParse(v) == null
                                    ? 'Invalid'
                                    : null,
                          )),
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
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true),
                            validator: (v) =>
                                v == null || int.tryParse(v) == null
                                    ? 'Invalid'
                                    : null,
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text("Item Photo",
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _takePicture,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade400),
                                image: bgImage != null
                                    ? DecorationImage(
                                        image: bgImage,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: bgImage == null
                                  ? const Icon(Icons.camera_alt,
                                      size: 40, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _takePicture,
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Take Photo'),
                                ),
                                if (_imagePath != null)
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _imagePath = null),
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    label: const Text('Remove Photo',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text("Appearance",
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 60,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _colors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final colorHex = _colors[index];
                            final isSelected = _selectedColor == colorHex;
                            final color = HexColor(colorHex);
                            final iconColor = color.computeLuminance() > 0.5
                                ? Colors.black54
                                : Colors.white;

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = colorHex),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isSelected
                                          ? (color.computeLuminance() > 0.5
                                              ? Colors.black
                                              : Colors.white)
                                          : Colors.grey.shade300,
                                      width: isSelected ? 3 : 1),
                                ),
                                child: isSelected
                                    ? Icon(Icons.check, color: iconColor)
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
                          icon: Icon(buttonIcon),
                          label: Text(buttonText),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: TextButton.icon(
                            onPressed: _isLoading ? null : _confirmDelete,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            label: const Text(
                              "Delete Item",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading) _buildLoadingOverlay(context, useNfc),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context, bool isNfcWrite) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isNfcWrite) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nfc,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hold phone near NFC tag...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Writing data...',
                style: TextStyle(color: Colors.white70),
              ),
            ] else ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Saving...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 40),
            if (isNfcWrite)
              const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
