import 'package:flutter/material.dart';
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
        const SnackBar(content: Text('Email dan Password tidak boleh kosong!'), backgroundColor: Colors.red),
      );
      return;
    }

    List<User> users = await appDb.select(appDb.users).get();
    
    // Auto-seed default admin if no admin exists in the database
    if (users.where((u) => u.roleId == 'role-admin' || u.roleId == 'role-owner').isEmpty) {
      await appDb.into(appDb.users).insert(
        UsersCompanion.insert(
          id: 'USR-DEFAULT-ADMIN',
          name: 'Admin Utama',
          email: const drift.Value('admin'),
          password: drift.Value(_hashString('admin')),
          roleId: const drift.Value('role-admin'),
        )
      );
      users = await appDb.select(appDb.users).get();
    }

    final hashedPassword = _hashString(password);
    
    // Find user by email or username
    final matchingUsers = users.where((u) => u.email == email || u.name == email).toList();
    User? authenticatedUser;

    for (var u in matchingUsers) {
      if (u.password == hashedPassword) {
        authenticatedUser = u;
        break;
      } else if (u.password == password) {
        // Migration: password is still plaintext in DB, update it to hash
        await (appDb.update(appDb.users)..where((tbl) => tbl.id.equals(u.id))).write(
          UsersCompanion(password: drift.Value(hashedPassword))
        );
        authenticatedUser = u;
        break;
      }
    }

    if (context.mounted) {
      if (authenticatedUser != null) {
        String mappedRole = 'Kasir';
        if (authenticatedUser.roleId == 'role-admin' || authenticatedUser.roleId == 'role-owner') {
          mappedRole = 'Admin';
        }
        
        // Save session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userRole', mappedRole);
        await prefs.setString('userName', authenticatedUser!.name);
        await prefs.setString('userId', authenticatedUser!.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selamat datang, ${authenticatedUser!.name}! ($mappedRole)')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainLayout(userRole: mappedRole, userName: authenticatedUser!.name, userId: authenticatedUser!.id)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email/Username atau Password salah!'), backgroundColor: Colors.red),
        );
      }
    }
  }


  void _showPinLoginDialog() {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login dengan PIN (Khusus Kasir)'),
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
              child: const Text('Batal')
            ),
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
                    await (appDb.update(appDb.users)..where((tbl) => tbl.id.equals(u.id))).write(
                      UsersCompanion(pin: drift.Value(hashedPin))
                    );
                    authenticatedUser = u;
                    break;
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context); // Tutup dialog

                  if (authenticatedUser != null) {
                    String mappedRole = 'Kasir';
                    if (authenticatedUser.roleId == 'role-admin' || authenticatedUser.roleId == 'role-owner') {
                      mappedRole = 'Admin';
                    }
                    
                    // Save session
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', true);
                    await prefs.setString('userRole', mappedRole);
                    await prefs.setString('userName', authenticatedUser!.name);
                    await prefs.setString('userId', authenticatedUser!.id);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selamat datang, ${authenticatedUser!.name}! ($mappedRole)')),
                    );
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => MainLayout(userRole: mappedRole, userName: authenticatedUser!.name, userId: authenticatedUser!.id)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIN Salah atau Kasir tidak ditemukan!'), backgroundColor: Colors.red),
                    );
                  }
                }
              }, 
              child: const Text('Masuk')
            ),
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
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<Business?>(
                  stream: (appDb.select(appDb.businesses)..limit(1)).watchSingleOrNull(),
                  builder: (context, snapshot) {
                    final business = snapshot.data;
                    final logoBase64 = business?.logoBase64;
                    
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: logoBase64 != null
                              ? Image.memory(
                                  base64Decode(logoBase64),
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                )
                              : Image.asset(
                                  'assets/images/logo_transparent.png',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          business?.name ?? 'Modern POS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk ke akun bisnis Anda',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                


                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email / Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _handleLogin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('MASUK'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _showPinLoginDialog,
                  child: const Text('Login dengan PIN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
