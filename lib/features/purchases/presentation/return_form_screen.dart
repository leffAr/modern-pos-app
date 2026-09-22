import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import 'package:drift/drift.dart' as drift;

class ReturnFormScreen extends StatefulWidget {
  final Return? existingReturn;

  const ReturnFormScreen({super.key, this.existingReturn});

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  final _invCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  
  bool _isLoading = false;
  Transaction? _foundTransaction;
  List<Map<String, dynamic>> _items = [];
  
  @override
  void initState() {
    super.initState();
    if (widget.existingReturn != null) {
      _invCtrl.text = widget.existingReturn!.transactionId;
      _reasonCtrl.text = widget.existingReturn!.reason;
      _searchTransaction();
    }
  }

  Future<void> _searchTransaction() async {
    final invId = _invCtrl.text.trim();
    if (invId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundTransaction = null;
      _items.clear();
    });

    try {
      // Cari transaksi yang ID atau ReceiptNumber-nya mengandung kata kunci yang diketik
      final matchingTxs = await (appDb.select(appDb.transactions)
        ..where((t) => t.id.like('%$invId%') | t.receiptNumber.like('%$invId%'))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
      ).get();
      
      final tx = matchingTxs.isNotEmpty ? matchingTxs.first : null;
      
      if (tx == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi tidak ditemukan!')));
        return;
      }

      _foundTransaction = tx;

      final txItems = await (appDb.select(appDb.transactionItems)
        ..where((t) => t.transactionId.equals(tx.id))).get();
      
      for (var ti in txItems) {
        final product = await (appDb.select(appDb.products)
          ..where((t) => t.id.equals(ti.productId))).getSingleOrNull();
        
        if (product != null) {
          _items.add({
            'productId': product.id,
            'name': product.name,
            'maxQty': ti.quantity,
            'qtyCtrl': TextEditingController(text: widget.existingReturn != null ? '0' : ti.quantity.toString()), // If editing, default to 0 so they don't double return. Wait, since we don't track ReturnItems, editing a return is complex. Let's just default to maxQty.
            'price': ti.price,
            'isReturned': true, // Checkbox to select if this item is returned
          });
        }
      }
      
      // If editing, we just set total refund amount, but since we don't have ReturnItems, we can't accurately prepopulate checks. We'll just load the items.
      
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveReturn() async {
    if (_foundTransaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan cari transaksi terlebih dahulu.')));
      return;
    }

    double totalRefund = 0;
    bool hasSelectedItems = false;
    for (var item in _items) {
      if (item['isReturned'] == true) {
        int qty = int.tryParse(item['qtyCtrl'].text) ?? 0;
        if (qty > 0) {
          totalRefund += (qty * (item['price'] as double));
          hasSelectedItems = true;
        }
      }
    }

    if (!hasSelectedItems && widget.existingReturn == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal 1 item untuk diretur.')));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await appDb.transaction(() async {
        final retId = widget.existingReturn?.id ?? 'RET-${DateTime.now().microsecondsSinceEpoch}';

        // 1. Save Return Record
        await appDb.into(appDb.returns).insertOnConflictUpdate(
          ReturnsCompanion.insert(
            id: retId,
            transactionId: _foundTransaction!.id,
            reason: _reasonCtrl.text.isNotEmpty ? _reasonCtrl.text : 'Lainnya',
            amountRefunded: drift.Value(totalRefund > 0 ? totalRefund : (widget.existingReturn?.amountRefunded ?? 0)),
            date: drift.Value(widget.existingReturn?.date ?? DateTime.now()),
          )
        );

        // 2. Update Stock if this is a NEW return (don't double count if editing)
        if (widget.existingReturn == null) {
          for (var item in _items) {
            if (item['isReturned'] == true) {
              int qty = int.tryParse(item['qtyCtrl'].text) ?? 0;
              if (qty > 0) {
                final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(item['productId']))).getSingleOrNull();
                if (inv != null) {
                  // Return item to store => INCREASE STOCK
                  await (appDb.update(appDb.inventory)..where((t) => t.id.equals(inv.id))).write(
                    InventoryCompanion(stock: drift.Value(inv.stock + qty))
                  );
                }
              }
            }
          }
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retur berhasil disimpan & stok dikembalikan!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final formatter = NumberFormat('#,###', 'id_ID');

    double currentTotalRefund = 0;
    for (var item in _items) {
      if (item['isReturned'] == true) {
        int qty = int.tryParse(item['qtyCtrl'].text) ?? 0;
        currentTotalRefund += (qty * (item['price'] as double));
      }
    }
    
    // If editing and no items are loaded properly or checked, use the existing refund
    if (widget.existingReturn != null && currentTotalRefund == 0) {
      currentTotalRefund = widget.existingReturn!.amountRefunded;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingReturn != null ? 'Edit Retur' : 'Retur Pelanggan (Barang Kembali)'),
        actions: [
          if (_isLoading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white)))
          else IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Simpan Retur',
            onPressed: _saveReturn,
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
                        const Text('Cari Transaksi Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _invCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nomor Transaksi (INV-...)', 
                                  prefixIcon: Icon(Icons.receipt_long), 
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _searchTransaction,
                              icon: const Icon(Icons.search),
                              label: const Text('Cari'),
                            ),
                          ],
                        ),
                        if (_foundTransaction != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Transaksi Ditemukan!\nTotal Belanja: Rp ${formatter.format(_foundTransaction!.grandTotal)}\nStatus: ${_foundTransaction!.status}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reasonCtrl,
                          decoration: const InputDecoration(labelText: 'Alasan Retur (Misal: Barang Cacat, Salah Ukuran)', prefixIcon: Icon(Icons.info_outline), border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_foundTransaction != null) ...[
                  const SizedBox(height: 16),
                  const Text('Daftar Produk dalam Transaksi (Pilih yang diretur):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Text('Tidak ada produk ditemukan di transaksi ini.')
                  else
                    ..._items.map((item) {
                      final maxQty = item['maxQty'] as int;
                      return Card(
                        child: CheckboxListTile(
                          value: item['isReturned'] as bool,
                          onChanged: widget.existingReturn != null ? null : (val) {
                            setState(() {
                              item['isReturned'] = val;
                            });
                          },
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Harga: Rp ${formatter.format(item['price'])} | Dibeli: $maxQty'),
                              if (item['isReturned'] == true && widget.existingReturn == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      const Text('Qty Diretur: '),
                                      SizedBox(
                                        width: 80,
                                        child: TextField(
                                          controller: item['qtyCtrl'],
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                          onChanged: (val) {
                                            int? q = int.tryParse(val);
                                            if (q != null && q > maxQty) {
                                              item['qtyCtrl'].text = maxQty.toString();
                                            }
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
          if (!isMobile)
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.all(24),
                child: _buildSummary(currentTotalRefund, formatter),
              ),
            ),
        ],
      ),
      bottomNavigationBar: isMobile 
        ? Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: _buildSummary(currentTotalRefund, formatter),
          )
        : null,
    );
  }

  Widget _buildSummary(double totalRefund, NumberFormat formatter) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Ringkasan Retur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 16),
        const Text('Jika Anda mencatat retur ini, stok untuk barang yang dipilih akan dikembalikan otomatis ke gudang.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL REFUND:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            Text('Rp ${formatter.format(totalRefund)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.red)),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _isLoading ? null : _saveReturn,
          child: const Text('Simpan Retur', style: TextStyle(fontSize: 16)),
        )
      ],
    );
  }
}
