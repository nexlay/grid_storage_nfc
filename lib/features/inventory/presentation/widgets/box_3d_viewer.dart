import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class Box3DViewer extends StatelessWidget {
  final String modelPath;
  final String hexColor;

  const Box3DViewer({
    Key? key,
    required this.modelPath,
    required this.hexColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Prosty kontroler bez zbędnych parametrów
    final Flutter3DController controller = Flutter3DController();

    return SizedBox(
      height: 300,
      child: Flutter3DViewer(
        controller: controller,
        src: modelPath,
      ),
    );
  }
}
