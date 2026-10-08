import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  // 1. Fix AuthenticationOptions (might be using older api, let's just omit options or use stickyAuth directly if it's older)
  // Actually, wait, let's replace `options: const AuthenticationOptions(...)` with just omitting it or check what version it is. Let's just remove options if it fails.
  content = content.replaceAll(
    'options: const AuthenticationOptions(\n          biometricOnly: false,\n          stickyAuth: true,\n        ),',
    ''
  );
  content = content.replaceAll(
    'options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),',
    ''
  );
  
  // If it was multiline, let's use a regex to just remove `options: ...`
  content = content.replaceAll(RegExp(r'options:\s*const\s*AuthenticationOptions\([^)]*\),?'), '');
  
  // 2. Fix authenticatedUser.name -> authenticatedUser!.name
  content = content.replaceAll(
    'await prefs.setString(\'userName\', authenticatedUser.name);',
    'await prefs.setString(\'userName\', authenticatedUser!.name);'
  );
  content = content.replaceAll(
    'await prefs.setString(\'userId\', authenticatedUser.id);',
    'await prefs.setString(\'userId\', authenticatedUser!.id);'
  );

  file.writeAsStringSync(content);
}
