import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grid_storage_nfc/features/inventory/presentation/bloc/inventory_bloc.dart';

class SetupTagScreen extends StatefulWidget {
  const SetupTagScreen({Key? key}) : super(key: key);

  @override
  State<SetupTagScreen> createState() => _SetupTagScreenState();
}

class _SetupTagScreenState extends State<SetupTagScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  int _initialQuantity = 0;
  int _threshold = 0;
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
          title: const Text('Setup New Tag'),
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
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        onSaved: (value) => _name = value!,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(
                            labelText: 'Initial Quantity'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null ||
                              int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onSaved: (value) =>
                            _initialQuantity = int.parse(value!),
                      ),
                      TextFormField(
                        decoration:
                            const InputDecoration(labelText: 'Threshold'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null ||
                              int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                        onSaved: (value) => _threshold = int.parse(value!),
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
                                  color: Color(int.parse(
                                          color.substring(1, 7),
                                          radix: 16) +
                                      0xFF000000),
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
                                          name: _name,
                                          description:
                                              '', // No description field in form
                                          quantity: _initialQuantity,
                                          threshold: _threshold,
                                          color: _selectedColor,
                                        ),
                                      );
                                }
                              },
                        child: const Text('Write to Tag'),
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
