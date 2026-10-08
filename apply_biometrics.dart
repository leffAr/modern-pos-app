import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  // 1. Add import for local_auth
  if (!content.contains('package:local_auth/local_auth.dart')) {
    content = content.replaceFirst(
      'import \'package:flutter/material.dart\';',
      'import \'package:flutter/material.dart\';\nimport \'package:local_auth/local_auth.dart\';'
    );
  }
  
  // 2. Add _authenticateWithBiometrics method before _showPinLoginDialog
  final bioMethod = r"""
  Future<void> _authenticateWithBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perangkat ini tidak mendukung login biometrik (sidik jari/wajah).')),
          );
        }
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Gunakan sidik jari atau PIN perangkat untuk masuk',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate && context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        final lastUserId = prefs.getString('userId');
        
        final usersList = await appDb.select(appDb.users).get();
        User? authenticatedUser;
        
        if (lastUserId != null) {
           authenticatedUser = usersList.where((u) => u.id == lastUserId).firstOrNull;
        }
        
        // Fallback to default admin if no previous user
        if (authenticatedUser == null) {
           authenticatedUser = usersList.where((u) => u.roleId == 'role-admin' || u.roleId == 'role-owner').firstOrNull;
        }

        if (authenticatedUser != null) {
          String mappedRole = 'Kasir';
          if (authenticatedUser.roleId == 'role-admin' || authenticatedUser.roleId == 'role-owner') {
            mappedRole = 'Admin';
          }
          
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userRole', mappedRole);
          await prefs.setString('userName', authenticatedUser.name);
          await prefs.setString('userId', authenticatedUser.id);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selamat datang kembali, ${authenticatedUser.name}!')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => MainLayout(userRole: mappedRole, userName: authenticatedUser.name, userId: authenticatedUser.id)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menemukan data pengguna terakhir. Silakan login manual.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error otentikasi: $e')),
        );
      }
    }
  }

  void _showPinLoginDialog() {
""";
  content = content.replaceFirst('  void _showPinLoginDialog() {', bioMethod);

  // 3. Replace fingerprint button action and label
  content = content.replaceFirst(
    'onPressed: _showPinLoginDialog,',
    'onPressed: _authenticateWithBiometrics,'
  );
  content = content.replaceFirst(
    'const Text(\'Login With PIN\'',
    'const Text(\'Login With TouchId\''
  );
  
  // 4. Add "Login dengan PIN" text button below
  final textBtn = r"""
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showPinLoginDialog,
                    child: const Text('Gunakan PIN Kasir', style: TextStyle(color: Colors.grey)),
                  ),
""";
  
  content = content.replaceFirst(
    'style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),',
    'style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),' + textBtn
  );

  file.writeAsStringSync(content);
  print("SUCCESS");
}
