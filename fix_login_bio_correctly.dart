import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  // Undo the wrong placement
  final wrongBlock = """
        if (!authenticatedUser.allowBiometric) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Akses biometrik ditolak untuk \${authenticatedUser!.name}. Silakan aktifkan di menu Kelola User.')),
          );
          return;
        }
""";
  content = content.replaceAll(wrongBlock, '');
  
  // Also clean up formatting variations just in case
  content = content.replaceAll(RegExp(r'\s*if \(!authenticatedUser\.allowBiometric\) \{[\s\S]*?return;\s*\}'), '');

  // Now, inject it properly into _authenticateWithBiometrics
  // Let's find the exact string inside _authenticateWithBiometrics
  // We can look for `// Fallback to default admin if no previous user` block
  final targetRegex = RegExp(r'// Fallback to default admin if no previous user[\s\S]*?if \(authenticatedUser != null\) \{');
  final match = targetRegex.firstMatch(content);
  if (match != null) {
    content = content.replaceFirst(
      match.group(0)!,
      match.group(0)! + '\n          if (!authenticatedUser.allowBiometric) {\n            ScaffoldMessenger.of(context).showSnackBar(\n              SnackBar(content: Text(\'Akses biometrik ditolak untuk \${authenticatedUser!.name}. Silakan aktifkan di menu Kelola User.\')),\n            );\n            return;\n          }'
    );
  }

  file.writeAsStringSync(content);
}
