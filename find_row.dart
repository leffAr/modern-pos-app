import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  final regex = RegExp(r"Row\(\s*children: \[\s*_buildQuickActionIcon\([\s\S]*?Stok Tipis[\s\S]*?\}\s*\)\s*,?\s*\]\s*,\s*\)");
  
  if (regex.hasMatch(content)) {
    final match = regex.firstMatch(content);
    if (match != null) {
      print("Found Row!");
    }
  } else {
    print("Not found!");
  }
}
