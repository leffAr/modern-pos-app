import 'dart:io';

void main() {
  final file = File('lib/features/pos/presentation/pos_screen.dart');
  String content = file.readAsStringSync();
  
  // 1. Add field to _CheckoutDialog
  content = content.replaceFirst(
    'final bool hasCustomer;',
    'final bool hasCustomer;\n  final String? qrisBase64;'
  );
  
  content = content.replaceFirst(
    'required this.hasCustomer,',
    'required this.hasCustomer,\n      this.qrisBase64,'
  );

  // 2. Pass the value when instantiated
  content = content.replaceFirst(
    'hasCustomer: _selectedCustomer != null,',
    'hasCustomer: _selectedCustomer != null,\n          qrisBase64: _qrisBase64,'
  );

  // 3. Fix the state usage
  // The error was because we used _qrisBase64 directly inside _CheckoutDialogState.
  // It should be widget.qrisBase64!
  content = content.replaceAll('_qrisBase64', 'widget.qrisBase64');
  // Wait, if I replace all `_qrisBase64`, I will break `_POSScreenState`!
  // I must only replace it inside the `_CheckoutDialogState`!
  // It's safer to just fix those two instances explicitly.
  
  // Let's reload content and do it manually for the dialog lines
  // Let's replace: `child: (_qrisBase64 != null && _qrisBase64!.isNotEmpty)`
  // with `child: (widget.qrisBase64 != null && widget.qrisBase64!.isNotEmpty)`
  content = content.replaceFirst(
    'child: (_qrisBase64 != null && _qrisBase64!.isNotEmpty)',
    'child: (widget.qrisBase64 != null && widget.qrisBase64!.isNotEmpty)'
  );
  
  content = content.replaceFirst(
    'base64Decode(_qrisBase64!),',
    'base64Decode(widget.qrisBase64!),'
  );

  file.writeAsStringSync(content);
  print("SUCCESS");
}
