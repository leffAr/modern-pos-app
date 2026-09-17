import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final List<Map<String, dynamic>> _purchases = [
    {'po': 'PO-20260910-001', 'supplier': 'PT Maju Bersama', 'total': 2500000.0, 'status': 'SELESAI (Stok Bertambah)'},
  ];

  final List<Map<String, dynamic>> _returns = [
    {'ret': 'RET-20260910-001', 'inv': 'INV-20260910-001', 'reason': 'Barang Cacat', 'refund': 15000.0},
  ];

  final _formatter = NumberFormat('#,###', 'id_ID');

  // ==================== PURCHASE METHODS ====================

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('Buat Purchase Order (Pembelian)'),
            onTap: () {
              Navigator.pop(context);
              _showPurchaseForm();
            },
          ),
          ListTile(
            leading: const Icon(Icons.keyboard_return),
            title: const Text('Buat Retur Transaksi'),
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

  void _showPurchaseForm([Map<String, dynamic>? existing, int? index]) {
    final supplierCtrl = TextEditingController(text: existing?['supplier'] ?? '');
    final totalCtrl = TextEditingController(text: existing != null ? existing['total'].toInt().toString() : '');
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Pembelian' : 'Tambah Pembelian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: supplierCtrl,
              decoration: const InputDecoration(labelText: 'Nama Supplier', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total Biaya', prefixText: 'Rp ', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          FilledButton(
            onPressed: () {
              if (supplierCtrl.text.isNotEmpty && totalCtrl.text.isNotEmpty) {
                setState(() {
                  if (isEdit && index != null) {
                    _purchases[index] = {
                      'po': existing['po'],
                      'supplier': supplierCtrl.text,
                      'total': double.parse(totalCtrl.text),
                      'status': existing['status'],
                    };
                  } else {
                    _purchases.insert(0, {
                      'po': 'PO-${DateTime.now().millisecondsSinceEpoch}',
                      'supplier': supplierCtrl.text,
                      'total': double.parse(totalCtrl.text),
                      'status': 'SELESAI (Stok Bertambah)',
                    });
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? 'Pembelian berhasil diperbarui!' : 'Pembelian berhasil dicatat!')),
                );
              }
            },
            child: Text(isEdit ? 'PERBARUI' : 'SIMPAN'),
          ),
        ],
      ),
    );
  }

  void _deletePurchase(int index) {
    final item = _purchases[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pembelian?'),
        content: Text('Apakah Anda yakin ingin menghapus "${item['po']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _purchases.removeAt(index));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembelian berhasil dihapus!')));
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  // ==================== RETURN METHODS ====================

  void _showReturnForm([Map<String, dynamic>? existing, int? index]) {
    final invCtrl = TextEditingController(text: existing?['inv'] ?? '');
    final reasonCtrl = TextEditingController(text: existing?['reason'] ?? '');
    final refundCtrl = TextEditingController(text: existing != null ? existing['refund'].toInt().toString() : '');
    final isEdit = existing != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Retur' : 'Tambah Retur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: invCtrl,
              decoration: const InputDecoration(labelText: 'No. Transaksi (INV)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Alasan Retur', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: refundCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal Refund', prefixText: 'Rp ', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          FilledButton(
            onPressed: () {
              if (invCtrl.text.isNotEmpty && refundCtrl.text.isNotEmpty) {
                setState(() {
                  if (isEdit && index != null) {
                    _returns[index] = {
                      'ret': existing['ret'],
                      'inv': invCtrl.text,
                      'reason': reasonCtrl.text.isNotEmpty ? reasonCtrl.text : 'Lainnya',
                      'refund': double.parse(refundCtrl.text),
                    };
                  } else {
                    _returns.insert(0, {
                      'ret': 'RET-${DateTime.now().millisecondsSinceEpoch}',
                      'inv': invCtrl.text,
                      'reason': reasonCtrl.text.isNotEmpty ? reasonCtrl.text : 'Lainnya',
                      'refund': double.parse(refundCtrl.text),
                    });
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEdit ? 'Retur berhasil diperbarui!' : 'Retur berhasil dicatat!')),
                );
              }
            },
            child: Text(isEdit ? 'PERBARUI' : 'SIMPAN'),
          ),
        ],
      ),
    );
  }

  void _deleteReturn(int index) {
    final item = _returns[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Retur?'),
        content: Text('Apakah Anda yakin ingin menghapus "${item['ret']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _returns.removeAt(index));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retur berhasil dihapus!')));
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================

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
              Tab(text: 'Retur (Return)'),
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
    if (_purchases.isEmpty) {
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
      itemCount: _purchases.length,
      itemBuilder: (context, index) {
        final p = _purchases[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.local_shipping, color: Colors.white),
            ),
            title: Text(p['po'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Supplier: ${p['supplier']}\nStatus: ${p['status']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rp ${_formatter.format(p['total'].toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') _showPurchaseForm(p, index);
                    if (value == 'delete') _deletePurchase(index);
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

  Widget _buildReturnList() {
    if (_returns.isEmpty) {
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
      itemCount: _returns.length,
      itemBuilder: (context, index) {
        final r = _returns[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.keyboard_return, color: Colors.white),
            ),
            title: Text(r['ret'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Transaksi: ${r['inv']}\nAlasan: ${r['reason']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rp ${_formatter.format(r['refund'].toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
                    const Text('Refund', style: TextStyle(fontSize: 11, color: Colors.red)),
                  ],
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') _showReturnForm(r, index);
                    if (value == 'delete') _deleteReturn(index);
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
}
