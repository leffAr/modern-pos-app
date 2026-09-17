import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';

class StockOpnameScreen extends StatefulWidget {
  const StockOpnameScreen({super.key});

  @override
  State<StockOpnameScreen> createState() => _StockOpnameScreenState();
}

class _StockOpnameScreenState extends State<StockOpnameScreen> {
  final _formatter = NumberFormat("#,###", "id_ID");

  void _showNewOpnameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _NewOpnameDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stok Opname (Audit)"),
      ),
      body: StreamBuilder<List<StockOpname>>(
        stream: (appDb.select(appDb.stockOpnames)..orderBy([(t) => drift.OrderingTerm.desc(t.date)])).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final opnames = snapshot.data ?? [];

          if (opnames.isEmpty) {
            return const Center(child: Text("Belum ada data stok opname."));
          }

          return ListView.builder(
            itemCount: opnames.length,
            itemBuilder: (context, i) {
              final op = opnames[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.fact_check)),
                title: Text("Opname: ${DateFormat('dd MMM yyyy HH:mm').format(op.date)}"),
                subtitle: Text("Catatan: ${op.status} | Status: ${op.status}"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => _EditOpnameDialog(opname: op),
                  );
                },
              );
            },
          );
        }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewOpnameDialog,
        icon: const Icon(Icons.add),
        label: const Text("Buat Opname"),
      ),
    );
  }
}

class _NewOpnameDialog extends StatefulWidget {
  const _NewOpnameDialog();

  @override
  State<_NewOpnameDialog> createState() => _NewOpnameDialogState();
}

class _NewOpnameDialogState extends State<_NewOpnameDialog> {
  final _notesCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;

  Future<void> _addProductToOpname(Product product) async {
    final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(product.id))).getSingleOrNull();
    int sysStock = inv?.stock ?? 0;
    
    // Check if already in list
    if (_items.any((item) => item["productId"] == product.id)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Produk sudah ada di daftar opname.")));
       return;
    }

    setState(() {
      _items.add({
        "productId": product.id,
        "productName": product.name,
        "systemStock": sysStock,
        "actualStock": sysStock,
        "ctrl": TextEditingController(text: sysStock.toString())
      });
    });
  }

  void _saveOpname() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tambahkan minimal 1 produk")));
      return;
    }

    setState(() => _isLoading = true);
    
    final opnameId = "OPN-${DateTime.now().microsecondsSinceEpoch}";
    
    try {
      await appDb.batch((batch) {
        batch.insert(
          appDb.stockOpnames,
          StockOpnamesCompanion.insert(
            id: opnameId,
            branchId: "CABANG-1",
            userId: "U-1", // Using U-1 as default for Admin
            date: drift.Value(DateTime.now()),
            status: const drift.Value("COMPLETED"),
          )
        );

        for (var item in _items) {
          int actual = int.tryParse(item["ctrl"].text) ?? 0;
          int variance = actual - (item["systemStock"] as int);

          batch.insert(
            appDb.stockOpnameItems,
            StockOpnameItemsCompanion.insert(
              id: "OPNI-${DateTime.now().microsecondsSinceEpoch}-${item['productId']}",
              opnameId: opnameId,
              productId: item["productId"],
              systemStock: item["systemStock"],
              actualStock: actual,
              variance: variance,
            )
          );

          // Update inventory
          batch.update(
            appDb.inventory,
            InventoryCompanion(stock: drift.Value(actual)),
            where: (t) => t.productId.equals(item["productId"])
          );
        }
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stok Opname berhasil disimpan!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menyimpan opname: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Buat Stok Opname"),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: "Catatan (Opsional)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text("Cari Produk"),
              onPressed: () {
                 showDialog(
                   context: context, 
                   builder: (ctx) => _ProductSelectionDialog(
                     onSelected: (p) => _addProductToOpname(p),
                   ),
                 );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  return ListTile(
                    title: Text(item["productName"]),
                    subtitle: Text("Stok Sistem: ${item["systemStock"]}"),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        controller: item["ctrl"],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Stok Aktual", isDense: true),
                      ),
                    ),
                  );
                }
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        FilledButton(onPressed: _isLoading ? null : _saveOpname, child: _isLoading ? const CircularProgressIndicator() : const Text("Simpan & Update Stok")),
      ],
    );
  }
}
class _ProductSelectionDialog extends StatefulWidget {
  final Function(Product) onSelected;
  const _ProductSelectionDialog({required this.onSelected});

  @override
  State<_ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  final _searchCtrl = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final prods = await (appDb.select(appDb.products)..where((p) => p.isActive.equals(true))).get();
    if (mounted) {
      setState(() {
        _allProducts = prods;
        _filteredProducts = prods;
      });
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        final q = query.toLowerCase();
        _filteredProducts = _allProducts.where((p) => 
          p.name.toLowerCase().contains(q) || 
          (p.sku != null && p.sku!.toLowerCase().contains(q)) ||
          (p.barcode != null && p.barcode!.toLowerCase().contains(q))
        ).toList();
      }
    });
  }

  Widget _buildImage(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey.shade200,
        child: const Icon(Icons.inventory, color: Colors.grey),
      );
    }
    try {
      final bytes = base64Decode(base64String);
      return Image.memory(bytes, width: 50, height: 50, fit: BoxFit.cover);
    } catch (e) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pilih Produk"),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: "Cari nama, SKU, barcode...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredProducts.isEmpty 
                ? const Center(child: Text("Produk tidak ditemukan."))
                : ListView.separated(
                    itemCount: _filteredProducts.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = _filteredProducts[i];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: _buildImage(p.imageBase64),
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("SKU: ${p.sku ?? '-'} | Barcode: ${p.barcode ?? '-'}"),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelected(p);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
      ],
    );
  }
}

