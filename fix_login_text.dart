import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  final oldText = "'Manage Your Store\\nEfficiently & Easily'";
  final newText = "'Modern POS'";
  
  if (content.contains(oldText)) {
    content = content.replaceFirst(oldText, newText);
    file.writeAsStringSync(content);
    print("SUCCESS: Text replaced");
  } else {
    print("ERROR: Text not found");
  }
}
