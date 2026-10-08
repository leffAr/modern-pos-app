import 'dart:io';

void main() {
  final file = File('lib/features/pos/presentation/pos_screen.dart');
  String content = file.readAsStringSync();
  
  final oldBlock = """
              if (paymentMethod == 'QRIS') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2, size: 40, color: Colors.purple),
                      const SizedBox(width: 16),
                      const Expanded(
                          child: Text(
                              "Pembayaran via QRIS. Pelanggan memindai kode QR toko.",
                              style: TextStyle(color: Colors.purple))),
                    ],
                  ),
                ),
              ] else ...[
""";

  final newBlock = """
              if (paymentMethod == 'QRIS') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8)),
                  child: (_qrisBase64 != null && _qrisBase64!.isNotEmpty)
                      ? Column(
                          children: [
                            const Text("Silakan Scan QRIS ini untuk membayar:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                            const SizedBox(height: 12),
                            Image.memory(
                              base64Decode(_qrisBase64!),
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(Icons.qr_code_2, size: 40, color: Colors.purple),
                            const SizedBox(width: 16),
                            const Expanded(
                                child: Text(
                                    "Pembayaran via QRIS. (Gambar QR belum diatur oleh Admin)",
                                    style: TextStyle(color: Colors.purple))),
                          ],
                        ),
                ),
              ] else ...[
""";

  // Using RegExp because we might not have `const` modifiers in the exact same place
  final targetRegex = RegExp(r"if\s*\(paymentMethod\s*==\s*'QRIS'\)\s*\.\.\.\[[\s\S]*?Pembayaran via QRIS[\s\S]*?\]\s*else\s*\.\.\.\[");
  
  final match = targetRegex.firstMatch(content);
  if (match != null) {
    content = content.replaceFirst(match.group(0)!, newBlock);
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("ERROR: block not found");
  }
}
