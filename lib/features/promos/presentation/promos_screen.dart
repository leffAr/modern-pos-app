import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';

class PromosScreen extends StatefulWidget {
  const PromosScreen({super.key});

  @override
  State<PromosScreen> createState() => _PromosScreenState();
}

class _PromosScreenState extends State<PromosScreen> {
  late Stream<List<Promo>> _promosStream;
  final _formatter = NumberFormat('#,###', 'id_ID');

  @override
  void initState() {
    super.initState();
    _promosStream = appDb.select(appDb.promos).watch();
  }

  void _showAddEditDialog([Promo? promo]) {
    final isEditing = promo != null;
    final nameController = TextEditingController(text: promo?.name ?? '');
    final valueController = TextEditingController(text: promo != null ? promo.value.toInt().toString() : '');
    String type = promo?.type ?? 'percentage';
    bool isActive = promo?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Diskon / Promo' : 'Tambah Promo Baru'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama Promo (Misal: Diskon Merdeka)'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Jenis Diskon'),
                      items: const [
                        DropdownMenuItem(value: 'percentage', child: Text('Persentase (%)')),
                        DropdownMenuItem(value: 'fixed', child: Text('Potongan Rupiah (Rp)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => type = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nilai Diskon',
                        prefixText: type == 'fixed' ? 'Rp ' : null,
                        suffixText: type == 'percentage' ? '%' : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Status Aktif'),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty || valueController.text.trim().isEmpty) return;
                    
                    final value = double.tryParse(valueController.text.trim()) ?? 0.0;

                    final companion = PromosCompanion(
                      id: isEditing ? drift.Value(promo.id) : drift.Value('PRM-${DateTime.now().millisecondsSinceEpoch}'),
                      name: drift.Value(nameController.text.trim()),
                      type: drift.Value(type),
                      value: drift.Value(value),
                      isActive: drift.Value(isActive),
                    );

                    if (isEditing) {
                      await (appDb.update(appDb.promos)..where((t) => t.id.equals(promo.id))).write(companion);
                    } else {
                      await appDb.into(appDb.promos).insert(companion);
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

  void _deletePromo(Promo promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Promo?'),
        content: Text('Anda yakin ingin menghapus promo "${promo.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Hapus')
          ),
        ],
      ),
    );

    if (confirm == true) {
      await (appDb.delete(appDb.promos)..where((t) => t.id.equals(promo.id))).go();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Diskon & Promo'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Promo'),
      ),
      body: StreamBuilder<List<Promo>>(
        stream: _promosStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final promos = snapshot.data!;
          if (promos.isEmpty) {
            return const Center(child: Text('Belum ada promo.'));
          }

          return ListView.builder(
            itemCount: promos.length,
            itemBuilder: (context, index) {
              final promo = promos[index];
              final valueText = promo.type == 'percentage' 
                ? '${promo.value.toInt()}%' 
                : 'Rp ${_formatter.format(promo.value.toInt())}';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: promo.isActive ? Colors.green.shade100 : Colors.grey.shade300,
                    child: Icon(Icons.local_offer, color: promo.isActive ? Colors.green : Colors.grey),
                  ),
                  title: Text(promo.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Potongan: $valueText ${!promo.isActive ? ' (Nonaktif)' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _showAddEditDialog(promo),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePromo(promo),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
