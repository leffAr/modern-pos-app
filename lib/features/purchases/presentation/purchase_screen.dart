import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import 'purchase_form_screen.dart';
import 'return_form_screen.dart';
import 'package:drift/drift.dart' as drift;

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _formatter = NumberFormat('#,###', 'id_ID');

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_shopping_cart),
            title: const Text('Buat Purchase Order (Pembelian)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseFormScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_return),
            title: const Text('Buat Retur Pembelian'),
            onTap: () {
              Navigator.pop(context);
              _showReturnForm();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _deletePurchase(Purchase p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pembelian?'),
        content: Text('Apakah Anda yakin ingin menghapus "${p.referenceNumber}"?\n\nPeringatan: Menghapus pembelian tidak akan mengembalikan stok produk.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await appDb.transaction(() async {
                await (appDb.delete(appDb.purchaseItems)..where((t) => t.purchaseId.equals(p.id))).go();
                await (appDb.delete(appDb.purchases)..where((t) => t.id.equals(p.id))).go();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembelian dihapus!')));
              }
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  void _showReturnForm([Return? existing]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnFormScreen(existingReturn: existing)));
  }

  void _deleteReturn(Return r) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Retur?'),
        content: Text('Apakah Anda yakin ingin menghapus retur untuk transaksi "${r.transactionId}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await (appDb.delete(appDb.returns)..where((t) => t.id.equals(r.id))).go();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retur dihapus!')));
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pembelian & Retur'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pembelian (Purchase Order)'),
              Tab(text: 'Retur Pembelian'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPurchaseList(),
            _buildReturnList(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('Buat Baru'),
        ),
      ),
    );
  }

  Widget _buildPurchaseList() {
    return StreamBuilder<List<Purchase>>(
      stream: (appDb.select(appDb.purchases)..orderBy([(t) => drift.OrderingTerm.desc(t.date)])).watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final purchases = snapshot.data!;
        
        if (purchases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Belum Ada Pembelian', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('Tekan tombol "Buat Baru" untuk mencatat pembelian.', style: TextStyle(color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final p = purchases[index];
            return FutureBuilder<Supplier>(
              future: (appDb.select(appDb.suppliers)..where((t) => t.id.equals(p.supplierId))).getSingle(),
              builder: (context, suppSnap) {
                final supplierName = suppSnap.data?.name ?? 'Loading...';
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.local_shipping, color: Colors.white),
                    ),
                    title: Text(p.referenceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Supplier: $supplierName\nTanggal: ${DateFormat('dd MMM yyyy').format(p.date)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Rp ${_formatter.format(p.total.toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseFormScreen(existingPurchase: p)));
                            if (value == 'delete') _deletePurchase(p);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit/Lihat')])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              }
            );
          },
        );
      }
    );
  }

  Widget _buildReturnList() {
    return StreamBuilder<List<Return>>(
      stream: (appDb.select(appDb.returns)..orderBy([(t) => drift.OrderingTerm.desc(t.date)])).watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final returns = snapshot.data!;
        
        if (returns.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.keyboard_return_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Belum Ada Retur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('Tekan tombol "Buat Baru" untuk mencatat retur.', style: TextStyle(color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: returns.length,
          itemBuilder: (context, index) {
            final r = returns[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.keyboard_return, color: Colors.white),
                ),
                title: Text(r.transactionId, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Alasan: ${r.reason}\nTanggal: ${DateFormat('dd MMM yyyy').format(r.date)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rp ${_formatter.format(r.amountRefunded.toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                        const Text('Refund', style: TextStyle(fontSize: 11, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') _showReturnForm(r);
                        if (value == 'delete') _deleteReturn(r);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      }
    );
  }
}
