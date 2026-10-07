import 'dart:io';

void main() {
  final file = File('lib/core/database/tables.dart');
  String content = file.readAsStringSync();
  
  if (!content.contains('TextColumn get qrisBase64')) {
    content = content.replaceFirst(
      'TextColumn get logoBase64 => text().nullable()(); // Logo dalam bentuk base64',
      'TextColumn get logoBase64 => text().nullable()(); // Logo dalam bentuk base64\n  TextColumn get qrisBase64 => text().nullable()(); // QRIS image'
    );
    file.writeAsStringSync(content);
    print("Added qrisBase64");
  } else {
    print("Already added");
  }
}
