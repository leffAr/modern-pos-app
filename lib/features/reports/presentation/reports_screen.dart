import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../data/export_service.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? _selectedDateRange;

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan'),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.date_range, color: Colors.white),
              label: Text(
                _selectedDateRange != null
                    ? '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}'
                    : 'Pilih Tanggal',
                style: const TextStyle(color: Colors.white),
              ),
              onPressed: _pickDateRange,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Penjualan'),
              Tab(text: 'Produk'),
              Tab(text: 'Laba Rugi'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SalesReportView(dateRange: _selectedDateRange),
            const _ProductReportView(),
            _ProfitReportView(dateRange: _selectedDateRange),
          ],
        ),
      ),
    );
  }
}

// ==================== TAB 1: PENJUALAN ====================
class _SalesReportView extends StatelessWidget {
  final DateTimeRange? dateRange;
  const _SalesReportView({this.dateRange});

  @override
  Widget build(BuildContext context) {
    final query = appDb.select(appDb.transactions).join([
      drift.leftOuterJoin(appDb.payments, appDb.payments.transactionId.equalsExp(appDb.transactions.id))
    ]);
    if (dateRange != null) {
      query.where(appDb.transactions.createdAt.isBiggerOrEqualValue(dateRange!.start) & appDb.transactions.createdAt.isSmallerOrEqualValue(dateRange!.end.add(const Duration(days: 1))));
    }

    return StreamBuilder<List<drift.TypedResult>>(
      stream: query.watch(),
      builder: (context, snapshot) {
        return StreamBuilder<List<DebtPayment>>(
          stream: appDb.select(appDb.debtPayments).watch(),
          builder: (context, dpSnapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final results = snapshot.data ?? [];
            final dps = dpSnapshot.data ?? [];
            
            final filteredDps = dateRange == null ? dps : dps.where((dp) => (dp.date.isAfter(dateRange!.start) || dp.date.isAtSameMomentAs(dateRange!.start)) && dp.date.isBefore(dateRange!.end.add(const Duration(days: 1))));
            double totalDebtPayments = 0;
            for (var dp in filteredDps) totalDebtPayments += dp.amount;

            if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Belum Ada Penjualan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text(
                  'Transaksi yang Anda buat di menu Kasir\nakan muncul di sini sebagai laporan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Buka Menu Kasir'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Silakan buka menu Kasir (POS) di sidebar untuk membuat transaksi pertama Anda!')),
                    );
                  },
                ),
              ],
            ),
          );
        }

        final completedResults = results.where((r) => r.readTable(appDb.transactions).status == 'COMPLETED').toList();
        
        double totalRevenue = 0;
        double totalPiutang = 0;
        for (var r in completedResults) {
          final tx = r.readTable(appDb.transactions);
          final payment = r.readTableOrNull(appDb.payments);
          if (payment?.method == 'KASBON') {
             totalPiutang += tx.grandTotal;
          } else {
             totalRevenue += tx.grandTotal;
          }
        }
        
        // Pembayaran piutang mengurangi piutang, dan menambah revenue
        totalPiutang -= totalDebtPayments;
        if (totalPiutang < 0) totalPiutang = 0;
        totalRevenue += totalDebtPayments;

        final totalTransactions = completedResults.length;
        final avgOrder = totalTransactions > 0 ? (totalRevenue+totalPiutang) / totalTransactions : 0.0;
        final formatter = NumberFormat('#,###', 'id_ID');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return GridView.count(
                  crossAxisCount: isMobile ? 1 : 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: isMobile ? 2.5 : 1.5,
                  children: [
                    _InfoCard(title: 'Total Revenue', value: 'Rp ${formatter.format(totalRevenue.toInt())}', color: Colors.green),
                    _InfoCard(title: 'Piutang (Kasbon)', value: 'Rp ${formatter.format(totalPiutang.toInt())}', color: Colors.orange),
                    _InfoCard(title: 'Transaksi', value: '${totalTransactions}', color: Colors.blue),
                    _InfoCard(title: 'Rata-rata', value: 'Rp ${formatter.format(avgOrder.toInt())}', color: Colors.indigo),
                  ],
                );
              }
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Text('Histori Transaksi', style: Theme.of(context).textTheme.titleLarge),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.people),
                      label: const Text('Export Kasir'),
                      onPressed: () async {
                        final users = await (appDb.select(appDb.users)..where((u) => u.roleId.equals('role-cashier'))).get();
                        if (!context.mounted) return;
                        
                        final selectedCashierId = await showDialog<String>(
                          context: context,
                          builder: (context) {
                            String? selectedId;
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return AlertDialog(
                                  title: const Text('Export Performa Kasir'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Pilih Kasir yang ingin diexport:'),
                                      const SizedBox(height: 16),
                                      DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Kasir'),
                                        value: selectedId,
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('Semua Kasir')),
                                          ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                                        ],
                                        onChanged: (val) => setState(() => selectedId = val),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                                    FilledButton(onPressed: () => Navigator.pop(context, selectedId ?? 'ALL'), child: const Text('Export Excel')),
                                  ],
                                );
                              }
                            );
                          }
                        );

                        if (selectedCashierId == null) return;
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyusun data performa kasir...')));
                        
                        final Map<String, Map<String, dynamic>> cashierData = {};
                        for (var r in results) {
                          final tx = r.readTable(appDb.transactions);
                          if (selectedCashierId != 'ALL' && tx.userId != selectedCashierId) continue;
                          
                          final payment = r.readTableOrNull(appDb.payments);
                          final isKasbon = payment?.method == 'KASBON';
                          
                          final userRow = await (appDb.select(appDb.users)..where((u) => u.id.equals(tx.userId))).getSingleOrNull();
                          final name = userRow?.name ?? tx.userId;
                          
                          if (!cashierData.containsKey(name)) {
                            cashierData[name] = {'count': 0, 'revenue': 0.0, 'piutang': 0.0};
                          }
                          cashierData[name]!['count'] = cashierData[name]!['count'] + 1;
                          if (isKasbon) {
                            cashierData[name]!['piutang'] = cashierData[name]!['piutang'] + tx.grandTotal;
                          } else {
                            cashierData[name]!['revenue'] = cashierData[name]!['revenue'] + tx.grandTotal;
                          }
                        }

                        final List<List<dynamic>> data = [];
                        double finalRevenue = 0;
                        double finalPiutang = 0;
                        int finalCount = 0;

                        cashierData.forEach((name, stats) {
                          final count = stats['count'] as int;
                          final revenue = stats['revenue'] as double;
                          final piutang = stats['piutang'] as double;
                          finalCount += count;
                          finalRevenue += revenue;
                          finalPiutang += piutang;

                          data.add([
                            name,
                            count,
                            revenue.toInt(),
                            piutang.toInt(),
                          ]);
                        });

                        data.add(['', '', '', '']);
                        data.add(['TOTAL', finalCount, finalRevenue.toInt(), finalPiutang.toInt()]);

                        final path = await ExportService.exportToExcel(
                          title: 'Performa_Kasir',
                          data: data,
                          headers: ['Nama Kasir', 'Total Transaksi', 'Total Pendapatan (Rp)', 'Total Piutang (Rp)'],
                        );

                        if (path != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil diexport! File tersimpan/terunduh.')));
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export Transaksi'),
                      onPressed: () async {
                        // Show loading
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sedang menyusun data Excel...')));
                        
                        final List<List<dynamic>> data = [];
                        double totalSubtotal = 0;
                        double totalDiscount = 0;
                        double totalPoints = 0;
                        double totalTax = 0;
                        double totalGrandTotal = 0;
                        double totalKasbon = 0;
                        
                        for (var r in results) {
                          final tx = r.readTable(appDb.transactions);
                          
                          final payment = r.readTableOrNull(appDb.payments);
                          final method = payment?.method ?? '-';

                          // Ambil pelanggan (jika ada)
                          String customerName = '-';
                          if (tx.customerId != null) {
                            final cust = await (appDb.select(appDb.customers)..where((c) => c.id.equals(tx.customerId!))).getSingleOrNull();
                            if (cust != null) customerName = cust.name;
                          }

                          // Ambil produk-produk yang dibeli
                          final itemsQuery = appDb.select(appDb.transactionItems).join([
                            drift.innerJoin(appDb.products, appDb.products.id.equalsExp(appDb.transactionItems.productId))
                          ])..where(appDb.transactionItems.transactionId.equals(tx.id));
                          
                          final itemsResult = await itemsQuery.get();
                          final itemNames = itemsResult.map((row) {
                            final product = row.readTable(appDb.products);
                            final item = row.readTable(appDb.transactionItems);
                            if (item.variantName != null && item.variantName!.isNotEmpty) {
                              return '${product.name} - ${item.variantName} (x${item.quantity})';
                            }
                            return '${product.name} (x${item.quantity})';
                          }).join(', ');

                          if (tx.status == 'COMPLETED') {
                            if (method == 'KASBON') {
                              totalKasbon += tx.grandTotal;
                            }
                            totalSubtotal += tx.subtotal;
                            totalDiscount += tx.discount;
                            totalPoints += tx.pointsUsed;
                            totalTax += tx.tax;
                            totalGrandTotal += tx.grandTotal;
                          }

                          // Ambil nama kasir
                          String cashierName = tx.userId;
                          final userRow = await (appDb.select(appDb.users)..where((u) => u.id.equals(tx.userId))).getSingleOrNull();
                          if (userRow != null) cashierName = userRow.name;

                          data.add([
                            tx.receiptNumber,
                            DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt),
                            tx.status,
                            tx.queueNumber?.toString() ?? '-',
                            tx.tableNumber ?? '-',
                            customerName,
                            method,
                            itemNames,
                            cashierName,
                            tx.subtotal.toInt(),
                            tx.discount.toInt(),
                            tx.discountNotes ?? '-',
                            tx.pointsUsed.toInt(),
                            tx.tax.toInt(),
                            tx.grandTotal.toInt(),
                          ]);
                        }

                        // Tambahkan baris kosong sebagai pemisah, kemudian baris Total
                        data.add(['', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);
                        data.add([
                          'TOTAL SEMUA (TERMASUK KASBON)',
                          '', '', '', '', '', '', '', '',
                          totalSubtotal.toInt(),
                          totalDiscount.toInt(),
                          '',
                          totalPoints.toInt(),
                          totalTax.toInt(),
                          totalGrandTotal.toInt(),
                        ]);

                        if (totalKasbon > 0) {
                          data.add([
                            'TOTAL KASBON (BELUM LUNAS)',
                            '', '', '', '', '', '', '', '', '', '', '', '', '',
                            totalKasbon.toInt(),
                          ]);
                          data.add([
                            'TOTAL PENDAPATAN BERSIH',
                            '', '', '', '', '', '', '', '', '', '', '', '', '',
                            (totalGrandTotal - totalKasbon).toInt(),
                          ]);
                        }

                        final headers = [
                          'No. Struk', 'Tanggal', 'Status', 'Antrian', 'Meja', 'Pelanggan', 
                          'Metode Bayar', 'Detail Produk', 'Nama Kasir', 
                          'Subtotal', 'Diskon', 'Ket. Diskon', 'Poin Dipakai', 'Pajak', 'Total Akhir'
                        ];

                        final path = await ExportService.exportToExcel(
                          title: 'Penjualan',
                          data: data,
                          headers: headers,
                        );

                        if (path != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil diexport! File tersimpan/terunduh.')));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengekspor laporan.')));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Transaction List
            ...results.map((r) {
              final tx = r.readTable(appDb.transactions);
              final payment = r.readTableOrNull(appDb.payments);
              final isKasbon = payment?.method == 'KASBON';
              
              final date = DateFormat('dd MMM yyyy, HH:mm').format(tx.createdAt);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tx.status == 'COMPLETED' ? (isKasbon ? Colors.orange.shade100 : Colors.green.shade100) : Colors.red.shade100,
                    child: Icon(
                      tx.status == 'COMPLETED' ? Icons.check : Icons.close,
                      color: tx.status == 'COMPLETED' ? (isKasbon ? Colors.orange : Colors.green) : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(tx.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      FutureBuilder(
                        future: (appDb.select(appDb.transactionItems)..where((t) => t.transactionId.equals(tx.id))).get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final hasWholesale = snapshot.data!.any((i) => i.variantName != null && i.variantName!.contains('(Grosir)'));
                          if (hasWholesale) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                              child: Text('Grosir', style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      if (tx.discount > 0 || tx.pointsUsed > 0)
                        Text(
                          [
                            if (tx.discount > 0) '${tx.discountNotes ?? "Promo"}: Rp ${formatter.format(tx.discount.toInt())}',
                            if (tx.pointsUsed > 0) 'Poin: Rp ${formatter.format(tx.pointsUsed.toInt())}'
                          ].join(' | '),
                          style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (tx.discount > 0 || tx.pointsUsed > 0)
                        Text(
                          'Rp ${formatter.format((tx.grandTotal + tx.discount + tx.pointsUsed).toInt())}',
                          style: const TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough, color: Colors.grey),
                        ),
                      Text('Rp ${formatter.format(tx.grandTotal.toInt())}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: tx.status == 'COMPLETED' ? (isKasbon ? Colors.orange : Colors.green) : Colors.red)),
                      Text(isKasbon ? 'KASBON' : tx.status, style: TextStyle(fontSize: 11, color: tx.status == 'COMPLETED' ? (isKasbon ? Colors.orange : Colors.green) : Colors.red, fontWeight: isKasbon ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                  onTap: () async {
                    if (tx.status != 'COMPLETED') return;
                    
                    // Ambil detail kasir
                    final kasirUser = await (appDb.select(appDb.users)..where((u) => u.id.equals(tx.userId))).getSingleOrNull();
                    final kasirName = kasirUser?.name ?? tx.userId;

                    // Ambil detail item untuk ditampilkan
                    final items = await (appDb.select(appDb.transactionItems)..where((t) => t.transactionId.equals(tx.id))).get();
                    
                    List<String> itemsText = [];
                    for (var item in items) {
                      final product = await (appDb.select(appDb.products)..where((p) => p.id.equals(item.productId))).getSingleOrNull();
                      final productName = product?.name ?? 'Produk Tidak Ditemukan';
                      
                      String displayName = productName;
                      if (item.variantName != null && item.variantName!.isNotEmpty) {
                        displayName += ' - ${item.variantName}';
                      }
                      
                      itemsText.add('- $displayName x${item.quantity}\n  Rp ${formatter.format(item.subtotal.toInt())}');
                    }
                    
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Detail Transaksi'),
                            content: SingleChildScrollView(
                              child: Text(
                                'Nomor Struk: ${tx.receiptNumber}\n'
                                'Kasir: $kasirName\n\n'
                                '-- ITEM PESANAN --\n'
                                '${itemsText.join('\n')}\n'
                                '--------------------\n'
                                'Subtotal: Rp ${formatter.format(tx.subtotal.toInt())}\n'
                                'Pajak: Rp ${formatter.format(tx.tax.toInt())}\n'
                                'Diskon Promo: -Rp ${formatter.format(tx.discount.toInt())}\n'
                                'Diskon Poin: -Rp ${formatter.format(tx.pointsUsed.toInt())}\n'
                                '--------------------\n'
                                'Total Akhir: Rp ${formatter.format(tx.grandTotal.toInt())}'
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Tutup'),
                              ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: Colors.red),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Void (Batalkan)'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Konfirmasi Void'),
                                    content: const Text('Apakah Anda yakin ingin membatalkan transaksi ini? Stok barang akan dikembalikan.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Ya, Batalkan')),
                                    ],
                                  ),
                                );
                                
                                if (confirm == true) {
                                  // 1. Get Items
                                  final items = await (appDb.select(appDb.transactionItems)..where((t) => t.transactionId.equals(tx.id))).get();
                                  
                                  // 2. Refund Inventory
                                  for (var item in items) {
                                    final inv = await (appDb.select(appDb.inventory)..where((i) => i.productId.equals(item.productId))).getSingleOrNull();
                                    if (inv != null) {
                                      await appDb.update(appDb.inventory).replace(inv.copyWith(stock: inv.stock + item.quantity));
                                    }
                                  }
                                  
                                  // 3. Update Status
                                  await appDb.update(appDb.transactions).replace(tx.copyWith(status: 'VOID'));
                                  
                                  if (context.mounted) {
                                    Navigator.pop(context); // Close Detail Dialog
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaksi berhasil dibatalkan (VOID). Stok dikembalikan.')));
                                  }
                                }
                              },
                            ),
                          ],
                        );
                      }
                    );
                  }
                },
              ),
            );
          }),
          ],
         );
        },
       );
      },
    );
  }
}

