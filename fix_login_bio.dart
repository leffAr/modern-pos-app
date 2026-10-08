import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  // We need to modify _authenticateWithBiometrics to check user.allowBiometric
  // If it's false, we deny entry.
  content = content.replaceFirst(
    'if (authenticatedUser != null) {',
    'if (authenticatedUser != null) {\n          if (!authenticatedUser.allowBiometric) {\n            ScaffoldMessenger.of(context).showSnackBar(\n              SnackBar(content: Text(\'Akses biometrik ditolak untuk \${authenticatedUser!.name}. Silakan aktifkan di menu Kelola User.\')),\n            );\n            return;\n          }'
  );
  
  file.writeAsStringSync(content);
  print("SUCCESS");
}
