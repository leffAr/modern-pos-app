
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
                               child: Row(
                                 children: [
                                   Expanded(
                                     flex: 2,
                                     child: TextField(
                                       controller: v["name"],
                                       decoration: const InputDecoration(labelText: "Nama Varian (mis. Size L)", border: OutlineInputBorder(), isDense: true),
                                     )
                                   ),
                                   const SizedBox(width: 8),
                                   Expanded(
                                     flex: 2,
                                     child: TextField(
                                       controller: v["price"],
                                       keyboardType: TextInputType.number,
                                       decoration: const InputDecoration(labelText: "Harga Khusus", prefixText: "Rp ", border: OutlineInputBorder(), isDense: true),
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
                child: const Text("BATAL"),
              ),
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
                        await appDb.into(appDb.productVariants).insert(
                          ProductVariantsCompanion.insert(
                            id: "VAR-" + DateTime.now().microsecondsSinceEpoch.toString(),
                            productId: productId,
                            name: vName,
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