// ==================== TAB 2: PRODUK ====================
class _ProductReportView extends StatelessWidget {
  final DateTimeRange? dateRange;
  const _ProductReportView({this.dateRange});

  @override
  Widget build(BuildContext context) {
    final query = appDb.select(appDb.transactions).join([
      drift.innerJoin(appDb.transactionItems, appDb.transactionItems.transactionId.equalsExp(appDb.transactions.id)),
      drift.innerJoin(appDb.products, appDb.products.id.equalsExp(appDb.transactionItems.productId)),
    ]);

    if (dateRange != null) {
      query.where(
        appDb.transactions.createdAt.isBiggerOrEqualValue(dateRange!.start) & 
        appDb.transactions.createdAt.isSmallerOrEqualValue(dateRange!.end.add(const Duration(days: 1))) &
        appDb.transactions.status.equals('COMPLETED')
      );
    } else {
      query.where(appDb.transactions.status.equals('COMPLETED'));
    }

    return StreamBuilder<List<drift.TypedResult>>(
      stream: query.watch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
        }
        
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Belum Ada Penjualan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('Lakukan transaksi untuk melihat\nproduk terlaris.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        // Group by product id
        final Map<String, Map<String, dynamic>> productStats = {};
        for (var row in results) {
          final item = row.readTable(appDb.transactionItems);
          final product = row.readTable(appDb.products);

          if (!productStats.containsKey(product.id)) {
            productStats[product.id] = {
              'name': product.name,
              'sku': product.sku,
              'qty': 0,
              'revenue': 0.0,
            };
          }
          productStats[product.id]!['qty'] += item.quantity;
          productStats[product.id]!['revenue'] += item.subtotal;
        }

        // Sort by quantity descending
        final sortedStats = productStats.values.toList()
          ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));

