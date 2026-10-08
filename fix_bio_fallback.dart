import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  final regex = RegExp(r'Future<void> _authenticateWithBiometrics\(\) async \{[\s\S]*?\}\s*\}');
  
  final newMethod = """Future<void> _authenticateWithBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUserId = prefs.getString('userId');
    final usersList = await appDb.select(appDb.users).get();
    User? authenticatedUser;

    if (lastUserId != null) {
      authenticatedUser = usersList.where((u) => u.id == lastUserId).firstOrNull;
    }

    if (authenticatedUser == null) {
      authenticatedUser = usersList.where((u) => u.roleId == 'role-admin' || u.roleId == 'role-owner').firstOrNull;
    }

    // Jika biometrik ditolak dari Kelola User, langsung minta PIN!
    if (authenticatedUser != null && !authenticatedUser.allowBiometric) {
      if (context.mounted) _showPinLoginDialog();
      return;
    }

    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (context.mounted) _showPinLoginDialog();
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Gunakan sidik jari untuk masuk',
      );

      if (didAuthenticate && context.mounted) {
        if (authenticatedUser != null) {
          String mappedRole = 'Kasir';
          if (authenticatedUser.roleId == 'role-admin' || authenticatedUser.roleId == 'role-owner') {
            mappedRole = 'Admin';
          }

          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userRole', mappedRole);
          await prefs.setString('userName', authenticatedUser!.name);
          await prefs.setString('userId', authenticatedUser!.id);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selamat datang kembali, \${authenticatedUser!.name}!')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (context) => MainLayout(
                    userRole: mappedRole,
                    userName: authenticatedUser!.name,
                    userId: authenticatedUser!.id)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menemukan data pengguna terakhir. Silakan login manual.')),
          );
        }
      } else {
        // Gagal 3x atau batal, langsung ke PIN!
        if (context.mounted) _showPinLoginDialog();
      }
    } catch (e) {
      // Gagal sistem (misal API diblokir / too many attempts), ke PIN!
      if (context.mounted) _showPinLoginDialog();
    }
  }""";
  
  if (content.contains('Future<void> _authenticateWithBiometrics() async {')) {
    content = content.replaceFirst(regex, newMethod);
    file.writeAsStringSync(content);
    print('SUCCESS');
  } else {
    print('ERROR: Not found');
  }
}
