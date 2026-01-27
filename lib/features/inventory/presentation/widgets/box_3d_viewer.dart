import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:hexcolor/hexcolor.dart';

class Box3DViewer extends StatefulWidget {
  final String modelPath;
  final String hexColor;

  const Box3DViewer({
    Key? key,
    required this.modelPath,
    required this.hexColor,
  }) : super(key: key);

  @override
  State<Box3DViewer> createState() => _Box3DViewerState();
}

class _Box3DViewerState extends State<Box3DViewer> {
  late Flutter3DController controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    controller = Flutter3DController();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: 200,
      decoration: BoxDecoration(
        color: HexColor(widget.hexColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _isReady
          ? Flutter3DViewer(
              controller: controller,
              src: widget.modelPath,
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