        final formatter = NumberFormat('#,###', 'id_ID');

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _InfoCard(title: 'Total Produk Terjual', value: '${sortedStats.fold<int>(0, (sum, stat) => sum + (stat['qty'] as int))}', color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                Text('Produk Terlaris', style: Theme.of(context).textTheme.titleLarge),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export Excel'),
                  onPressed: () async {
                    final List<List<dynamic>> data = [];
                    for (var stat in sortedStats) {
                      data.add([
                        stat['name'].toString(),
                        stat['sku']?.toString() ?? '-',
                        stat['qty'] as int,
                        (stat['revenue'] as double).toInt(),
                      ]);
                    }

                    final path = await ExportService.exportToExcel(
                      title: 'Laporan_Produk_Terlaris',
                      data: data,
                      headers: ['Nama Produk', 'SKU', 'Jumlah Terjual (Qty)', 'Total Omset (Rp)'],
                    );

                    if (path != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil diexport! File tersimpan/terunduh.')));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sortedStats.map((stat) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(stat['name'].substring(0, 1).toUpperCase(), style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold)),
                ),
                title: Text(stat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('SKU: ${stat['sku'] ?? '-'}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${stat['qty']} Terjual', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                    Text('Rp ${formatter.format(stat['revenue'].toInt())}', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}

// ==================== TAB 3: LABA RUGI ====================
class _ProfitReportView extends StatelessWidget {
  final DateTimeRange? dateRange;
  const _ProfitReportView({this.dateRange});

  @override
  Widget build(BuildContext context) {
    // Stream transactions joined with items and products for COGS
    final cogsQuery = appDb.select(appDb.transactions).join([
      drift.innerJoin(appDb.transactionItems, appDb.transactionItems.transactionId.equalsExp(appDb.transactions.id)),
      drift.innerJoin(appDb.products, appDb.products.id.equalsExp(appDb.transactionItems.productId)),
    ]);
    if (dateRange != null) {
      cogsQuery.where(
        appDb.transactions.createdAt.isBiggerOrEqualValue(dateRange!.start) & 
        appDb.transactions.createdAt.isSmallerOrEqualValue(dateRange!.end.add(const Duration(days: 1))) &
        appDb.transactions.status.equals('COMPLETED')
      );
    } else {
      cogsQuery.where(appDb.transactions.status.equals('COMPLETED'));
    }

    // Stream expenses
    final expQuery = appDb.select(appDb.expenses);
    if (dateRange != null) {
      expQuery.where((e) => e.date.isBiggerOrEqualValue(dateRange!.start) & e.date.isSmallerOrEqualValue(dateRange!.end.add(const Duration(days: 1))));
    }

    return StreamBuilder<List<drift.TypedResult>>(
      stream: cogsQuery.watch(),
      builder: (context, cogsSnapshot) {
        return StreamBuilder<List<Expense>>(
          stream: expQuery.watch(),
          builder: (context, expSnapshot) {
            final cogsResults = cogsSnapshot.data ?? [];
            final expenses = expSnapshot.data ?? [];

            // Calculate Revenue and COGS
            double totalRevenue = 0.0;
            double totalCOGS = 0.0;
            
            // To avoid double counting revenue for the same transaction ID
            final Set<String> processedTxIds = {};

            for (var row in cogsResults) {
              final tx = row.readTable(appDb.transactions);
              final item = row.readTable(appDb.transactionItems);
              final product = row.readTable(appDb.products);

              if (!processedTxIds.contains(tx.id)) {
                totalRevenue += (tx.subtotal - tx.discount); // Net Sales (Excluding Tax because Tax is not revenue)
                processedTxIds.add(tx.id);
              }
              
              totalCOGS += (item.quantity * product.purchasePrice);
            }

            final grossProfit = totalRevenue - totalCOGS;
            final totalExpenses = expenses.fold<double>(0, (sum, exp) => sum + exp.amount);
            final netProfit = grossProfit - totalExpenses;
            
            final formatter = NumberFormat('#,###', 'id_ID');

            if (cogsResults.isEmpty && expenses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Belum Ada Data Keuangan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                    const SizedBox(height: 8),
                    Text('Buat transaksi atau catat pengeluaran\nuntuk melihat laporan laba rugi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ringkasan Laba Rugi', style: Theme.of(context).textTheme.titleLarge),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.file_download),
                      label: const Text('Export Excel'),
                      onPressed: () async {
                        final List<List<dynamic>> data = [
                          ['Total Penjualan (Net)', totalRevenue.toInt()],
                          ['Harga Pokok Penjualan (HPP)', -totalCOGS.toInt()],
                          ['Laba Kotor (Gross Profit)', grossProfit.toInt()],
                          ['Total Pengeluaran Operasional', -totalExpenses.toInt()],
                          ['', ''],
                          ['LABA BERSIH (NET PROFIT)', netProfit.toInt()],
                        ];

                        if (expenses.isNotEmpty) {
                          data.add(['', '']);
                          data.add(['DETAIL PENGELUARAN', '']);
                          for (var exp in expenses) {
                            data.add([exp.category, -exp.amount.toInt()]);
                          }
                        }

                        final path = await ExportService.exportToExcel(
                          title: 'Laporan_Laba_Rugi',
                          data: data,
                          headers: ['Komponen Keuangan', 'Nilai (Rp)'],
                        );

                        if (path != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil diexport! File tersimpan/terunduh.')));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Revenue Card
                Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: Icon(Icons.trending_up, color: Colors.green.shade700, size: 32),
                    title: const Text('Total Penjualan (Net)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Subtotal - Diskon (Tanpa PPN)', style: TextStyle(fontSize: 12)),
                    trailing: Text('Rp ${formatter.format(totalRevenue.toInt())}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ),
                ),
                const SizedBox(height: 8),

                // COGS Card
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: Icon(Icons.inventory, color: Colors.orange.shade700, size: 32),
                    title: const Text('Harga Pokok Penjualan (HPP)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Total Harga Modal Barang', style: TextStyle(fontSize: 12)),
                    trailing: Text('- Rp ${formatter.format(totalCOGS.toInt())}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                  ),
                ),
                const SizedBox(height: 8),

                // Gross Profit
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Laba Kotor (Gross Profit)', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Rp ${formatter.format(grossProfit.toInt())}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(thickness: 1),
                const SizedBox(height: 8),

                // Expense Card
                Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: Icon(Icons.trending_down, color: Colors.red.shade700, size: 32),
                    title: const Text('Total Pengeluaran Operasional', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('- Rp ${formatter.format(totalExpenses.toInt())}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ),
                ),
                const SizedBox(height: 8),

                // Divider
                const Divider(thickness: 2),
                const SizedBox(height: 8),

                // Net Profit Card
                Card(
                  color: netProfit >= 0 ? Colors.blue.shade50 : Colors.red.shade50,
                  child: ListTile(
                    leading: Icon(
                      netProfit >= 0 ? Icons.account_balance_wallet : Icons.warning_amber,
                      color: netProfit >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
                      size: 32,
                    ),
                    title: Text(netProfit >= 0 ? 'Laba Bersih (Net Profit)' : 'Rugi Bersih', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(
                      'Rp ${formatter.format(netProfit.abs().toInt())}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: netProfit >= 0 ? Colors.blue.shade700 : Colors.orange.shade700),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Detail Pengeluaran
                if (expenses.isNotEmpty) ...[
                  Text('Detail Pengeluaran', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...expenses.map((exp) {
                    final date = DateFormat('dd MMM yyyy').format(exp.date);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Icon(Icons.receipt_outlined, color: Colors.red.shade700, size: 20),
                        ),
                        title: Text(exp.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${exp.notes ?? '-'} • $date', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        trailing: Text('- Rp ${formatter.format(exp.amount.toInt())}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

// ==================== REUSABLE CARD ====================
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _InfoCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
