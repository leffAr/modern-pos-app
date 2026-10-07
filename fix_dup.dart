import 'dart:io';

void main() {
  final file = File('lib/features/settings/presentation/store_settings_screen.dart');
  String content = file.readAsStringSync();
  
  content = content.replaceAll(
    'qrisBase64: drift.Value(_qrisBase64),\n                qrisBase64: drift.Value(_qrisBase64),',
    'qrisBase64: drift.Value(_qrisBase64),'
  );
  
  file.writeAsStringSync(content);
}
