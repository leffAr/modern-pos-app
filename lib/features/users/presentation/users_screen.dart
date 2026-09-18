import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Stream<List<User>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = appDb.select(appDb.users).watch();
  }

  void _showAddEditDialog([User? user]) {
    final isEditing = user != null;
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final passwordController = TextEditingController();
    final pinController = TextEditingController();
    
    // roleId in DB: 'role-admin' or 'role-cashier'
    String selectedRole = user?.roleId == 'role-admin' ? 'role-admin' : 'role-cashier';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Pengguna' : 'Tambah Pengguna'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Pilih Peran (Role)'),
                      items: const [
                        DropdownMenuItem(value: 'role-cashier', child: Text('Kasir')),
                        DropdownMenuItem(value: 'role-admin', child: Text('Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null) setStateSB(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email / Username'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Nomor HP (Opsional)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PIN Angka (Untuk Login Cepat)',
                        hintText: 'Contoh: 1234'
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                FilledButton(
                  onPressed: () async {
                    final nameText = nameController.text.trim();
                    final emailText = emailController.text.trim();
                    final passText = passwordController.text.trim();
                    
                    if (nameText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama Lengkap tidak boleh kosong')));
                      return;
                    }
                    if (emailText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email / Username tidak boleh kosong')));
                      return;
                    }
                    if (!isEditing && passText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password harus diisi untuk pengguna baru')));
                      return;
                    }

                    String _hashString(String input) {
                      final bytes = utf8.encode(input);
                      final digest = sha256.convert(bytes);
                      return digest.toString();
                    }

                    final pinText = pinController.text.trim();
                    
                    String finalPassword = user?.password ?? '';
                    if (passText.isNotEmpty) {
                      finalPassword = _hashString(passText);
                    }
                    String finalPin = user?.pin ?? '';
                    if (pinText.isNotEmpty) {
                      finalPin = _hashString(pinText);
                      
                      // Validasi PIN unik
                      final existingUserWithPin = await (appDb.select(appDb.users)
                        ..where((u) => u.pin.equals(finalPin)))
                        .getSingleOrNull();
                        
                      if (existingUserWithPin != null && (!isEditing || existingUserWithPin.id != user!.id)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error: Kode PIN ini sudah digunakan oleh akun lain. Harap gunakan PIN yang berbeda!'),
                              backgroundColor: Colors.red,
                            )
                          );
                        }
                        return; // Berhenti dan jangan simpan
                      }
                    }

                    final companion = UsersCompanion(
                      id: isEditing ? drift.Value(user!.id) : drift.Value('USR-${DateTime.now().millisecondsSinceEpoch}'),
                      name: drift.Value(nameController.text.trim()),
                      email: drift.Value(emailController.text.trim()),
                      phone: drift.Value(phoneController.text.trim()),
                      password: drift.Value(finalPassword),
                      pin: drift.Value(finalPin),
                      roleId: drift.Value(selectedRole),
                    );

                    if (isEditing) {
                      await (appDb.update(appDb.users)..where((t) => t.id.equals(user!.id))).write(companion);
                    } else {
                      await appDb.into(appDb.users).insert(companion);
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun?'),
        content: Text('Yakin ingin menghapus akun ${user.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await (appDb.delete(appDb.users)..where((t) => t.id.equals(user.id))).go();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Akun Kasir'),
      ),
      body: StreamBuilder<List<User>>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.manage_accounts, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Belum ada pengguna terdaftar.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Pengguna Pertama'),
                    onPressed: () => _showAddEditDialog(),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.roleId == 'role-admin' ? Colors.purple.shade100 : Colors.blue.shade100,
                    child: Icon(user.roleId == 'role-admin' ? Icons.admin_panel_settings : Icons.person, color: user.roleId == 'role-admin' ? Colors.purple : Colors.blue),
                  ),
                  title: Text('${user.name} (${user.roleId == 'role-admin' ? 'Admin' : 'Kasir'})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${user.email ?? 'Tidak ada email'}\nHP: ${user.phone ?? '-'}\nPIN: ${user.pin != null && user.pin!.isNotEmpty ? '(Terenkripsi)' : 'Belum Diatur'}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showAddEditDialog(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(user),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Pengguna Baru'),
      ),
    );
  }
}
