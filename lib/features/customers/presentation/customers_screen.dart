import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';

class CustomersScreen extends StatefulWidget {
  final String userRole;
  const CustomersScreen({super.key, required this.userRole});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Stream<List<Customer>> _customersStream;

  @override
  void initState() {
    super.initState();
    // Membaca data pelanggan secara real-time dari SQLite
    _customersStream = appDb.select(appDb.customers).watch();
  }

  void _showAddEditDialog([Customer? customer]) {
    final nameCtrl = TextEditingController(text: customer?.name);
    final phoneCtrl = TextEditingController(text: customer?.phone);
    final emailCtrl = TextEditingController(text: customer?.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer == null ? 'Tambah Pelanggan Baru' : 'Edit Pelanggan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor Telepon', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama tidak boleh kosong!')));
                return;
              }

              if (customer == null) {
                // INSERT NEW
                await appDb.into(appDb.customers).insert(
                  CustomersCompanion.insert(
                    id: 'CUST-${DateTime.now().millisecondsSinceEpoch}',
                    businessId: 'BIZ-1', // Dummy ID Bisnis
                    name: nameCtrl.text,
                    phone: drift.Value(phoneCtrl.text),
                    email: drift.Value(emailCtrl.text),
                    point: const drift.Value(0), // Default Poin
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pelanggan berhasil ditambahkan')));
              } else {
                // UPDATE EXISTING
                await (appDb.update(appDb.customers)..where((t) => t.id.equals(customer.id))).write(
                  CustomersCompanion(
                    name: drift.Value(nameCtrl.text),
                    phone: drift.Value(phoneCtrl.text),
                    email: drift.Value(emailCtrl.text),
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data pelanggan diperbarui')));
              }

              Navigator.pop(context);
            },
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
  }

  void _showPayDebtDialog(Customer customer) {
    final amountCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bayar Utang: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sisa Utang: Rp ${customer.debt.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nominal Bayar',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          FilledButton(
            onPressed: () async {
              final amountStr = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
              final amount = double.tryParse(amountStr) ?? 0.0;
              
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal tidak valid!')));
                return;
              }

              if (amount > customer.debt) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nominal lebih besar dari sisa utang!')));
                return;
              }

              // Update customer debt
              await (appDb.update(appDb.customers)..where((c) => c.id.equals(customer.id))).write(
                CustomersCompanion(debt: drift.Value(customer.debt - amount))
              );

              // Record payment in DebtPayments
              await appDb.into(appDb.debtPayments).insert(
                DebtPaymentsCompanion.insert(
                  id: 'DP-${DateTime.now().microsecondsSinceEpoch}',
                  customerId: customer.id,
                  amount: amount,
                  notes: const drift.Value('Pembayaran Utang Kasbon')
                )
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembayaran kasbon berhasil dicatat!')));
              }
            },
            child: const Text('BAYAR'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pelanggan?'),
        content: Text('Anda yakin ingin menghapus data ${customer.name}? Riwayat transaksi mereka mungkin akan terpengaruh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await (appDb.delete(appDb.customers)..where((t) => t.id.equals(customer.id))).go();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data Pelanggan dihapus')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan (CRM)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Search logic
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Customer>>(
        stream: _customersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final customers = snapshot.data ?? [];

          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Belum ada pelanggan terdaftar.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Pelanggan'),
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final c = customers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent.shade100,
                  child: Text(
                    c.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Telp: ${c.phone ?? '-'}\nEmail: ${c.email ?? '-'}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${c.point} Pts', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        if (c.debt > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Utang: Rp ${c.debt.toInt()}', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'bayar_utang') _showPayDebtDialog(c);
                        if (val == 'edit') _showAddEditDialog(c);
                        if (val == 'delete') _deleteCustomer(c);
                      },
                      itemBuilder: (context) => [
                        if (c.debt > 0)
                          const PopupMenuItem(value: 'bayar_utang', child: Text('Bayar Kasbon/Utang')),
                        if (widget.userRole == 'Admin')
                          const PopupMenuItem(value: 'edit', child: Text('Edit Data')),
                        if (widget.userRole == 'Admin')
                          const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Pelanggan'),
      ),
    );
  }
}
