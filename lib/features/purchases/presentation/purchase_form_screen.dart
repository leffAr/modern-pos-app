import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import 'package:drift/drift.dart' as drift;

class PurchaseFormScreen extends StatefulWidget {
  final Purchase? existingPurchase;

  const PurchaseFormScreen({super.key, this.existingPurchase});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _supplierCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.existingPurchase != null) {
      _refCtrl.text = widget.existingPurchase!.referenceNumber;
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);
    try {
      // Load Supplier Name
      final supplier = await (appDb.select(appDb.suppliers)
        ..where((t) => t.id.equals(widget.existingPurchase!.supplierId))).getSingleOrNull();
      if (supplier != null) _supplierCtrl.text = supplier.name;

      // Load Items
      final purchaseItems = await (appDb.select(appDb.purchaseItems)
        ..where((t) => t.purchaseId.equals(widget.existingPurchase!.id))).get();
      
      for (var pi in purchaseItems) {
        final product = await (appDb.select(appDb.products)
          ..where((t) => t.id.equals(pi.productId))).getSingleOrNull();
        if (product != null) {
          _items.add({
            'productId': product.id,
            'name': product.name,
            'qtyCtrl': TextEditingController(text: pi.quantity.toString()),
            'costCtrl': TextEditingController(text: pi.cost.toInt().toString()),
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addProduct(Product product) {
    if (_items.any((i) => i['productId'] == product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk sudah ada di daftar.')));
      return;
    }
    setState(() {
      _items.add({
        'productId': product.id,
        'name': product.name,
        'qtyCtrl': TextEditingController(text: '1'),
        'costCtrl': TextEditingController(text: product.purchasePrice.toInt().toString()), // default to selling price as a hint
      });
    });
  }

  Future<void> _savePurchase() async {
    if (_supplierCtrl.text.isEmpty || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier dan minimal 1 produk harus diisi.')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await appDb.transaction(() async {
        // 1. Get or Create Supplier
        final supplierName = _supplierCtrl.text.trim();
        var supplier = await (appDb.select(appDb.suppliers)..where((t) => t.name.equals(supplierName))).getSingleOrNull();
        if (supplier == null) {
          final newSuppId = 'SUP-${DateTime.now().microsecondsSinceEpoch}';
          await appDb.into(appDb.suppliers).insert(
            SuppliersCompanion.insert(
              id: newSuppId,
              businessId: 'BIZ-1', // Default business ID
              name: supplierName,
            )
          );
          supplier = await (appDb.select(appDb.suppliers)..where((t) => t.id.equals(newSuppId))).getSingle();
        }

        // 2. Calculate Total
        double total = 0;
        for (var item in _items) {
          int qty = int.tryParse(item['qtyCtrl'].text) ?? 1;
          double cost = double.tryParse(item['costCtrl'].text) ?? 0;
          total += (qty * cost);
        }

        final purchaseId = widget.existingPurchase?.id ?? 'PO-${DateTime.now().microsecondsSinceEpoch}';
        
        // If editing, we should revert old stock if it was COMPLETED
        if (widget.existingPurchase != null) {
          // Find old items
          final oldItems = await (appDb.select(appDb.purchaseItems)..where((t) => t.purchaseId.equals(purchaseId))).get();
          for (var oldItem in oldItems) {
             final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(oldItem.productId))).getSingleOrNull();
             if (inv != null) {
                await (appDb.update(appDb.inventory)..where((t) => t.id.equals(inv.id))).write(
                  InventoryCompanion(stock: drift.Value(inv.stock - oldItem.quantity))
                );
             }
          }
          await (appDb.delete(appDb.purchaseItems)..where((t) => t.purchaseId.equals(purchaseId))).go();
        }

        // 3. Save Purchase
        await appDb.into(appDb.purchases).insertOnConflictUpdate(
          PurchasesCompanion.insert(
            id: purchaseId,
            branchId: 'CABANG-1',
            supplierId: supplier.id,
            referenceNumber: _refCtrl.text.isEmpty ? purchaseId : _refCtrl.text,
            total: drift.Value(total),
            status: const drift.Value('COMPLETED'),
            date: drift.Value(widget.existingPurchase?.date ?? DateTime.now()),
          )
        );

        // 4. Save Items & Update Stock
        for (var item in _items) {
          int qty = int.tryParse(item['qtyCtrl'].text) ?? 1;
          double cost = double.tryParse(item['costCtrl'].text) ?? 0;

          await appDb.into(appDb.purchaseItems).insert(
            PurchaseItemsCompanion.insert(
              id: 'PI-${DateTime.now().microsecondsSinceEpoch}-${item['productId']}',
              purchaseId: purchaseId,
              productId: item['productId'],
              quantity: drift.Value(qty),
              cost: drift.Value(cost),
            )
          );

          // Update Stock
          final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(item['productId']))).getSingleOrNull();
          if (inv != null) {
            await (appDb.update(appDb.inventory)..where((t) => t.id.equals(inv.id))).write(
              InventoryCompanion(stock: drift.Value(inv.stock + qty))
            );
          }
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembelian berhasil disimpan & stok diperbarui!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProductSearch() {
    showDialog(
      context: context,
      builder: (context) => _ProductSearchDialog(
        onSelected: (p) {
          Navigator.pop(context);
          _addProduct(p);
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingPurchase != null ? 'Edit Pembelian' : 'Pembelian Baru'),
        actions: [
          if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white)))
          else IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Simpan Pembelian',
            onPressed: _savePurchase,
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isMobile ? 1 : 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Informasi Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _supplierCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Supplier *', prefixIcon: Icon(Icons.business), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _refCtrl,
                          decoration: const InputDecoration(labelText: 'Nomor Referensi / Nota (Opsional)', prefixIcon: Icon(Icons.receipt), border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daftar Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Produk'),
                      onPressed: _showProductSearch,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: const Text('Belum ada produk. Tekan tombol Tambah Produk.', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: isMobile 
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _items.removeAt(index))),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: item['qtyCtrl'],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                                        onChanged: (_) => setState((){}),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: item['costCtrl'],
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Harga Beli Satuan', prefixText: 'Rp ', isDense: true),
                                        onChanged: (_) => setState((){}),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(flex: 3, child: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: item['qtyCtrl'],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                                    onChanged: (_) => setState((){}),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: item['costCtrl'],
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Harga Satuan', prefixText: 'Rp ', border: OutlineInputBorder(), isDense: true),
                                    onChanged: (_) => setState((){}),
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _items.removeAt(index))),
                              ],
                            )
                      ),
                    );
                  })
              ],
            ),
          ),
          if (!isMobile)
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.all(24),
                child: _buildSummary(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isMobile 
        ? Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildSummary(),
          )
        : null,
    );
  }

  Widget _buildSummary() {
    double total = 0;
    for (var item in _items) {
      int qty = int.tryParse(item['qtyCtrl'].text) ?? 0;
      double cost = double.tryParse(item['costCtrl'].text) ?? 0;
      total += (qty * cost);
    }
    
    final formatter = NumberFormat('#,###', 'id_ID');
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ringkasan Pembelian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Item:'),
            Text('${_items.length} Macam', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL BIAYA:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Rp ${formatter.format(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blue)),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _isLoading ? null : _savePurchase,
          child: const Text('Simpan Pembelian', style: TextStyle(fontSize: 16)),
        )
      ],
    );
  }
}

class _ProductSearchDialog extends StatefulWidget {
  final Function(Product) onSelected;
  const _ProductSearchDialog({required this.onSelected});
  @override
  State<_ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<_ProductSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await (appDb.select(appDb.products)).get();
    setState(() {
      _allProducts = products;
      _filteredProducts = products;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Produk'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(labelText: 'Cari Produk', prefixIcon: Icon(Icons.search)),
              onChanged: (val) {
                setState(() {
                  _filteredProducts = _allProducts.where((p) => p.name.toLowerCase().contains(val.toLowerCase())).toList();
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, i) {
                  final p = _filteredProducts[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text('Rp ${NumberFormat('#,###', 'id_ID').format(p.purchasePrice)}'),
                    onTap: () => widget.onSelected(p),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
