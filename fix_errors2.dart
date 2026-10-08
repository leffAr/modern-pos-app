import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  content = content.replaceAll(
    'Text(\'Selamat datang kembali, \${authenticatedUser.name}!\')',
    'Text(\'Selamat datang kembali, \${authenticatedUser!.name}!\')'
  );
  content = content.replaceAll(
    'userName: authenticatedUser.name,',
    'userName: authenticatedUser!.name,'
  );
  content = content.replaceAll(
    'userId: authenticatedUser.id',
    'userId: authenticatedUser!.id'
  );

  file.writeAsStringSync(content);
}