class _EditOpnameDialog extends StatefulWidget {
  final StockOpname opname;
  const _EditOpnameDialog({required this.opname});

  @override
  State<_EditOpnameDialog> createState() => _EditOpnameDialogState();
}

class _EditOpnameDialogState extends State<_EditOpnameDialog> {
  final _notesCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  List<StockOpnameItem> _originalItems = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadOpnameDetails();
  }

  Future<void> _loadOpnameDetails() async {
    final items = await (appDb.select(appDb.stockOpnameItems)..where((t) => t.opnameId.equals(widget.opname.id))).get();
    
    _originalItems = items;
    
    for (var item in items) {
      final product = await (appDb.select(appDb.products)..where((p) => p.id.equals(item.productId))).getSingleOrNull();
      _items.add({
        "productId": item.productId,
        "productName": product?.name ?? 'Produk Dihapus',
        "systemStock": item.systemStock,
        "actualStock": item.actualStock,
        "ctrl": TextEditingController(text: item.actualStock.toString())
      });
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addProductToOpname(Product product) async {
    final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(product.id))).getSingleOrNull();
    int sysStock = inv?.stock ?? 0;
    
    if (_items.any((item) => item["productId"] == product.id)) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Produk sudah ada di daftar opname.")));
       return;
    }

    setState(() {
      _items.add({
        "productId": product.id,
        "productName": product.name,
        "systemStock": sysStock,
        "actualStock": sysStock,
        "ctrl": TextEditingController(text: sysStock.toString())
      });
    });
  }

  void _saveOpname() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tambahkan minimal 1 produk")));
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      await appDb.transaction(() async {
        // 1. Revert old items
        for (var oldItem in _originalItems) {
            final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(oldItem.productId))).getSingleOrNull();
            if (inv != null) {
                await (appDb.update(appDb.inventory)..where((t) => t.id.equals(inv.id))).write(
                    InventoryCompanion(stock: drift.Value(inv.stock - oldItem.variance))
                );
            }
        }
        // 2. Delete old items
        await (appDb.delete(appDb.stockOpnameItems)..where((t) => t.opnameId.equals(widget.opname.id))).go();
        
        // 3. Insert new items and apply
        for (var item in _items) {
           int actual = int.tryParse(item["ctrl"].text) ?? 0;
           int systemStock = item["systemStock"];
           int variance = actual - systemStock;

           await appDb.into(appDb.stockOpnameItems).insert(
              StockOpnameItemsCompanion.insert(
                id: "OPNI-${DateTime.now().microsecondsSinceEpoch}-${item['productId']}",
                opnameId: widget.opname.id,
                productId: item["productId"],
                systemStock: systemStock,
                actualStock: actual,
                variance: variance,
              )
           );

           final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(item["productId"]))).getSingleOrNull();
           if (inv != null) {
               await (appDb.update(appDb.inventory)..where((t) => t.id.equals(inv.id))).write(
                   InventoryCompanion(stock: drift.Value(inv.stock + variance))
               );
           }
        }
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stok Opname berhasil diperbarui!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memperbarui opname: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _deleteOpname() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Opname?"),
        content: const Text("Apakah Anda yakin ingin menghapus opname ini? Stok akan dikembalikan ke sebelum opname dilakukan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Hapus")
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await appDb.transaction(() async {
        // Revert old items
        for (var oldItem in _originalItems) {
            final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(oldItem.productId))).getSingleOrNull();
            if (inv != null) {
                await (appDb.update(appDb.inventory)..where((t) => t.id.equals(inv.id))).write(
                    InventoryCompanion(stock: drift.Value(inv.stock - oldItem.variance))
                );
            }
        }
        // Delete items
        await (appDb.delete(appDb.stockOpnameItems)..where((t) => t.opnameId.equals(widget.opname.id))).go();
        // Delete opname
        await (appDb.delete(appDb.stockOpnames)..where((t) => t.id.equals(widget.opname.id))).go();
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stok Opname berhasil dihapus!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghapus opname: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      );
    }

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Edit Stok Opname"),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isSaving ? null : _deleteOpname,
            tooltip: "Hapus Opname",
          )
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text("Tambah Produk ke Opname"),
              onPressed: () {
                 showDialog(
                   context: context, 
                   builder: (ctx) => _ProductSelectionDialog(
                     onSelected: (p) => _addProductToOpname(p),
                   ),
                 );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final item = _items[i];
                  return ListTile(
                    title: Text(item["productName"]),
                    subtitle: Text("Stok Sistem (saat opname): ${item["systemStock"]}"),
                    trailing: SizedBox(
                      width: 150,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: item["ctrl"],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: "Stok Aktual", isDense: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _items.removeAt(i);
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  );
                }
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
        FilledButton(
          onPressed: _isSaving ? null : _saveOpname, 
          child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Simpan Perubahan")
        ),
      ],
    );
  }
}
