import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/services/sound_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  final _manualInputController = TextEditingController();
  bool _hasPopped = false;
  bool _isScanned = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _handleManualSubmit(String val) async {
    if (_hasPopped) return;
    final code = val.trim();
    if (code.isNotEmpty) {
      _hasPopped = true;
      await SoundService.playBeep();
      if (mounted) {
        Navigator.pop(context, code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode / SKU'),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder<TorchState>(
              valueListenable: _cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
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
            icon: ValueListenableBuilder<CameraFacing>(
              valueListenable: _cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
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
                  onDetect: (capture) async {
                    if (_hasPopped) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String code = barcodes.first.rawValue ?? '';
                      if (code.isNotEmpty) {
                        _hasPopped = true;
                        try {
                          await _cameraController.stop();
                        } catch (_) {}

                        // Mainkan suara beep scan QR & haptic feedback
                        await SoundService.playBeep();

                        if (mounted) {
                          setState(() {
                            _isScanned = true;
                          });
                        }

                        // Beri jeda singkat agar suara terdengar jelas dan visual tampak
                        await Future.delayed(const Duration(milliseconds: 180));

                        if (!context.mounted) return;
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
                      border: Border.all(
                        color: _isScanned ? Colors.greenAccent : Colors.redAccent,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _isScanned ? Colors.green.withOpacity(0.15) : Colors.transparent,
                    ),
                    child: _isScanned
                        ? const Center(
                            child: Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 64),
                          )
                        : null,
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
                        onPressed: () => _handleManualSubmit(_manualInputController.text),
                      ),
                    ),
                    onSubmitted: (val) => _handleManualSubmit(val),
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
