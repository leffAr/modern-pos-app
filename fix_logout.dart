import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/main_layout.dart');
  String content = file.readAsStringSync();
  content = content.replaceAll('await prefs.clear();', 'await prefs.setBool(\'isLoggedIn\', false);');
  file.writeAsStringSync(content);
}
