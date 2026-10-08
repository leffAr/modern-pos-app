import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  final lines = file.readAsLinesSync();
  
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains("title: 'Stok Tipis',")) {
      print("Found Stok Tipis at line: \${i + 1}");
      for (int j = i - 5; j <= i + 15; j++) {
        print("\$j: \${lines[j]}");
      }
      break;
    }
  }
}
