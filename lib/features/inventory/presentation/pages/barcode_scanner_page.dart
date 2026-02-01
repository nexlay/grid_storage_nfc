import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  // Kontroler skanera
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode / QR'),
        actions: [
          // POPRAWIONY PRZEŁĄCZNIK LATARKI
          ValueListenableBuilder(
            valueListenable: controller, // <--- ZMIANA: Nasłuchujemy kontrolera
            builder: (context, state, child) {
              // Sprawdzamy stan latarki wewnątrz obiektu state
              switch (state.torchState) {
                case TorchState.off:
                  return IconButton(
                    icon: const Icon(Icons.flash_off, color: Colors.grey),
                    onPressed: () => controller.toggleTorch(),
                  );
                case TorchState.on:
                  return IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.yellow),
                    onPressed: () => controller.toggleTorch(),
                  );
                case TorchState.unavailable:
                  return const SizedBox.shrink(); // Brak latarki w urządzeniu
                case TorchState.auto: // Obsługa nowego stanu auto (opcjonalnie)
                  return IconButton(
                    icon: const Icon(Icons.flash_auto, color: Colors.white),
                    onPressed: () => controller.toggleTorch(),
                  );
              }
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (_isScanned) return;

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? code = barcodes.first.rawValue;
            if (code != null) {
              setState(() {
                _isScanned = true;
              });

              Navigator.pop(context, code);
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
