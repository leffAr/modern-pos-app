import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/web_image_picker.dart';

class ProductsScreen extends StatefulWidget {
  final bool isReadOnly;
  const ProductsScreen({super.key, this.isReadOnly = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Stream<List<Product>> _productsStream;
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  void _updateStream() {
    if (_selectedCategoryId == null) {
      _productsStream = appDb.select(appDb.products).watch();
    } else {
      _productsStream = (appDb.select(appDb.products)..where((p) => p.categoryId.equals(_selectedCategoryId!))).watch();
    }
  }

  Stream<Map<String, int>> _categoryStatsStream() {
    String stockFilter = _selectedCategoryId == null ? '' : "WHERE product_id IN (SELECT id FROM products WHERE category_id = '$_selectedCategoryId')";
    String soldFilter = _selectedCategoryId == null ? '' : "WHERE product_id IN (SELECT id FROM products WHERE category_id = '$_selectedCategoryId')";
    
    return appDb.customSelect('''
      SELECT 
        (SELECT SUM(stock) FROM inventory $stockFilter) as total_stock,
        (SELECT SUM(quantity) FROM transaction_items $soldFilter) as total_sold
    ''', readsFrom: {appDb.inventory, appDb.transactionItems, appDb.products}).watchSingle().map((row) {
      return {
        'stock': (row.data['total_stock'] as num?)?.toInt() ?? 0,
        'sold': (row.data['total_sold'] as num?)?.toInt() ?? 0,
      };
    });
  }

  final _formatter = NumberFormat('#,###', 'id_ID');


  Future<void> _showAddEditDialog([Product? product]) async {
    final nameCtrl = TextEditingController(text: product?.name);
    final skuCtrl = TextEditingController(text: product?.sku);
    final barcodeCtrl = TextEditingController(text: product?.barcode);
    final descCtrl = TextEditingController(text: product?.description);
    final purchasePriceCtrl = TextEditingController(
      text: product != null ? product.purchasePrice.toInt().toString() : "",
    );
    final sellingPriceCtrl = TextEditingController(
      text: product != null ? product.sellingPrice.toInt().toString() : "",
    );
    final wholesalePriceCtrl = TextEditingController(
      text: product != null && product.wholesalePrice != null ? product.wholesalePrice!.toInt().toString() : "",
    );
    final wholesaleMinQtyCtrl = TextEditingController(
      text: product != null && product.wholesaleMinQty != null ? product.wholesaleMinQty!.toString() : "",
    );
    final unitCtrl = TextEditingController(text: product?.unit ?? "pcs");
    bool isActive = product?.isActive ?? true;
    String? selectedCategoryId = product?.categoryId;
    String? currentImageBase64 = product?.imageBase64;
    
    final stockCtrl = TextEditingController(text: "0");
    final minStockCtrl = TextEditingController(text: "0");

    List<Map<String, dynamic>> variants = [];

    if (product != null) {
      // Ambil stok dari inventory
      final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(product.id))).getSingleOrNull();
      if (inv != null) {
          stockCtrl.text = inv.stock.toString();
          minStockCtrl.text = inv.minimumStock.toString();
      }
      
      // Ambil variants
      final existingVariants = await (appDb.select(appDb.productVariants)..where((t) => t.productId.equals(product.id))).get();
      variants = existingVariants.map((v) => {
        "id": v.id,
        "name": TextEditingController(text: v.name),
        "purchasePrice": TextEditingController(text: v.purchasePrice.toInt().toString()),
        "price": TextEditingController(text: v.price.toInt().toString())
      }).toList();
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(product == null ? "Tambah Produk" : "Edit Produk"),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Gambar Produk
                    GestureDetector(
                      onTap: () async {
                        try {
                          final base64 = await WebImagePicker.pickImageAsBase64();
                          if (base64 != null) {
                            setDialogState(() {
                              currentImageBase64 = base64;
                            });
                          }
                        } catch (e) {
                          debugPrint("Pick error: `$e");
                        }
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                        ),
                        child: currentImageBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  base64Decode(currentImageBase64!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.grey.shade500, size: 40),
                                  const SizedBox(height: 8),
                                  Text("Pilih Foto", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                      ),
                    ),
                    if (currentImageBase64 != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setDialogState(() => currentImageBase64 = null),
                        child: const Text("Hapus Foto", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Nama Produk
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Nama Produk *",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Kategori Dropdown
                    StreamBuilder<List<Category>>(
                      stream: appDb.select(appDb.categories).watch(),
                      builder: (context, snap) {
                        final categories = snap.data ?? [];
                        return DropdownButtonFormField<String?>(
                          value: selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: "Kategori",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text("Tanpa Kategori")),
                            ...categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // SKU & Barcode
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: skuCtrl,
                            decoration: const InputDecoration(
                              labelText: "SKU",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: barcodeCtrl,
                            decoration: const InputDecoration(
                              labelText: "Barcode",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.barcode_reader),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Deskripsi
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Deskripsi (Opsional)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Harga Beli & Harga Jual
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: purchasePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Harga Beli",
                              prefixText: "Rp ",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: sellingPriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Harga Jual *",
                              prefixText: "Rp ",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Harga Grosir
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: wholesalePriceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Harga Grosir (Opsional)",
                              prefixText: "Rp ",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: wholesaleMinQtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Min. Beli Grosir",
                              suffixText: "pcs",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 14),
                    // Variasi Produk (M, L, etc)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text("Varian Produk (Ukuran/Jenis)", style: TextStyle(fontWeight: FontWeight.bold)),
                               TextButton.icon(
                                 onPressed: () {
                                   setDialogState(() {
                                     variants.add({
                                       "id": null,
                                       "name": TextEditingController(),
                                       "purchasePrice": TextEditingController(),
                                       "price": TextEditingController()
                                     });
                                   });
                                 },
                                 icon: const Icon(Icons.add, size: 16),
                                 label: const Text("Tambah Varian"),
                               )
                             ]
                           ),
                           if (variants.isEmpty)
                             Text("Kosongkan jika produk ini tidak memiliki varian.", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                           ...variants.asMap().entries.map((entry) {
                             int idx = entry.key;
                             var v = entry.value;
                             return Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Column(
                                 children: [
                                   TextField(
                                     controller: v["name"],
                                     decoration: const InputDecoration(labelText: "Nama Varian (mis. Size L)", border: OutlineInputBorder(), isDense: true),
                                   ),
                                   const SizedBox(height: 8),
                                   Row(
                                     children: [
                                       Expanded(
                                         child: TextField(
                                           controller: v["purchasePrice"],
                                           keyboardType: TextInputType.number,
                                           decoration: const InputDecoration(labelText: "Harga Beli", prefixText: "Rp ", border: OutlineInputBorder(), isDense: true),
                                         )
                                       ),
                                       const SizedBox(width: 8),
                                       Expanded(
                                         child: TextField(
                                           controller: v["price"],
                                           keyboardType: TextInputType.number,
                                           decoration: const InputDecoration(labelText: "Harga Jual", prefixText: "Rp ", border: OutlineInputBorder(), isDense: true),
                                         )
                                       ),
                                       IconButton(
                                         icon: const Icon(Icons.delete, color: Colors.red),
                                         onPressed: () {
                                           setDialogState(() {
                                             variants.removeAt(idx);
                                           });
                                         }
                                       )
                                     ]
                                   ),
                                   const Divider(),
                                 ]
                               )
                             );
                           }).toList(),
                        ]
                      )
                    ),
                    
                    const SizedBox(height: 14),

                    // Satuan
                    TextField(
                      controller: unitCtrl,
                      decoration: const InputDecoration(
                        labelText: "Satuan (Opsional)",
                        hintText: "pcs, porsi, cup, dll",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Stok Awal & Minimal
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Stok Awal",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minStockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Minimal Stok",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Switch Aktif
                    SwitchListTile(
                      title: const Text("Produk Aktif"),
                      subtitle: const Text("Tampilkan produk ini di layar kasir"),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isReadOnly ? "TUTUP" : "BATAL"),
                ),
                if (!widget.isReadOnly)
                  FilledButton(
                    onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Nama produk wajib diisi!")),
                    );
                    return;
                  }

                  final buyPrice = double.tryParse(purchasePriceCtrl.text.replaceAll(".", "")) ?? 0;
                  final sellPrice = double.tryParse(sellingPriceCtrl.text.replaceAll(".", "")) ?? 0;
                  final wPrice = double.tryParse(wholesalePriceCtrl.text.replaceAll(".", ""));
                  final wMinQty = int.tryParse(wholesaleMinQtyCtrl.text);
                  final initialStock = int.tryParse(stockCtrl.text) ?? 0;
                  final minStock = int.tryParse(minStockCtrl.text) ?? 0;

                  // 1. Simpan Data Produk Utama
                  final biz = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull();
                  final bizId = biz?.id ?? "BIZ-1";

                  final productId = product?.id ?? ("PROD-" + DateTime.now().millisecondsSinceEpoch.toString());

                  if (product == null) {
                    await appDb.into(appDb.products).insert(
                          ProductsCompanion.insert(
                            id: productId,
                            businessId: bizId,
                            categoryId: drift.Value(selectedCategoryId),
                            name: name,
                            sku: drift.Value(skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim()),
                            barcode: drift.Value(barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim()),
                            description: drift.Value(descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim()),
                            imageBase64: drift.Value(currentImageBase64),
                            purchasePrice: drift.Value(buyPrice),
                            sellingPrice: drift.Value(sellPrice),
                            wholesalePrice: drift.Value(wPrice),
                            wholesaleMinQty: drift.Value(wMinQty),
                            unit: drift.Value(unitCtrl.text.trim().isEmpty ? "pcs" : unitCtrl.text.trim()),
                            isActive: drift.Value(isActive),
                          ),
                        );
                    // Insert Inventory awal
                    await appDb.into(appDb.inventory).insert(
                          InventoryCompanion.insert(
                            id: "INV-" + DateTime.now().millisecondsSinceEpoch.toString(),
                            productId: productId,
                            branchId: "BRANCH-1", // default
                            stock: drift.Value(initialStock),
                            minimumStock: drift.Value(minStock),
                          ),
                        );
                  } else {
                    await (appDb.update(appDb.products)..where((t) => t.id.equals(product.id))).write(
                          ProductsCompanion(
                            categoryId: drift.Value(selectedCategoryId),
                            name: drift.Value(name),
                            sku: drift.Value(skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim()),
                            barcode: drift.Value(barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim()),
                            description: drift.Value(descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim()),
                            imageBase64: drift.Value(currentImageBase64),
                            purchasePrice: drift.Value(buyPrice),
                            sellingPrice: drift.Value(sellPrice),
                            wholesalePrice: drift.Value(wPrice),
                            wholesaleMinQty: drift.Value(wMinQty),
                            unit: drift.Value(unitCtrl.text.trim().isEmpty ? "pcs" : unitCtrl.text.trim()),
                            isActive: drift.Value(isActive),
                          ),
                        );

                    // Update Inventory
                    await (appDb.update(appDb.inventory)..where((t) => t.productId.equals(product.id))).write(
                          InventoryCompanion(
                            stock: drift.Value(initialStock),
                            minimumStock: drift.Value(minStock),
                          ),
                        );
                  }
                  
                  // 2. Simpan Varian
                  // Hapus varian lama
                  await (appDb.delete(appDb.productVariants)..where((t) => t.productId.equals(productId))).go();
                  // Insert varian baru
                  for (var v in variants) {
                     final vName = v["name"].text.trim();
                     if (vName.isNotEmpty) {
                        final vPrice = double.tryParse(v["price"].text.replaceAll(".", "")) ?? sellPrice;
                        final vBuyPrice = double.tryParse(v["purchasePrice"].text.replaceAll(".", "")) ?? buyPrice;
                        await appDb.into(appDb.productVariants).insert(
                          ProductVariantsCompanion.insert(
                            id: "VAR-" + DateTime.now().microsecondsSinceEpoch.toString(),
                            productId: productId,
                            name: vName,
                            purchasePrice: drift.Value(vBuyPrice),
                            price: vPrice,
                          )
                        );
                     }
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(product == null ? "Produk berhasil ditambahkan!" : "Produk berhasil diperbarui!")),
                    );
                  }
                },
                child: const Text("SIMPAN"),
              ),
            ],
          ),
        ),
      );
    }
  }
  void _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: Text('Anda yakin ingin menghapus "${product.name}"?\nData produk akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await (appDb.delete(appDb.products)..where((t) => t.id.equals(product.id))).go();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk dihapus')));
    }
  }

  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membaca file")));
        }
        return;
      }

      var excel = Excel.decodeBytes(bytes);
      int count = 0;
      final biz = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull();
      final bizId = biz?.id ?? "BIZ-1";

      await appDb.batch((batch) {
        for (var table in excel.tables.keys) {
          var rows = excel.tables[table]?.rows;
          if (rows == null || rows.isEmpty) continue;
          
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.isEmpty || row[0] == null || row[0]!.value == null) continue;

            String name = row[0]!.value.toString();
            String? sku = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString() : null;
            String? barcode = row.length > 2 && row[2]?.value != null ? row[2]!.value.toString() : null;
            double buyPrice = row.length > 3 && row[3]?.value != null ? double.tryParse(row[3]!.value.toString()) ?? 0 : 0;
            double sellPrice = row.length > 4 && row[4]?.value != null ? double.tryParse(row[4]!.value.toString()) ?? 0 : 0;
            int stock = row.length > 5 && row[5]?.value != null ? int.tryParse(row[5]!.value.toString()) ?? 0 : 0;
            String unit = row.length > 6 && row[6]?.value != null ? row[6]!.value.toString() : "pcs";

            final productId = "PROD-" + DateTime.now().microsecondsSinceEpoch.toString() + "-$i";

            batch.insert(
              appDb.products,
              ProductsCompanion.insert(
                id: productId,
                businessId: bizId,
                name: name,
                sku: drift.Value(sku),
                barcode: drift.Value(barcode),
                purchasePrice: drift.Value(buyPrice),
                sellingPrice: drift.Value(sellPrice),
                unit: drift.Value(unit),
                isActive: const drift.Value(true),
              ),
            );

            batch.insert(
              appDb.inventory,
              InventoryCompanion.insert(
                id: "INV-" + DateTime.now().microsecondsSinceEpoch.toString() + "-$i",
                productId: productId,
                branchId: "BRANCH-1",
                stock: drift.Value(stock),
              ),
            );
            count++;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$count produk berhasil diimport!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal import: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Produk"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: "Import Excel",
            onPressed: _importExcel,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: _ProductSearchDelegate());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_list, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StreamBuilder<List<Category>>(
                        stream: appDb.select(appDb.categories).watch(),
                        builder: (context, snap) {
                          final cats = snap.data ?? [];
                          return DropdownButton<String>(
                            value: _selectedCategoryId,
                            isExpanded: true,
                            hint: const Text('Semua Kategori'),
                            underline: const SizedBox(),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                              ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                                _updateStream();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(),
                StreamBuilder<Map<String, int>>(
                  stream: _categoryStatsStream(),
                  builder: (context, snap) {
                    final stats = snap.data ?? {'stock': 0, 'sold': 0};
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Total Stok', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('${stats['stock']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                          ],
                        ),
                        Container(width: 1, height: 30, color: Colors.blue.shade200),
                        Column(
                          children: [
                            const Text('Total Terjual', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('${stats['sold']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Belum Ada Produk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Tambahkan produk pertama Anda untuk memulai.', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Produk Pertama'),
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = products[index];
              final margin = p.sellingPrice - p.purchasePrice;
              return ListTile(
                onTap: widget.isReadOnly ? () => _showAddEditDialog(p) : null,
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: p.isActive ? Colors.indigo.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: p.imageBase64 != null
                        ? Image.memory(
                            base64Decode(p.imageBase64!),
                            fit: BoxFit.cover,
                          )
                        : Center(
                            child: Text(
                              p.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: p.isActive ? Colors.indigo : Colors.grey,
                              ),
                            ),
                          ),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (!p.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text('Nonaktif', style: TextStyle(fontSize: 10, color: Colors.red.shade700)),
                      ),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SKU: ${p.sku ?? '-'} | Barcode: ${p.barcode ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                        StreamBuilder<List<ProductVariant>>(
                          stream: (appDb.select(appDb.productVariants)..where((v) => v.productId.equals(p.id))).watch(),
                          builder: (context, snap) {
                            final variants = snap.data ?? [];
                            if (variants.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: variants.map((v) {
                                  final vMargin = v.price - v.purchasePrice;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      children: [
                                        Text("${v.name} -> Beli: Rp ${_formatter.format(v.purchasePrice.toInt())}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        const SizedBox(width: 8),
                                        Text("Jual: Rp ${_formatter.format(v.price.toInt())}", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Text("Margin: Rp ${_formatter.format(vMargin.toInt())}", style: TextStyle(fontSize: 12, color: vMargin >= 0 ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
                                      ]
                                    )
                                  );
                                }).toList()
                              );
                            } else {
                              return Row(
                                children: [
                                  Text("Beli: Rp ${_formatter.format(p.purchasePrice.toInt())}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  const SizedBox(width: 12),
                                  Text("Jual: Rp ${_formatter.format(p.sellingPrice.toInt())} / ${p.unit}", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 12),
                                  Text("Margin: Rp ${_formatter.format(margin.toInt())}", style: TextStyle(fontSize: 12, color: margin >= 0 ? Colors.blue : Colors.red, fontWeight: FontWeight.bold)),
                                ],
                              );
                            }
                          }
                        ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StreamBuilder(
                          stream: (appDb.select(appDb.inventory)..where((i) => i.productId.equals(p.id))).watchSingleOrNull(),
                          builder: (context, snap) => Text('Stok: ${snap.data?.stock ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                        ),
                        const SizedBox(width: 12),
                        StreamBuilder(
                          stream: appDb.customSelect('SELECT SUM(quantity) as sold FROM transaction_items WHERE product_id = ?', variables: [drift.Variable.withString(p.id)], readsFrom: {appDb.transactionItems}).watchSingle(),
                          builder: (context, snap) {
                            final sold = snap.data?.read<double?>('sold') ?? 0.0;
                            return Text('Terjual: ${sold.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: widget.isReadOnly ? null : PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showAddEditDialog(p);
                    if (val == 'delete') _deleteProduct(p);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                  ],
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    ),
  ],
),
      floatingActionButton: widget.isReadOnly ? null : FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
      ),
    );
  }
}

// ==================== SEARCH DELEGATE ====================
class _ProductSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Cari nama produk, SKU, atau barcode...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final formatter = NumberFormat('#,###', 'id_ID');
    return StreamBuilder<List<Product>>(
      stream: appDb.select(appDb.products).watch(),
      builder: (context, snapshot) {
        final products = (snapshot.data ?? []).where((p) {
          final q = query.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              (p.sku?.toLowerCase().contains(q) ?? false) ||
              (p.barcode?.toLowerCase().contains(q) ?? false);
        }).toList();

        if (products.isEmpty) {
          return Center(child: Text('Tidak ditemukan produk untuk "$query"'));
        }

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: p.imageBase64 != null
                      ? Image.memory(
                          base64Decode(p.imageBase64!),
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            p.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ),
                ),
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('SKU: ${p.sku ?? '-'}'),
              trailing: Text('Rp ${formatter.format(p.sellingPrice.toInt())}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              onTap: () => close(context, p.id),
            );
          },
        );
      },
    );
  }
}
