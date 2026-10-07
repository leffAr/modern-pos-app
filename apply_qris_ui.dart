import 'dart:io';

void main() {
  final file = File('lib/features/pos/presentation/pos_screen.dart');
  String content = file.readAsStringSync();

  // Add _qrisBase64
  if (!content.contains('String? _qrisBase64;')) {
    content = content.replaceFirst(
      'double _taxPercentage = 0.0;',
      'double _taxPercentage = 0.0;\n  String? _qrisBase64;'
    );
  }

  // Set _qrisBase64 in listener
  if (!content.contains('_qrisBase64 = biz.qrisBase64;')) {
    content = content.replaceFirst(
      '_taxPercentage = biz.taxPercentage;',
      '_taxPercentage = biz.taxPercentage;\n          _qrisBase64 = biz.qrisBase64;'
    );
  }

  // Replace QRIS display block
  final oldQrisBlock = """            ] else if (_paymentMethod == 'QRIS') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.qr_code_2, size: 40, color: Colors.purple),
                    SizedBox(width: 16),
                    Expanded(
                        child: Text(
                            "Pembayaran via QRIS. Pelanggan memindai kode QR toko.",
                            style: TextStyle(color: Colors.purple))),
                  ],
                ),
              ),
            ] else ...[""";
            
  final newQrisBlock = """            ] else if (_paymentMethod == 'QRIS') ...[
              if (_qrisBase64 != null)
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      const Text("Pindai QRIS untuk Membayar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Image.memory(
                        base64Decode(_qrisBase64!),
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_2, size: 40, color: Colors.purple),
                      SizedBox(width: 16),
                      Expanded(
                          child: Text(
                              "Pembayaran via QRIS. Gambar QR belum diatur di Pengaturan Toko.",
                              style: TextStyle(color: Colors.purple))),
                    ],
                  ),
                ),
            ] else ...[""";

  if (content.contains('Icon(Icons.qr_code_2, size: 40, color: Colors.purple)')) {
    content = content.replaceFirst(oldQrisBlock, newQrisBlock);
    file.writeAsStringSync(content);
    print("Success");
  } else {
    print("Could not find QRIS block");
  }
}
