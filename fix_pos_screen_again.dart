import 'dart:io';

void main() {
  final file = File('lib/features/pos/presentation/pos_screen.dart');
  String content = file.readAsStringSync();
  
  // Revert the horrible replaceAll
  content = content.replaceAll('widget.qrisBase64', '_qrisBase64');
  
  // Now carefully fix just the two usages inside _CheckoutDialogState
  // We look for the block inside _CheckoutDialogState where we display the image
  final dialogBlock = """
              child: (_qrisBase64 != null && _qrisBase64!.isNotEmpty)
                  ? Column(
                      children: [
                        const Text("Silakan Scan QRIS ini untuk membayar:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple)),
                        const SizedBox(height: 12),
                        Image.memory(
                          base64Decode(_qrisBase64!),
                          width: 250,
                          height: 250,
                          fit: BoxFit.contain,
                        ),
""";
  final fixedDialogBlock = """
              child: (widget.qrisBase64 != null && widget.qrisBase64!.isNotEmpty)
                  ? Column(
                      children: [
                        const Text("Silakan Scan QRIS ini untuk membayar:",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple)),
                        const SizedBox(height: 12),
                        Image.memory(
                          base64Decode(widget.qrisBase64!),
                          width: 250,
                          height: 250,
                          fit: BoxFit.contain,
                        ),
""";

  if (content.contains(dialogBlock)) {
    content = content.replaceFirst(dialogBlock, fixedDialogBlock);
    print("SUCCESS: Replaced dialog block");
  } else {
    print("WARNING: Dialog block not found exactly as string");
    // Fallback: manually replace inside the specific lines
    content = content.replaceFirst(
      'child: (_qrisBase64 != null && _qrisBase64!.isNotEmpty)',
      'child: (widget.qrisBase64 != null && widget.qrisBase64!.isNotEmpty)'
    );
    content = content.replaceFirst(
      'base64Decode(_qrisBase64!),',
      'base64Decode(widget.qrisBase64!),'
    );
  }
  
  // But wait, there's another usage when instantiating `_CheckoutDialog`:
  // builder: (context) => _CheckoutDialog( ... qrisBase64: _qrisBase64 )
  // My replaceAll changed it to `qrisBase64: _qrisBase64` which is correct since we reverted it!
  // Wait, no! If I revert `widget.qrisBase64` to `_qrisBase64`, then the constructor of `_CheckoutDialog` will become:
  // `final String? _qrisBase64;`
  // And `this._qrisBase64`. Which is wrong! It should be public `qrisBase64`.
  
  // Let's fix the constructor of _CheckoutDialog manually
  content = content.replaceFirst('final String? _qrisBase64;', 'final String? qrisBase64;');
  content = content.replaceFirst('this._qrisBase64,', 'this.qrisBase64,');
  content = content.replaceFirst('qrisBase64: _qrisBase64,', 'qrisBase64: _qrisBase64,');

  file.writeAsStringSync(content);
}
