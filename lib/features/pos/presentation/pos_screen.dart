import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/utils/image_helper.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_beep/flutter_beep.dart';
import '../../../core/database/database.dart';
import 'package:drift/drift.dart' as drift;
import '../data/receipt_printer_service.dart';
import 'scanner_screen.dart';

class POSScreen extends StatefulWidget {
  final String cashierName;
  const POSScreen({super.key, this.cashierName = 'Admin Utama'});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  // Cart State
  final List<Map<String, dynamic>> _cartItems = [];
  Promo? _selectedPromo;
  
  double get _subtotal => _cartItems.fold(0, (sum, item) => sum + (item['price'] * item['qty']));
  
  double _manualDiscount = 0.0;
  final TextEditingController _manualDiscountCtrl = TextEditingController();

  double get _discountAmount {
    double total = 0.0;
    if (_selectedPromo != null) {
      if (_selectedPromo!.type == 'percentage') {
        total += _subtotal * (_selectedPromo!.value / 100);
      } else {
        total += _selectedPromo!.value;
      }
    }
    total += _manualDiscount;
    if (total > _subtotal) return _subtotal;
    return total;
  }
  
  double _taxPercentage = 0.0;
  double get _tax => (_subtotal - _discountAmount) * (_taxPercentage / 100);
  double get _grandTotal => (_subtotal - _discountAmount) + _tax;

  // Stream Database
  Stream<List<Product>> _productsStream = const Stream.empty();
  Stream<List<Shift>> _activeShiftStream = const Stream.empty();
  Stream<List<Category>> _categoriesStream = const Stream.empty();
  Stream<List<Promo>> _promosStream = const Stream.empty();
  Stream<List<Customer>> _customersStream = const Stream.empty();
  Stream<List<InventoryItem>> _inventoryStream = const Stream.empty();
  Customer? _selectedCustomer;
  
  String _searchQuery = '';
  String? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _scannerFocusNode = FocusNode();
  String _barcodeBuffer = "";
  DateTime? _lastKeyPressTime;

