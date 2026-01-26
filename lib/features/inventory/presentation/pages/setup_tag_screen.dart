import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart'; // Import StorageBox
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:hexcolor/hexcolor.dart';

class SetupTagScreen extends StatefulWidget {
  final StorageBox? boxToEdit; // New optional parameter

  const SetupTagScreen({Key? key, this.boxToEdit}) : super(key: key);

  @override
  State<SetupTagScreen> createState() => _SetupTagScreenState();
}

class _SetupTagScreenState extends State<SetupTagScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _thresholdController;
  String _selectedColor = '#FFFFFF';
  bool _isLoading = false;

  final List<String> _colors = [
    '#FFFFFF',
    '#FF0000',
    '#00FF00',
    '#0000FF',
    '#FFFF00',
    '#FF00FF',
    '#00FFFF',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _quantityController = TextEditingController();
    _thresholdController = TextEditingController();

    if (widget.boxToEdit != null) {
      // Pre-fill form fields if in edit mode
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listener: (context, state) {
        setState(() {
          _isLoading = state is InventoryLoading;
        });
        if (state is InventoryLoaded && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
          Navigator.of(context).pop();
        } else if (state is InventoryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.boxToEdit == null ? 'Setup New Tag' : 'Edit Item'),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: AbsorbPointer(
                  absorbing: _isLoading,
                  child: ListView(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        onSaved: (value) => _nameController.text = value!,
                      ),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                            labelText: 'Initial Quantity'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onSaved: (value) => _quantityController.text = value!,
                      ),
                      TextFormField(
                        controller: _thresholdController,
                        decoration:
                            const InputDecoration(labelText: 'Threshold'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onSaved: (value) => _thresholdController.text = value!,
                      ),
                      const SizedBox(height: 20),
                      const Text('Color', style: TextStyle(fontSize: 16)),
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _colors.length,
                          itemBuilder: (context, index) {
                            final color = _colors[index];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = color;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: HexColor(color),
                                  shape: BoxShape.circle,
                                  border: _selectedColor == color
                                      ? Border.all(
                                          color: Colors.black, width: 2)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  _formKey.currentState!.save();
                                  context.read<InventoryBloc>().add(
                                        WriteTagRequested(
                                          id: widget.boxToEdit?.id.toString(), // Pass ID if editing
                                          name: _nameController.text,
                                          description: '',
                                          quantity:
                                              int.parse(_quantityController.text),
                                          threshold:
                                              int.parse(_thresholdController.text),
                                          color: _selectedColor,
                                        ),
                                      );
                                }
                              },
                        child: Text(widget.boxToEdit == null
                            ? 'Write to Tag'
                            : 'Update Database'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}