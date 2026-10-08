import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/utils/image_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../dashboard/presentation/main_layout.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _keepLoggedIn = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Email dan Password tidak boleh kosong!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    List<User> users = await appDb.select(appDb.users).get();

    // Auto-seed default admin if no admin exists in the database
    if (users
        .where((u) => u.roleId == 'role-admin' || u.roleId == 'role-owner')
        .isEmpty) {
      await appDb.into(appDb.users).insert(UsersCompanion.insert(
            id: 'USR-DEFAULT-ADMIN',
            name: 'Admin Utama',
            email: const drift.Value('admin'),
            password: drift.Value(_hashString('admin')),
            roleId: const drift.Value('role-admin'),
          ));
      users = await appDb.select(appDb.users).get();
    }

    final hashedPassword = _hashString(password);

    // Find user by email or username
    final matchingUsers =
        users.where((u) => u.email == email || u.name == email).toList();
    User? authenticatedUser;

    for (var u in matchingUsers) {
      if (u.password == hashedPassword) {
        authenticatedUser = u;
        break;
      } else if (u.password == password) {
        // Migration: password is still plaintext in DB, update it to hash
        await (appDb.update(appDb.users)..where((tbl) => tbl.id.equals(u.id)))
            .write(UsersCompanion(password: drift.Value(hashedPassword)));
        authenticatedUser = u;
        break;
      }
    }

    if (context.mounted) {
      if (authenticatedUser != null) {
        String mappedRole = 'Kasir';
        if (authenticatedUser.roleId == 'role-admin' ||
            authenticatedUser.roleId == 'role-owner') {
          mappedRole = 'Admin';
        }

        // Save session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userRole', mappedRole);
        await prefs.setString('userName', authenticatedUser!.name);
        await prefs.setString('userId', authenticatedUser!.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Selamat datang, ${authenticatedUser!.name}! ($mappedRole)')),
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
          const SnackBar(
              content: Text('Email/Username atau Password salah!'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
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
            SnackBar(content: Text('Selamat datang kembali, ${authenticatedUser!.name}!')),
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
  }


  void _showPinLoginDialog() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login dengan PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Masukkan 4 Digit PIN Anda:'),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () async {
                  final pin = pinController.text.trim();
                  if (pin.isEmpty) return;

                  // Cari user di database yang pin-nya cocok
                  final usersList = await appDb.select(appDb.users).get();
                  final hashedPin = _hashString(pin);
                  User? authenticatedUser;

                  for (var u in usersList) {
                    if (u.pin == hashedPin) {
                      authenticatedUser = u;
                      break;
                    } else if (u.pin == pin) {
                      // Migration: pin is still plaintext in DB, update it to hash
                      await (appDb.update(appDb.users)
                            ..where((tbl) => tbl.id.equals(u.id)))
                          .write(UsersCompanion(pin: drift.Value(hashedPin)));
                      authenticatedUser = u;
                      break;
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(context); // Tutup dialog

                    if (authenticatedUser != null) {
                      String mappedRole = 'Kasir';
                      if (authenticatedUser.roleId == 'role-admin' ||
                          authenticatedUser.roleId == 'role-owner') {
                        mappedRole = 'Admin';
                      }

                      // Save session
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isLoggedIn', true);
                      await prefs.setString('userRole', mappedRole);
                      await prefs.setString(
                          'userName', authenticatedUser!.name);
                      await prefs.setString('userId', authenticatedUser!.id);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Selamat datang, ${authenticatedUser!.name}! ($mappedRole)')),
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
                        const SnackBar(
                            content:
                                Text('PIN Salah atau Kasir tidak ditemukan!'),
                            backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Masuk')),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    final loginCard = Card(
      elevation: 4,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Login',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.person, color: Colors.blueGrey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Keep me logged in',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _keepLoggedIn,
                  activeColor: Colors.tealAccent.shade400,
                  onChanged: (v) {
                    setState(() => _keepLoggedIn = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _handleLogin,
              child: const Text('Log in',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      iconSize: 40,
                      color: Colors.blue,
                      icon: const Icon(Icons.fingerprint),
                      onPressed: _authenticateWithBiometrics,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Login With TouchId',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );

    final leftContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<Business?>(
            stream:
                (appDb.select(appDb.businesses)..limit(1)).watchSingleOrNull(),
            builder: (context, snapshot) {
              final business = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business?.name ?? 'Modern POS',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Online inventory management system',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563)),
                  ),
                ],
              );
            }),
        const SizedBox(height: 48),
        loginCard,
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: isWide
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: leftContent,
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    color: const Color(0xFFE3F2FD),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -100,
                          bottom: -100,
                          child: Container(
                            width: 600,
                            height: 600,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBBDEFB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: -50,
                          top: -50,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              color: const Color(0xFF90CAF9),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.point_of_sale_rounded,
                                  size: 250, color: Colors.blue.shade700),
                              const SizedBox(height: 24),
                              Text(
                                'Modern POS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          : Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: leftContent,
                ),
              ),
            ),
    );
  }
}
