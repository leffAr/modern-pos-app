import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  final _manualInputController = TextEditingController();
  bool _hasPopped = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode / SKU'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: _cameraController.torchState,
              builder: (context, state, child) {
                switch (state as TorchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
            iconSize: 32.0,
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: _cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state as CameraFacing) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            iconSize: 32.0,
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: (capture) {
                    if (_hasPopped) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String code = barcodes.first.rawValue ?? '';
                      if (code.isNotEmpty) {
                        _hasPopped = true;
                        Navigator.pop(context, code);
                      }
                    }
                  },
                ),
                // Scanner Overlay Box
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Arahkan kamera ke barcode produk, atau ketik manual jika menggunakan Emulator / Browser:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualInputController,
                    decoration: InputDecoration(
                      labelText: 'Masukkan Barcode / SKU',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () {
                          if (_hasPopped) return;
                          if (_manualInputController.text.isNotEmpty) {
                            _hasPopped = true;
                            Navigator.pop(context, _manualInputController.text);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      if (_hasPopped) return;
                      if (val.isNotEmpty) {
                        _hasPopped = true;
                        Navigator.pop(context, val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