  @override
  void initState() {
    super.initState();
    // Mengambil data secara live dari SQLite
    _productsStream = appDb.select(appDb.products).watch();
    _initActiveShiftStream();
    _categoriesStream = appDb.select(appDb.categories).watch();
    _promosStream = appDb.select(appDb.promos).watch();
    _customersStream = appDb.select(appDb.customers).watch();
    _inventoryStream = appDb.select(appDb.inventory).watch();
    
    (appDb.select(appDb.businesses)..limit(1)).watchSingleOrNull().listen((biz) {
      if (biz != null && mounted) {
        setState(() {
          _taxPercentage = biz.taxPercentage;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_scannerFocusNode);
    });
  }

  void _initActiveShiftStream() async {
    final user = await (appDb.select(appDb.users)..where((u) => u.name.equals(widget.cashierName))).getSingleOrNull();
    final actualUserId = user?.id ?? "U-1";
    if (mounted) {
      setState(() {
        _activeShiftStream = (appDb.select(appDb.shifts)..where((s) => s.userId.equals(actualUserId) & s.status.equals("OPEN"))).watch();
      });
    }
  }

  @override
  void dispose() {
    _scannerFocusNode.dispose();
    super.dispose();
  }
  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      if (_lastKeyPressTime != null && now.difference(_lastKeyPressTime!) > const Duration(milliseconds: 100)) {
        _barcodeBuffer = "";
      }
      _lastKeyPressTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _processBarcode(_barcodeBuffer);
          _barcodeBuffer = "";
        }
      } else if (event.character != null) {
        _barcodeBuffer += event.character!;
      }
    }
  }

  Future<void> _processBarcode(String barcode) async {
    FlutterBeep.beep();
    final product = await (appDb.select(appDb.products)..where((p) => p.barcode.equals(barcode))).getSingleOrNull();
    if (product != null) {
      _addToCart(product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${product.name} ditambahkan!"), duration: const Duration(seconds: 1)));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Barcode tidak ditemukan!")));
      }
    }
  }
  void _addDirectlyToCart(Product product, double basePrice, String? variantName) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((item) => item["id"] == product.id && item["variantName"] == variantName);
      
      int currentQty = 1;
      if (existingIndex >= 0) {
        currentQty = _cartItems[existingIndex]["qty"] + 1;
        _cartItems[existingIndex]["qty"] = currentQty;
      } else {
        _cartItems.add({
          "id": product.id, 
          "name": product.name, 
          "basePrice": basePrice, 
          "price": basePrice, 
          "qty": 1, 
          "variantName": variantName,
          "wholesaleMinQty": product.wholesaleMinQty,
          "wholesalePrice": product.wholesalePrice
        });
      }
      
      // Update wholesale price for all items in cart
      for (var item in _cartItems) {
        if (item["wholesaleMinQty"] != null && item["wholesalePrice"] != null && item["wholesaleMinQty"] > 0) {
          if (item["qty"] >= item["wholesaleMinQty"]) {
            item["price"] = item["wholesalePrice"];
            item["isWholesale"] = true;
          } else {
            item["price"] = item["basePrice"];
            item["isWholesale"] = false;
          }
        } else {
          item["isWholesale"] = false;
        }
      }
    });
  }

  Future<void> _addToCart(Product product) async {
    // Cek apakah produk ini memiliki varian
    final variants = await (appDb.select(appDb.productVariants)..where((t) => t.productId.equals(product.id))).get();

    if (variants.isEmpty) {
      _addDirectlyToCart(product, product.sellingPrice, null);
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Pilih Varian: ${product.name}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: variants.map((v) => ListTile(
                  title: Text(v.name),
                  trailing: Text("Rp ${NumberFormat("#,###", "id_ID").format(v.price.toInt())}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _addDirectlyToCart(product, v.price, v.name);
                  },
                )).toList()
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL"))
              ]
            );
          }
        );
      }
    }
  }
  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedCode != null && scannedCode.trim().isNotEmpty) {
      final barcode = scannedCode.trim();
      // Cari produk di database berdasarkan SKU/Barcode
      final products = await (appDb.select(appDb.products)..where((t) => t.sku.equals(barcode) | t.barcode.equals(barcode))).get();

      if (products.isNotEmpty) {
        _addToCart(products.first);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${products.first.name} otomatis ditambahkan!'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Item (Kode: $barcode) tidak ditemukan di database!'), backgroundColor: Colors.red));
      }
    }
  }

  void _holdBill() async {
    final noteCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simpan Struk (Hold)'),
        content: TextField(
          controller: noteCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama Pelanggan / Nomor Meja', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, noteCtrl.text), child: const Text('Simpan')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final txId = 'HLD-${DateTime.now().millisecondsSinceEpoch}';
      
      await appDb.into(appDb.transactions).insert(
        TransactionsCompanion.insert(
          id: txId,
          branchId: 'CABANG-1',
          userId: widget.cashierName,
          receiptNumber: name, // Kita simpan Note/Nama di receiptNumber
          status: const drift.Value('HOLD'),
          subtotal: drift.Value(_subtotal),
          tax: drift.Value(_tax),
          discount: drift.Value(_discountAmount),
          discountNotes: drift.Value(_manualDiscount > 0 ? "Diskon di tempat" : null),
          grandTotal: drift.Value(_grandTotal),
        )
      );

      for (var item in _cartItems) {
        await appDb.into(appDb.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'H-ITEM-${DateTime.now().microsecondsSinceEpoch}',
            transactionId: txId,
            productId: item['id'],
            quantity: drift.Value(item['qty']),
            price: drift.Value(item['price']),
            subtotal: drift.Value(item['price'] * item['qty']),
          )
        );
      }

      setState(() {
        _cartItems.clear();
        _selectedPromo = null;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pesanan $name berhasil di-Hold!')));
    }
  }

  void _showHoldBillsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daftar Pesanan Tersimpan (Hold)'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: StreamBuilder<List<Transaction>>(
            stream: (appDb.select(appDb.transactions)..where((t) => t.status.equals('HOLD'))).watch(),
            builder: (context, snapshot) {
              final holds = snapshot.data ?? [];
              if (holds.isEmpty) return const Center(child: Text('Tidak ada pesanan tersimpan.'));
              
              return ListView.builder(
                itemCount: holds.length,
                itemBuilder: (context, index) {
                  final h = holds[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long, color: Colors.orange),
                      title: Text(h.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${DateFormat('HH:mm').format(h.createdAt)} | Rp ${h.grandTotal.toInt()}'),
                      trailing: FilledButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          
                          // Load items to cart
                          final items = await (appDb.select(appDb.transactionItems)..where((t) => t.transactionId.equals(h.id))).get();
                          
                          setState(() {
                            _cartItems.clear();
                            _selectedPromo = null;
                          });

                          for (var item in items) {
                            final product = await (appDb.select(appDb.products)..where((p) => p.id.equals(item.productId))).getSingleOrNull();
                            if (product != null) {
                              double correctBasePrice = product.sellingPrice;
                              if (item.variantName != null) {
                                final variant = await (appDb.select(appDb.productVariants)..where((v) => v.productId.equals(product.id) & v.name.equals(item.variantName!))).getSingleOrNull();
                                if (variant != null) {
                                  correctBasePrice = variant.price;
                                }
                              }
                              
                              setState(() {
                                _cartItems.add({
                                  'id': product.id, 
                                  'name': product.name, 
                                  'price': item.price, 
                                  'basePrice': correctBasePrice,
                                  'qty': item.quantity,
                                  'variantName': item.variantName,
                                  'wholesaleMinQty': product.wholesaleMinQty,
                                  'wholesalePrice': product.wholesalePrice
                                });
                              });
                            }
                          }
                          
                          // Hapus dari hold DB
                          await (appDb.delete(appDb.transactionItems)..where((t) => t.transactionId.equals(h.id))).go();
                          await (appDb.delete(appDb.transactions)..where((t) => t.id.equals(h.id))).go();
                          
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pesanan ${h.receiptNumber} dimuat kembali.')));
                        },
                        child: const Text('Lanjutkan'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchTodayReport() async {
    final userRow = await (appDb.select(appDb.users)..where((u) => u.name.equals(widget.cashierName))).getSingleOrNull();
    final actualUserId = userRow?.id ?? "U-1";

    // Cari shift yang sedang aktif (OPEN) untuk user ini
    final activeShift = await (appDb.select(appDb.shifts)
      ..where((s) => s.userId.equals(actualUserId) & s.status.equals('OPEN'))
      ..orderBy([(s) => drift.OrderingTerm.desc(s.openedAt)])
      ..limit(1)
    ).getSingleOrNull();

    if (activeShift == null) {
      return {
        'total': 0.0,
        'cash': 0.0,
        'qris': 0.0,
        'transactions': <Map<String, dynamic>>[],
        'txs': <Map<String, dynamic>>[],
        'isShiftClosed': true,
      };
    }

    final txs = await (appDb.select(appDb.transactions)
      ..where((t) => t.createdAt.isBiggerOrEqualValue(activeShift.openedAt) & t.userId.equals(actualUserId))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])
    ).get();

    double total = 0;
    double cash = 0;
    double qris = 0;
    double piutang = 0;
    List<Map<String, dynamic>> txList = [];

    for (var tx in txs) {
      final pay = await (appDb.select(appDb.payments)..where((p) => p.transactionId.equals(tx.id))).getSingleOrNull();
      final method = pay?.method ?? 'CASH';
      
      if (method == 'CASH') { cash += tx.grandTotal; total += tx.grandTotal; }
      else if (method == 'QRIS') { qris += tx.grandTotal; total += tx.grandTotal; }
      else if (method == 'KASBON') { piutang += tx.grandTotal; }

      txList.add({
        'receipt': tx.receiptNumber,
        'date': tx.createdAt,
        'cashier': tx.userId,
        'method': method,
        'total': tx.grandTotal,
        'discount': tx.discount,
        'pointsUsed': tx.pointsUsed,
      });
    }

    final dps = await (appDb.select(appDb.debtPayments)
      ..where((d) => d.date.isBiggerOrEqualValue(activeShift.openedAt))
    ).get();
    
    double shiftDebtPayments = 0;
    for (var dp in dps) {
      shiftDebtPayments += dp.amount;
    }
    
    piutang -= shiftDebtPayments;
    if (piutang < 0) piutang = 0;
    
    total += shiftDebtPayments;
    cash += shiftDebtPayments;

    return {
      'total': total,
      'cash': cash,
      'qris': qris,
      'piutang': piutang,
      'transactions': txList,
      'txs': txList,
      'isShiftClosed': false,
    };
  }

  Widget _buildSummaryCard(String title, double amount, MaterialColor color) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color.shade900, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Rp ${formatter.format(amount)}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showDailyReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              AppBar(
                title: const Text('Laporan Shift Saat Ini'),
                centerTitle: true,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              Expanded(
                child: FutureBuilder(
                  future: _fetchTodayReport(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                    
                    final data = snapshot.data as Map<String, dynamic>?;
                    if (data == null || data['isShiftClosed'] == true) {
                      return const Center(child: Text('Anda belum membuka shift baru.\nSilakan buka shift di menu Manajemen Shift.', textAlign: TextAlign.center));
                    }
                    if (data['transactions'].isEmpty) {
                      return const Center(child: Text('Belum ada transaksi pada shift ini.'));
                    }

                    final List<Map<String, dynamic>> txs = data['transactions'];
                    final total = data['total'];
                    final totalCash = data['cash'];
                    final totalQris = data['qris'];
                    final formatter = NumberFormat('#,###', 'id_ID');

                    return Column(
                      children: [
                        // Summary Cards
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Expanded(child: _buildSummaryCard('Pendapatan', total, Colors.blue)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildSummaryCard('Tunai', totalCash, Colors.green)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildSummaryCard('QRIS', totalQris, Colors.purple)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildSummaryCard('Piutang', data['piutang'], Colors.orange)),
                            ],
                          ),
                        ),
                        const Divider(),
                        // List
                        Expanded(
                          child: ListView.builder(
                            itemCount: txs.length,
                            itemBuilder: (context, i) {
                              final tx = txs[i];
                              final time = DateFormat('HH:mm').format(tx['date']);
                              final double discount = tx['discount'] ?? 0;
                              final double pointsUsed = tx['pointsUsed'] ?? 0;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: tx['method'] == 'CASH' ? Colors.green.shade100 : (tx['method'] == 'KASBON' ? Colors.orange.shade100 : Colors.purple.shade100),
                                  child: Icon(tx['method'] == 'CASH' ? Icons.money : (tx['method'] == 'KASBON' ? Icons.receipt_long : Icons.qr_code), color: tx['method'] == 'CASH' ? Colors.green : (tx['method'] == 'KASBON' ? Colors.orange : Colors.purple)),
                                ),
                                title: Text(tx['receipt']),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('$time • Kasir: ${tx['cashier']} • ${tx['method']}'),
                                    if (discount > 0 || pointsUsed > 0)
                                      Text(
                                        [
                                          if (discount > 0) 'Promo: Rp ${formatter.format(discount.toInt())}',
                                          if (pointsUsed > 0) 'Poin: Rp ${formatter.format(pointsUsed.toInt())}'
                                        ].join(' | '),
                                        style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (discount > 0 || pointsUsed > 0)
                                      Text(
                                        'Rp ${formatter.format((tx['total'] + discount + pointsUsed).toInt())}',
                                        style: const TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough, color: Colors.grey),
                                      ),
                                    Text('Rp ${formatter.format(tx['total'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCheckoutDialog() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Keranjang kosong!")));
      return;
    }

    final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull() ?? 
         const Business(id: "BIZ-1", name: "MODERN POS", address: "", phone: "", logoBase64: null, taxPercentage: 0.0, enableTableNumber: false, enableQueueNumber: false);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => _CheckoutDialog(
          total: _grandTotal, 
          enableTableNumber: business.enableTableNumber,
          hasCustomer: _selectedCustomer != null,
          customerPoints: _selectedCustomer?.point ?? 0,
          onComplete: (paid, change, method, tableNum, dueDate, usePoints) => _completeTransaction(paid, change, method, tableNum, dueDate, usePoints, business),
        ),
      );
    }
  }

  void _completeTransaction(double paid, double change, String paymentMethod, String? tableNum, DateTime? dueDate, bool usePoints, Business business) async {
    Navigator.of(context).pop(); // close dialog
    
    final txId = "INV-${DateTime.now().millisecondsSinceEpoch}";

    try {
      // Hitung Queue Number (Reset tiap hari)
      int? queueNum;
      if (business.enableQueueNumber) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        
        final todayTxs = await (appDb.select(appDb.transactions)
          ..where((t) => t.createdAt.isBetweenValues(startOfDay, endOfDay) & t.queueNumber.isNotNull())
        ).get();
        
        queueNum = todayTxs.length + 1;
      }

      double pointsUsedAmount = 0;
      double pointsEarnedAmount = 0;
      double finalGrandTotal = _grandTotal;

      if (_selectedCustomer != null) {
        if (usePoints) {
          pointsUsedAmount = _selectedCustomer!.point;
          if (pointsUsedAmount > finalGrandTotal) {
            pointsUsedAmount = finalGrandTotal;
          }
          finalGrandTotal -= pointsUsedAmount;
          // Jangan dapatkan poin baru jika transaksi ini menggunakan poin (menghindari kebingungan user)
          pointsEarnedAmount = 0;
        } else {
          // Earn points: 1 point for every Rp 100 spent
          pointsEarnedAmount = (finalGrandTotal / 100).floorToDouble();
        }
      }

      // Get the correct user ID
      final user = await (appDb.select(appDb.users)..where((u) => u.name.equals(widget.cashierName))).getSingleOrNull();
      final actualUserId = user?.id ?? "U-1";

      // Simpan Transaksi Utama ke Database SQLite
      await appDb.into(appDb.transactions).insert(
        TransactionsCompanion.insert(
          id: txId,
          branchId: "CABANG-1",
          userId: actualUserId,
          customerId: drift.Value(_selectedCustomer?.id),
          receiptNumber: txId,
          status: const drift.Value("COMPLETED"),
          subtotal: drift.Value(_subtotal),
          tax: drift.Value(_tax),
          discount: drift.Value(_discountAmount),
          grandTotal: drift.Value(finalGrandTotal),
          tableNumber: drift.Value(tableNum),
          queueNumber: drift.Value(queueNum),
          dueDate: drift.Value(dueDate),
          pointsUsed: drift.Value(pointsUsedAmount),
          pointsEarned: drift.Value(pointsEarnedAmount),
          discountNotes: drift.Value(_manualDiscount > 0 ? "Diskon di tempat" : null),
          createdAt: drift.Value(DateTime.now()),
        )
      );

      if (_selectedCustomer != null) {
        // Jika Kasbon, tambah utang pelanggan
        double updatedDebt = _selectedCustomer!.debt;
        if (paymentMethod == "KASBON") {
          updatedDebt += finalGrandTotal;
        }
        
        double updatedPoints = _selectedCustomer!.point - pointsUsedAmount + pointsEarnedAmount;

        await (appDb.update(appDb.customers)..where((c) => c.id.equals(_selectedCustomer!.id))).write(
          CustomersCompanion(
            debt: drift.Value(updatedDebt),
            point: drift.Value(updatedPoints),
          )
        );
      }

      // Simpan item belanja ke TransactionItems dan potong stok
      int itemIndex = 0;
      for (var item in _cartItems) {
        itemIndex++;
        String? finalVariant = item['variantName'];
        if (item['isWholesale'] == true) {
          finalVariant = finalVariant != null ? '$finalVariant (Grosir)' : '(Grosir)';
          // Simpan juga kembali ke cart untuk dicetak di struk!
          item['variantName'] = finalVariant;
        }

        await appDb.into(appDb.transactionItems).insert(
          TransactionItemsCompanion.insert(
            id: 'ITEM-${DateTime.now().microsecondsSinceEpoch}-$itemIndex',
            transactionId: txId,
            productId: item['id'],
            variantName: drift.Value(finalVariant),
            quantity: drift.Value(item['qty']),
            price: drift.Value(item['price']),
            subtotal: drift.Value(item['price'] * item['qty']),
          )
        );

        // Potong stok (hanya jika ada data di inventory)
        final inv = await (appDb.select(appDb.inventory)..where((t) => t.productId.equals(item['id']))).getSingleOrNull();
        if (inv != null) {
          await (appDb.update(appDb.inventory)..where((t) => t.id.equals(inv.id))).write(
            InventoryCompanion(stock: drift.Value(inv.stock - (item['qty'] as int)))
          );
        }
      }

      // Simpan Payment
      await appDb.into(appDb.payments).insert(
        PaymentsCompanion.insert(
          id: 'PAY-${DateTime.now().microsecondsSinceEpoch}',
          transactionId: txId,
          method: drift.Value(paymentMethod),
          amount: drift.Value(paid),
          changeAmount: drift.Value(change),
        )
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi Berhasil Disimpan ke Database! Mencetak struk...')));
      }

      // Use the passed in business object instead of querying again

      final prefs = await SharedPreferences.getInstance();
      final isAutoPrint = prefs.getBool("isAutoPrint") ?? true;

      if (isAutoPrint) {
        await ReceiptPrinterService.printReceipt(
          business: business,
          items: _cartItems,
          subtotal: _subtotal,
          discount: _discountAmount,
          discountNotes: _manualDiscount > 0 ? "Diskon di tempat" : _selectedPromo?.name,
          tax: _tax,
          total: finalGrandTotal,
          paid: paid,
          change: change,
          paymentMethod: paymentMethod,
          cashierName: widget.cashierName,
          tableNumber: tableNum,
          queueNumber: queueNum,
          dueDate: dueDate,
          pointsUsed: pointsUsedAmount,
        );
      }

      setState(() {
        _cartItems.clear();
        _selectedCustomer = null;
      });

    } catch (e, st) {
      print('=== POS SAVE ERROR ===');
      print(e);
      print(st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error 404: Terjadi kesalahan. Silakan coba lagi. $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900 || MediaQuery.of(context).size.height < 600;

    return KeyboardListener(
      focusNode: _scannerFocusNode,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      endDrawer: isMobile ? Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: SafeArea(child: _buildCartSection()),
      ) : null,
      body: StreamBuilder<List<Shift>>(
        stream: _activeShiftStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final shifts = snapshot.data ?? [];
          if (shifts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_clock, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Shift Belum Dibuka', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Anda harus membuka shift dan memasukkan\nmodal kas awal sebelum bisa bertransaksi.', textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kiri: Search, Categories, Products
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar - Responsive
                      Padding(
                        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, isMobile ? 12 : 24, isMobile ? 12 : 24, isMobile ? 8 : 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: isMobile ? 'Cari...' : 'Search menu here...',
                                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val.toLowerCase();
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _scanBarcode,
                              icon: const Icon(Icons.qr_code_scanner, size: 22),
                              tooltip: 'Scan Barcode',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.grey.shade700,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                              ),
                            ),
                            if (!isMobile) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _showDailyReport,
                                icon: const Icon(Icons.receipt_long, size: 20),
                                label: const Text('Report'),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.grey.shade700,
                                  side: BorderSide(color: Colors.grey.shade200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const Spacer(),
                              // Profile
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    child: Text(
                                      widget.cashierName.isNotEmpty ? widget.cashierName[0].toUpperCase() : 'U',
                                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(widget.cashierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                      const Text('Cashier', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                            if (isMobile) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _showDailyReport,
                                icon: const Icon(Icons.receipt_long, size: 22),
                                tooltip: 'Laporan Shift',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.grey.shade700,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Builder(
                                builder: (context) {
                                  return IconButton(
                                    icon: Badge(
                                      label: Text('${_cartItems.length}'),
                                      isLabelVisible: _cartItems.isNotEmpty,
                                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.black87),
                                    ),
                                    onPressed: () {
                                      Scaffold.of(context).openEndDrawer();
                                    },
                                  );
                                }
                              ),
                            ]
                          ],
                        ),
                      ),
                      
                      // Categories
                      SizedBox(
                        height: 50,
                        child: StreamBuilder<List<Category>>(
                          stream: _categoriesStream,
                          builder: (context, snapshot) {
                            final categories = snapshot.data ?? [];
                            return ListView(
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
                              children: [
                                _buildCategoryChip(null, 'All Menu'),
                                ...categories.map((c) => _buildCategoryChip(c.id, c.name)),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Grid
                      Expanded(
                        child: _buildProductSection(),
                      ),
                    ],
                  ),
                ),
                
                // Kanan: Cart
                if (!isMobile)
                  Container(
                    width: 350,
                    color: Colors.white,
                    child: _buildCartSection(),
                  ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildCategoryChip(String? id, String label) {
    final isSelected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _selectedCategoryId = id);
        },
      ),
    );
  }

  Widget _buildProductSection() {
    return StreamBuilder<List<Product>>(
      stream: _productsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final allProducts = snapshot.data ?? [];
        final products = allProducts.where((p) {
          final matchesSearch = p.name.toLowerCase().contains(_searchQuery) || 
                                (p.sku != null && p.sku!.toLowerCase().contains(_searchQuery)) ||
                                (p.barcode != null && p.barcode!.toLowerCase().contains(_searchQuery));
          
          final matchesCategory = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
          
          return matchesSearch && matchesCategory && p.isActive;
        }).toList();

        if (products.isEmpty) {
          return const Center(child: Text('Menu tidak ditemukan.'));
        }

        return StreamBuilder<List<InventoryItem>>(
          stream: _inventoryStream,
          builder: (context, invSnapshot) {
            final inventory = invSnapshot.data ?? [];
            final inventoryMap = {for (var item in inventory) item.productId: item.stock};

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth < 600 ? 2 : constraints.maxWidth < 900 ? 3 : 4;
                  double aspectRatio = constraints.maxWidth < 600 ? 0.65 : 0.8;
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final p = products[index];
                      final stock = inventoryMap[p.id] ?? 0;
                      
                      // Calculate qty in cart
                      int qtyInCart = 0;
                      for (var item in _cartItems) {
                        if (item['id'] == p.id) {
                          qtyInCart += item['qty'] as int;
                        }
                      }
                      
                      return _ProductCard(
                        name: p.name,
                        price: p.sellingPrice,
                        hasVariants: false,
                        imageBase64: p.imageBase64,
                        stock: stock,
                        unit: p.unit,
                        qtyInCart: qtyInCart,
                        onTap: () => _addToCart(p),
                        onIncrement: () => _addToCart(p),
                        onDecrement: () {
                           // Find index in cart and decrement
                           for (int i = 0; i < _cartItems.length; i++) {
                             if (_cartItems[i]['id'] == p.id) {
                               _updateCartQty(i, -1);
                               break;
                             }
                           }
                        }
                      );
                    },
                  );
                }
              ),
            );
          },
        );
      },
    );
  }
  void _updateCartQty(int index, int delta) {
    setState(() {
      _cartItems[index]['qty'] += delta;
      if (_cartItems[index]['qty'] <= 0) {
        _cartItems.removeAt(index);
      } else {
        // Cek harga grosir kembali setelah qty berubah
        final item = _cartItems[index];
        if (item["wholesaleMinQty"] != null && item["wholesalePrice"] != null && item["wholesaleMinQty"] > 0) {
          if (item["qty"] >= item["wholesaleMinQty"]) {
            item["price"] = item["wholesalePrice"];
            item["isWholesale"] = true;
          } else {
            item["price"] = item["basePrice"];
            item["isWholesale"] = false;
          }
        } else {
          item["isWholesale"] = false;
        }
      }
    });
  }

  Widget _buildCartSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCustomer != null 
                    ? "${_selectedCustomer!.name} (Poin: ${_selectedCustomer!.point.toInt()})" 
                    : "Walk-in Customer",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _cartItems.isEmpty
              ? const Center(child: Text('Keranjang Kosong'))
              : ListView.builder(
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return ListTile(
                      title: Text(item['variantName'] != null ? '${item['name']} - ${item['variantName']}' : item['name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Rp ${NumberFormat('#,###', 'id_ID').format(item['price'].toInt())} x ${item['qty']}${item['isWholesale'] == true ? '\n(Harga Grosir)' : ''}', style: TextStyle(color: item['isWholesale'] == true ? Colors.green : Colors.grey.shade600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Rp ${NumberFormat('#,###', 'id_ID').format((item['price'] * item['qty']).toInt())}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _updateCartQty(index, -1),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                onPressed: () => _updateCartQty(index, 1),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Flexible(
          flex: 0,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
            children: [
              StreamBuilder<List<Customer>>(
                stream: _customersStream,
                builder: (context, snapshot) {
                  final customers = snapshot.data ?? [];
                  Customer? actualSelectedCustomer;
                  if (_selectedCustomer != null) {
                    try {
                      actualSelectedCustomer = customers.firstWhere((c) => c.id == _selectedCustomer!.id);
                    } catch (_) {}
                  }

                  return DropdownButtonFormField<Customer?>(
                    value: actualSelectedCustomer,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Pelanggan (Opsional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<Customer?>(value: null, child: Text('Pelanggan Umum')),
                      ...customers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomer = val;
                      });
                    },
                  );
                }
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Promo>>(
                stream: _promosStream,
                builder: (context, snapshot) {
                  final promos = snapshot.data?.where((p) => p.isActive).toList() ?? [];
                  Promo? actualSelectedPromo;
                  if (_selectedPromo != null) {
                    try {
                      actualSelectedPromo = promos.firstWhere((p) => p.id == _selectedPromo!.id);
                    } catch (_) {}
                  }

                  return DropdownButtonFormField<Promo?>(
                    value: actualSelectedPromo,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Diskon / Promo',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<Promo?>(value: null, child: Text('Tanpa Promo')),
                      ...promos.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedPromo = val;
                      });
                    },
                  );
                }
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualDiscountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Diskon Manual (Rp) - Opsional',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _manualDiscountCtrl.text.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _manualDiscountCtrl.clear();
                      setState(() {
                        _manualDiscount = 0.0;
                      });
                    },
                  ) : null,
                ),
                onChanged: (val) {
                  setState(() {
                    _manualDiscount = double.tryParse(val) ?? 0.0;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal'),
                  Text('Rp ${_subtotal.toInt()}'),
                ],
              ),
              if (_discountAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Diskon (${_selectedPromo != null && _manualDiscount > 0 ? "Promo + Manual" : _manualDiscount > 0 ? "Manual" : _selectedPromo?.name})', style: const TextStyle(color: Colors.green)),
                    Text('- Rp ${_discountAmount.toInt()}', style: const TextStyle(color: Colors.green)),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pajak (11%)'),
                  Text('Rp ${_tax.toInt()}'),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Rp $_grandTotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.pause, size: 18),
                      onPressed: _cartItems.isEmpty ? null : _holdBill,
                      label: const FittedBox(child: Text('HOLD', maxLines: 1)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StreamBuilder<List<Transaction>>(
                      stream: (appDb.select(appDb.transactions)..where((t) => t.status.equals('HOLD'))).watch(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return OutlinedButton.icon(
                          icon: Badge(
                            isLabelVisible: count > 0,
                            label: Text('$count'),
                            child: const Icon(Icons.receipt_long, size: 18),
                          ),
                          onPressed: () => _showHoldBillsDialog(),
                          label: const FittedBox(child: Text('BILLS', maxLines: 1)),
                        );
                      }
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                           _cartItems.clear();
                           _selectedCustomer = null;
                        });
                      },
                      child: const Text('BATAL'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _showCheckoutDialog,
                      child: const Text('BAYAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final double price;
  final bool hasVariants;
  final String? imageBase64;
  final int stock;
  final String unit;
  final VoidCallback onTap;
  final int qtyInCart;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _ProductCard({
    required this.name, 
    required this.price, 
    this.hasVariants = false,
    this.imageBase64, 
    required this.stock,
    required this.unit,
    required this.onTap,
    this.qtyInCart = 0,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.grey.shade100,
                    child: (imageBase64 != null && ImageHelper.decodeBase64(imageBase64) != null)
                        ? Image.memory(
                            ImageHelper.decodeBase64(imageBase64)!,
                            fit: BoxFit.cover,
                          )
                        : Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade300),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stock > 0 ? Theme.of(context).colorScheme.primary.withOpacity(0.9) : Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stock > 0 ? '$stock $unit' : 'Habis',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name, 
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.2), 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Rp ${NumberFormat("#,###", "id_ID").format(price)}', 
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasVariants)
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: Theme.of(context).colorScheme.primary)
                          ),
                          child: const Text('Pilih Varian', style: TextStyle(fontSize: 12)),
                        ),
                      )
                    else if (qtyInCart == 0)
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: FilledButton(
                          onPressed: onIncrement,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                          ),
                          child: const Text('+ Tambah', style: TextStyle(fontSize: 12)),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: onDecrement,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.remove, size: 16),
                            ),
                          ),
                          Text('$qtyInCart', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          InkWell(
                            onTap: onIncrement,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final double total;
  final bool enableTableNumber;
  final bool hasCustomer;
  final double customerPoints;
  final Function(double paid, double change, String method, String? tableNum, DateTime? dueDate, bool usePoints) onComplete;

  const _CheckoutDialog({required this.total, required this.enableTableNumber, required this.hasCustomer, required this.customerPoints, required this.onComplete});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  double _paidAmount = 0;
  String _paymentMethod = 'CASH'; // 'CASH' atau 'QRIS' atau 'KASBON'
  DateTime? _dueDate;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _tableCtrl = TextEditingController();
  bool _usePoints = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() {
      final val = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (val != _paidAmount) {
        setState(() {
          _paidAmount = val;
        });
      }
    });
  }

  void _addQuickCash(double amount) {
    setState(() {
      _paidAmount += amount;
      _amountCtrl.text = _paidAmount.toInt().toString();
    });
  }

  void _setExactAmount() {
    setState(() {
      _paidAmount = widget.total;
      _amountCtrl.text = _paidAmount.toInt().toString();
    });
  }

  void _resetAmount() {
    setState(() {
      _paidAmount = 0;
      _amountCtrl.text = '';
    });
  }

  void _onNumpadTap(String val) {
    if (val == 'C') {
      _resetAmount();
    } else if (val == '⌫') {
      setState(() {
        String current = _paidAmount.toInt().toString();
        if (current.length > 1) {
          current = current.substring(0, current.length - 1);
          _paidAmount = double.parse(current);
        } else {
          _paidAmount = 0;
        }
      });
    } else if (val == '+10k') {
      _addQuickCash(10000);
    } else if (val == '+50k') {
      _addQuickCash(50000);
    } else if (val == '+100k') {
      _addQuickCash(100000);
    } else if (val == 'PAS') {
      _setExactAmount();
    } else {
      setState(() {
        String current = _paidAmount == 0 ? '' : _paidAmount.toInt().toString();
        current += val;
        if (current.length <= 11) { // Max around 99 billion
          _paidAmount = double.tryParse(current) ?? 0;
        }
      });
    }
  }

  Widget _buildNumpadBtn(String label, {Color? color}) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: () => _onNumpadTap(label),
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            label, 
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              color: label == 'C' ? Colors.red : (color != null && color != Colors.grey.shade200 ? Colors.blue.shade900 : Colors.black87)
            )
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget _buildLeftPanel(double totalAfterPoints, double change, NumberFormat formatter) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total Tagihan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Tagihan", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                Text("Rp ${formatter.format(totalAfterPoints)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.blue.shade900)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (widget.hasCustomer && widget.customerPoints > 0)
            SwitchListTile(
              title: const Text("Gunakan Poin"),
              subtitle: Text("Poin tersedia: ${widget.customerPoints.toInt()} (Rp ${formatter.format(widget.customerPoints.toInt())})"),
              value: _usePoints,
              onChanged: (val) {
                setState(() {
                  _usePoints = val;
                });
              },
            ),
          const SizedBox(height: 8),

          if (widget.enableTableNumber) ...[
            TextField(
              controller: _tableCtrl,
              decoration: const InputDecoration(
                labelText: 'Nomor Meja / Nama Pemesan',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.table_restaurant),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          if (_paymentMethod == 'CASH') ...[
            // Input Nominal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade200, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Uang Diterima", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                  Text("Rp ${formatter.format(_paidAmount)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green.shade700)),
                ],
              ),
            ),
          ] else if (_paymentMethod == 'QRIS') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_2, size: 40, color: Colors.purple),
                  SizedBox(width: 16),
                  Expanded(child: Text("Pembayaran via QRIS. Pelanggan memindai kode QR toko.", style: TextStyle(color: Colors.purple))),
                ],
              ),
            ),
          ] else ...[ // KASBON
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Jatuh Tempo Pembayaran',
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
                errorText: _dueDate == null ? 'Harus diisi' : null,
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
              controller: TextEditingController(text: _dueDate != null ? DateFormat('dd MMM yyyy').format(_dueDate!) : ''),
            ),
          ],
          const SizedBox(height: 16),
          // Kembalian
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: change > 0 ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Kembalian", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                Text("Rp ${formatter.format(change > 0 ? change : 0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: change > 0 ? Colors.green.shade900 : Colors.black54)),
              ],
            ),
          ),
        ],
      );
    }

    Widget _buildRightPanel() {
      if (_paymentMethod != 'CASH') return const SizedBox();
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.4, // Buat tombol numpad sedikit lebih pipih agar muat
        children: [
          _buildNumpadBtn('1'), _buildNumpadBtn('2'), _buildNumpadBtn('3'),
          _buildNumpadBtn('4'), _buildNumpadBtn('5'), _buildNumpadBtn('6'),
          _buildNumpadBtn('7'), _buildNumpadBtn('8'), _buildNumpadBtn('9'),
          _buildNumpadBtn('C', color: Colors.red.shade50), _buildNumpadBtn('0'), _buildNumpadBtn('00'),
          _buildNumpadBtn('+10k', color: Colors.blue.shade50), _buildNumpadBtn('+50k', color: Colors.blue.shade50), _buildNumpadBtn('+100k', color: Colors.blue.shade50),
          _buildNumpadBtn('PAS', color: Colors.green.shade50), _buildNumpadBtn('⌫', color: Colors.grey.shade200),
        ],
      );
    }

    double totalAfterPoints = widget.total;
    if (_usePoints && widget.customerPoints > 0) {
       totalAfterPoints -= widget.customerPoints;
       if (totalAfterPoints < 0) totalAfterPoints = 0;
    }

    if (_paymentMethod == "QRIS") {
      _paidAmount = totalAfterPoints; // QRIS selalu pas
    }
    
    final change = _paymentMethod == "KASBON" ? 0.0 : (_paidAmount - totalAfterPoints);
    bool isEnough = _paymentMethod == "KASBON" ? (_dueDate != null) : (_paidAmount >= totalAfterPoints);
    final formatter = NumberFormat("#,###", "id_ID");
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      titlePadding: const EdgeInsets.only(top: 16, left: 24, right: 24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      title: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          // Metode Pembayaran as ChoiceChips
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Tunai'),
                selected: _paymentMethod == 'CASH',
                onSelected: (val) {
                  if (val) setState(() { _paymentMethod = 'CASH'; _amountCtrl.text = _paidAmount.toInt().toString(); });
                },
              ),
              ChoiceChip(
                label: const Text('QRIS'),
                selected: _paymentMethod == 'QRIS',
                onSelected: (val) {
                  if (val) setState(() => _paymentMethod = 'QRIS');
                },
              ),
              ChoiceChip(
                label: const Text('KASBON'),
                selected: _paymentMethod == 'KASBON',
                onSelected: widget.hasCustomer ? (val) {
                  if (val) setState(() { _paymentMethod = 'KASBON'; _paidAmount = 0; _amountCtrl.text = '0'; });
                } : null,
                tooltip: widget.hasCustomer ? null : 'Pilih Profil Pelanggan terlebih dahulu di Keranjang',
              ),
            ],
          )
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 700,
        child: SingleChildScrollView(
          child: Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PANEL KIRI
              isMobile ? _buildLeftPanel(totalAfterPoints, change, formatter) : Expanded(flex: 1, child: _buildLeftPanel(totalAfterPoints, change, formatter)),
              if (!isMobile) const SizedBox(width: 24),
              if (isMobile) const SizedBox(height: 24),
              // PANEL KANAN
              isMobile ? _buildRightPanel() : Expanded(flex: 1, child: _buildRightPanel()),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.print),
          onPressed: isEnough ? () => widget.onComplete(_paidAmount, change > 0 ? change : 0, _paymentMethod, _tableCtrl.text.trim(), _dueDate, _usePoints) : null,
          label: const Text('BAYAR & CETAK'),
        ),
      ],
    );
  }
}

