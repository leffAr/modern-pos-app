import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';

import '../../pos/data/receipt_printer_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userRole;
  final String userName;
  const DashboardScreen({super.key, this.userRole = 'Admin', this.userName = 'Admin Utama'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Stream<List<drift.TypedResult>> _dashboardDataStream;
  String _selectedFilter = 'Hari Ini';

  @override
  void initState() {
    super.initState();
    _dashboardDataStream = (appDb.select(appDb.transactions).join([ 
      drift.leftOuterJoin(appDb.payments, appDb.payments.transactionId.equalsExp(appDb.transactions.id)),
      drift.leftOuterJoin(appDb.users, appDb.users.id.equalsExp(appDb.transactions.userId))
    ])..orderBy([drift.OrderingTerm(expression: appDb.transactions.createdAt, mode: drift.OrderingMode.desc)])).watch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<List<drift.TypedResult>>(
        stream: _dashboardDataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allTxResults = snapshot.data ?? [];
          
          final now = DateTime.now();
          DateTime startDate;
          DateTime endDate;
          if (_selectedFilter == 'Hari Ini') {
            startDate = DateTime(now.year, now.month, now.day);
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          } else if (_selectedFilter == 'Kemarin') {
            final y = now.subtract(const Duration(days: 1));
            startDate = DateTime(y.year, y.month, y.day);
            endDate = DateTime(y.year, y.month, y.day, 23, 59, 59);
          } else if (_selectedFilter == '7 Hari Terakhir') {
            startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          } else if (_selectedFilter == '30 Hari Terakhir') {
            startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
            endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          } else {
            startDate = DateTime(2000);
            endDate = DateTime(2100);
          }

          final filteredResults = allTxResults.where((r) {
            final tx = r.readTable(appDb.transactions);
            return tx.createdAt.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                   tx.createdAt.isBefore(endDate.add(const Duration(seconds: 1)));
          }).toList();

          double totalRevenue = 0;
          double totalPiutang = 0;

          // Group per Kasir
          final Map<String, Map<String, dynamic>> cashierPerformance = {};

          for (var r in filteredResults) {
            final tx = r.readTable(appDb.transactions);
            final payment = r.readTableOrNull(appDb.payments);
            final isKasbon = payment?.method == 'KASBON';
            
            if (isKasbon) {
              totalPiutang += tx.grandTotal;
            } else {
              totalRevenue += tx.grandTotal;
            }
            
            final user = r.readTableOrNull(appDb.users);
            final name = user?.name ?? tx.userId;
            
            if (!cashierPerformance.containsKey(name)) {
              cashierPerformance[name] = {'count': 0, 'revenue': 0.0, 'piutang': 0.0};
            }
            cashierPerformance[name]!['count'] = cashierPerformance[name]!['count'] + 1;
            if (isKasbon) {
              cashierPerformance[name]!['piutang'] = cashierPerformance[name]!['piutang'] + tx.grandTotal;
            } else {
              cashierPerformance[name]!['revenue'] = cashierPerformance[name]!['revenue'] + tx.grandTotal;
            }
          }

          final average = filteredResults.isEmpty ? 0.0 : totalRevenue / filteredResults.length;

          return StreamBuilder<List<Expense>>(
            stream: appDb.select(appDb.expenses).watch(),
            builder: (context, expSnapshot) {
              return StreamBuilder<List<DebtPayment>>(
                stream: appDb.select(appDb.debtPayments).watch(),
                builder: (context, dpSnapshot) {
                  final allExpenses = expSnapshot.data ?? [];
                  final filteredExpenses = allExpenses.where((e) => 
                    e.date.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                    e.date.isBefore(endDate.add(const Duration(seconds: 1)))
                  ).toList();

                  final allDebtPayments = dpSnapshot.data ?? [];
                  final filteredDebtPayments = allDebtPayments.where((dp) => 
                    dp.date.isAfter(startDate.subtract(const Duration(seconds: 1))) && 
                    dp.date.isBefore(endDate.add(const Duration(seconds: 1)))
                  ).toList();

                  double totalDebtPayments = 0;
                  for (var dp in filteredDebtPayments) {
                    totalDebtPayments += dp.amount;
                  }

                  double finalTotalPiutang = totalPiutang - totalDebtPayments;
                  if (finalTotalPiutang < 0) finalTotalPiutang = 0;

                  // Pembayaran piutang harus masuk ke Pendapatan
                  double finalTotalRevenue = totalRevenue + totalDebtPayments;
                  
                  final totalExpense = filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
                  final netProfit = finalTotalRevenue - totalExpense;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeHeader(context, finalTotalRevenue),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCards(
                            context: context, 
                            revenue: finalTotalRevenue, 
                            txCount: filteredResults.length, 
                            avg: average, 
                            netProfit: netProfit,
                            expense: totalExpense,
                            piutang: finalTotalPiutang,
                          ),
                
                if (widget.userRole == 'Admin') ...[
                  const SizedBox(height: 32),
                  const Text('Performa Kasir (Sesuai Filter)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 16),
                  _buildCashierPerformanceCard(cashierPerformance),

                  const SizedBox(height: 32),
                  const Text('Peringatan Stok Tipis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 16),
                  _buildLowStockAlert(),
                ],

                const SizedBox(height: 32),
                const Text('Histori Transaksi Terkini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const SizedBox(height: 16),
                _buildRecentTransactions(filteredResults),
                    ],
                  ),
                ),
              ],
            ),
          );
         },
        );
       },
      );
     },
    ),
   );
  }

  Widget _buildWelcomeHeader(BuildContext context, double revenue) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 24 : 56, isMobile ? 16 : 24, 24),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Halo, ${widget.userName}',
                  style: TextStyle(fontSize: isMobile ? 22 : 32, fontWeight: FontWeight.w800, color: const Color(0xFF111827), letterSpacing: -1.0),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: Color(0xFF4B5563)),
                    onPressed: () => _showPrintReportDialog(context),
                    tooltip: 'Cetak Laporan',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.sync_outlined, color: Color(0xFF4B5563)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sinkronisasi ke server...')));
                    },
                    tooltip: 'Sync Offline Data',
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Ikhtisar performa:', style: TextStyle(fontSize: 16, color: Color(0xFF6B7280))),
              const SizedBox(width: 12),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFilter = val);
                    },
                    items: ['Hari Ini', 'Kemarin', '7 Hari Terakhir', '30 Hari Terakhir', 'Semua Waktu']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards({
    required BuildContext context, 
    required double revenue, 
    required int txCount,
    required double avg,
    required double netProfit,
    required double expense,
    required double piutang,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1000;
    final crossAxisCount = isMobile ? 2 : (isTablet ? 4 : 4);
    final formatter = NumberFormat('#,###', 'id_ID');

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.3 : 1.8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard(title: 'Pendapatan', value: 'Rp ${formatter.format(revenue.toInt())}', icon: Icons.attach_money, color: Colors.green),
        _SummaryCard(title: 'Piutang (Kasbon)', value: 'Rp ${formatter.format(piutang.toInt())}', icon: Icons.money_off, color: Colors.orange),
        _SummaryCard(title: 'Pengeluaran', value: 'Rp ${formatter.format(expense.toInt())}', icon: Icons.trending_down, color: Colors.red),
        _SummaryCard(title: 'Laba Bersih', value: 'Rp ${formatter.format(netProfit.toInt())}', icon: Icons.savings, color: Colors.blue),
      ],
    );
  }

  Widget _buildLowStockAlert() {
    return StreamBuilder<List<drift.TypedResult>>(
      stream: (appDb.select(appDb.inventory).join([
        drift.innerJoin(appDb.products, appDb.products.id.equalsExp(appDb.inventory.productId))
      ])..where(appDb.inventory.stock.isSmallerOrEqual(appDb.inventory.minimumStock))).watch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final results = snapshot.data!;
        if (results.isEmpty) {
          return Card(
            color: Colors.green.shade50,
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('Semua stok produk aman.', style: TextStyle(color: Colors.green))),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = results[index];
              final product = item.readTable(appDb.products);
              final inv = item.readTable(appDb.inventory);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  ),
                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('SKU: ${product.sku ?? '-'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sisa: ${inv.stock}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions(List<drift.TypedResult> results) {
    if (results.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('Belum ada transaksi sama sekali.')),
        ),
      );
    }

    final displayTxs = results.take(10).toList(); // Ambil 10 terbaru
    final formatter = NumberFormat('#,###', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayTxs.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (context, index) {
          final row = displayTxs[index];
          final tx = row.readTable(appDb.transactions);
          final payment = row.readTableOrNull(appDb.payments);
          final user = row.readTableOrNull(appDb.users);
          final cashierName = user?.name ?? tx.userId;
          final isKasbon = payment?.method == 'KASBON';
          
          final hour = tx.createdAt.hour.toString().padLeft(2, '0');
          final minute = tx.createdAt.minute.toString().padLeft(2, '0');

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isKasbon ? Colors.orange : Colors.blueAccent).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long, color: isKasbon ? Colors.orange : Colors.blueAccent, size: 20),
              ),
              title: Text(tx.receiptNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Oleh: $cashierName • $hour:$minute', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  if (tx.discount > 0 || tx.pointsUsed > 0)
                    Text(
                      [
                        if (tx.discount > 0) 'Diskon Promo',
                        if (tx.pointsUsed > 0) 'Poin Dipakai'
                      ].join(' & '),
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
                  Text(
                    'Rp ${formatter.format(tx.grandTotal.toInt())}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isKasbon ? Colors.orange : Colors.green),
                  ),
                  if (isKasbon)
                    const Text('KASBON', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCashierPerformanceCard(Map<String, Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text('Belum ada transaksi hari ini.', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      );
    }
    
    final formatter = NumberFormat('#,###', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
        columns: const [
          DataColumn(label: Text('Nama Kasir', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Jml Transaksi', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pendapatan', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Piutang (Kasbon)', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: data.entries.map((entry) {
          final count = entry.value['count'] as int;
          final revenue = entry.value['revenue'] as double;
          final piutang = entry.value['piutang'] as double;
          return DataRow(cells: [
            DataCell(Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text('$count')),
            DataCell(Text('Rp ${formatter.format(revenue.toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
            DataCell(Text('Rp ${formatter.format(piutang.toInt())}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))),
          ]);
        }).toList(),
      ),
      ),
    );
  }

  Future<void> _showPrintReportDialog(BuildContext context) async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      }
    );

    if (pickedRange != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyusun Laporan...')));
        
        // Prepare range
        final start = DateTime(pickedRange.start.year, pickedRange.start.month, pickedRange.start.day, 0, 0, 0);
        final end = DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day, 23, 59, 59);

        // Fetch Transactions
        final txs = await (appDb.select(appDb.transactions)..where((t) => t.createdAt.isBetweenValues(start, end) & t.status.equals('COMPLETED'))).get();
        
        final payments = await (appDb.select(appDb.payments).join([
           drift.innerJoin(appDb.transactions, appDb.transactions.id.equalsExp(appDb.payments.transactionId))
        ])..where(
          appDb.transactions.createdAt.isBetweenValues(start, end) & appDb.transactions.status.equals('COMPLETED')
        )).get();

        double grossSales = 0;
        double discounts = 0;
        double netSales = 0;
        double totalCash = 0;
        double totalQris = 0;
        double totalKasbon = 0;

        for (var t in txs) {
          final pRow = payments.where((p) => p.readTable(appDb.payments).transactionId == t.id).firstOrNull;
          if (pRow != null) {
            final payment = pRow.readTable(appDb.payments);
            final isKasbon = payment.method == 'KASBON';
            
            if (isKasbon) {
              totalKasbon += t.grandTotal;
            } else {
              grossSales += t.subtotal;
              discounts += t.discount;
              netSales += t.grandTotal;
              
              if (payment.method == 'CASH') {
                 totalCash += t.grandTotal;
              } else if (payment.method == 'QRIS') {
                 totalQris += t.grandTotal;
              }
            }
          }
        }

        // Top products
        final items = await (appDb.select(appDb.transactionItems).join([
          drift.innerJoin(appDb.transactions, appDb.transactions.id.equalsExp(appDb.transactionItems.transactionId)),
          drift.innerJoin(appDb.products, appDb.products.id.equalsExp(appDb.transactionItems.productId)),
        ])..where(appDb.transactions.createdAt.isBetweenValues(start, end))).get();

        Map<String, Map<String, dynamic>> productStats = {};
        for (var row in items) {
           final prod = row.readTable(appDb.products);
           final itm = row.readTable(appDb.transactionItems);
           if (!productStats.containsKey(prod.name)) {
             productStats[prod.name] = {'name': prod.name, 'unit': prod.unit, 'qty': 0, 'total': 0.0};
           }
           productStats[prod.name]!['qty'] += itm.quantity;
           productStats[prod.name]!['total'] += itm.subtotal;
        }

        final topProducts = productStats.values.toList();
        topProducts.sort((a, b) => (b['qty'] as num).compareTo(a['qty'] as num));

        // Get Business Profile
        final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull() ?? 
                      const Business(id: 'BIZ-1', name: 'MODERN POS', address: '', phone: '', logoBase64: null, taxPercentage: 0.0, enableTableNumber: false, enableQueueNumber: false);

        // Fetch Expenses
        final exps = await (appDb.select(appDb.expenses)..where((e) => e.date.isBetweenValues(start, end))).get();
        double totalExpenses = 0;
        for (var e in exps) {
          totalExpenses += e.amount;
        }

        // Fetch Debt Payments
        final dps = await (appDb.select(appDb.debtPayments)..where((d) => d.date.isBetweenValues(start, end))).get();
        double totalDebtPayments = 0;
        for (var dp in dps) {
          totalDebtPayments += dp.amount;
        }

        totalKasbon -= totalDebtPayments;
        if (totalKasbon < 0) totalKasbon = 0;

        netSales += totalDebtPayments;
        totalCash += totalDebtPayments; // Diasumsikan tunai

        double finalNetProfit = netSales - totalExpenses;

        await ReceiptPrinterService.printAdminReport(
          business: business,
          startDate: start,
          endDate: end,
          totalGrossSales: grossSales,
          totalDiscounts: discounts,
          totalNetSales: netSales,
          totalExpenses: totalExpenses,
          finalNetProfit: finalNetProfit,
          totalCash: totalCash,
          totalQris: totalQris,
          totalKasbon: totalKasbon,
          totalTransactions: txs.length,
          topProducts: topProducts,
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500))),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
          ),
        ],
      ),
    );
  }
}

