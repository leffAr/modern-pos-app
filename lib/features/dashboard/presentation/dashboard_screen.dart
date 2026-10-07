import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:fl_chart/fl_chart.dart';
import '../../../core/database/database.dart';
import '../../../core/state/report_filter_state.dart';

import '../../pos/data/receipt_printer_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userRole;
  final String userName;
  const DashboardScreen(
      {super.key, this.userRole = 'Admin', this.userName = 'Admin Utama'});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Stream<List<drift.TypedResult>> _dashboardDataStream;
  late Stream<List<Expense>> _expensesStream;
  late Stream<List<DebtPayment>> _debtPaymentsStream;
  late Stream<List<drift.TypedResult>> _lowStockStream;

  @override
  void initState() {
    super.initState();
    ReportFilterState.instance.addListener(_onFilterChanged);
    _dashboardDataStream = (appDb.select(appDb.transactions).join([
      drift.leftOuterJoin(appDb.payments,
          appDb.payments.transactionId.equalsExp(appDb.transactions.id)),
      drift.leftOuterJoin(
          appDb.users, appDb.users.id.equalsExp(appDb.transactions.userId))
    ])
          ..orderBy([
            drift.OrderingTerm(
                expression: appDb.transactions.createdAt,
                mode: drift.OrderingMode.desc)
          ]))
        .watch();

    _expensesStream = appDb.select(appDb.expenses).watch();
    _debtPaymentsStream = appDb.select(appDb.debtPayments).watch();
    _lowStockStream = (appDb.select(appDb.inventory).join([
      drift.innerJoin(appDb.products,
          appDb.products.id.equalsExp(appDb.inventory.productId))
    ])
          ..where(drift.CustomExpression<bool>(
              'inventory.stock <= inventory.minimum_stock')))
        .watch();
  }

  @override
  void dispose() {
    ReportFilterState.instance.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
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

          final range = ReportFilterState.instance.dateRange;
          final filteredResults = allTxResults.where((r) {
            if (range == null) return true;
            final tx = r.readTable(appDb.transactions);
            final start = range.start;
            final end = range.end.add(const Duration(days: 1));
            return (tx.createdAt.isAfter(start) ||
                    tx.createdAt.isAtSameMomentAs(start)) &&
                tx.createdAt.isBefore(end);
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
              cashierPerformance[name] = {
                'count': 0,
                'revenue': 0.0,
                'piutang': 0.0
              };
            }
            cashierPerformance[name]!['count'] =
                cashierPerformance[name]!['count'] + 1;
            if (isKasbon) {
              cashierPerformance[name]!['piutang'] =
                  cashierPerformance[name]!['piutang'] + tx.grandTotal;
            } else {
              cashierPerformance[name]!['revenue'] =
                  cashierPerformance[name]!['revenue'] + tx.grandTotal;
            }
          }

          final average = filteredResults.isEmpty
              ? 0.0
              : totalRevenue / filteredResults.length;

          return StreamBuilder<List<Expense>>(
            stream: _expensesStream,
            builder: (context, expSnapshot) {
              return StreamBuilder<List<DebtPayment>>(
                stream: _debtPaymentsStream,
                builder: (context, dpSnapshot) {
                  final allExpenses = expSnapshot.data ?? [];
                  final filteredExpenses = allExpenses.where((e) {
                    if (range == null) return true;
                    final start = range.start;
                    final end = range.end.add(const Duration(days: 1));
                    return (e.date.isAfter(start) ||
                            e.date.isAtSameMomentAs(start)) &&
                        e.date.isBefore(end);
                  }).toList();

                  final allDebtPayments = dpSnapshot.data ?? [];
                  final filteredDebtPayments = allDebtPayments.where((dp) {
                    if (range == null) return true;
                    final start = range.start;
                    final end = range.end.add(const Duration(days: 1));
                    return (dp.date.isAfter(start) ||
                            dp.date.isAtSameMomentAs(start)) &&
                        dp.date.isBefore(end);
                  }).toList();

                  double totalDebtPayments = 0;
                  for (var dp in filteredDebtPayments) {
                    totalDebtPayments += dp.amount;
                  }

                  double finalTotalPiutang = totalPiutang - totalDebtPayments;
                  if (finalTotalPiutang < 0) finalTotalPiutang = 0;

                  // Pembayaran piutang harus masuk ke Pendapatan
                  double finalTotalRevenue = totalRevenue + totalDebtPayments;

                  final totalExpense =
                      filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
                  final netProfit = finalTotalRevenue - totalExpense;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWelcomeHeader(context, finalTotalRevenue),
                        Transform.translate(
                          offset: const Offset(0, -32),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                                  _buildSalesChart(filteredResults, range),
                                  const SizedBox(height: 32),
                                  const Text('Performa Kasir (Sesuai Filter)',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF111827))),
                                  const SizedBox(height: 16),
                                  _buildCashierPerformanceCard(
                                      cashierPerformance),
                                  const SizedBox(height: 32),
                                  const Text('Peringatan Stok Tipis',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red)),
                                  const SizedBox(height: 16),
                                  _buildLowStockAlert(),
                                ],
                                const SizedBox(height: 32),
                                const Text('Histori Transaksi Terkini',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827))),
                                const SizedBox(height: 16),
                                _buildRecentTransactions(filteredResults),
                              ],
                            ),
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
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24, isMobile ? 32 : 56, isMobile ? 16 : 24, 72),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0056D2), Color(0xFF009DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      'Selamat Datang,',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade100,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userName,
                      style: TextStyle(
                          fontSize: isMobile ? 26 : 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5),
                    ),
                  ])),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: IconButton(
                      icon:
                          const Icon(Icons.print_outlined, color: Colors.white),
                      onPressed: () => _showPrintReportDialog(context),
                      tooltip: 'Cetak Laporan',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle),
                    child: IconButton(
                      icon:
                          const Icon(Icons.sync_outlined, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Sinkronisasi ke server...')));
                      },
                      tooltip: 'Sync Offline Data',
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF007BFF),
                    value: ReportFilterState.availableFilters
                            .contains(ReportFilterState.instance.currentFilter)
                        ? ReportFilterState.instance.currentFilter
                        : null,
                    hint: Text(
                      ReportFilterState.instance.displayLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        size: 14, color: Colors.white),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    onChanged: (val) {
                      if (val != null) {
                        ReportFilterState.instance.setFilter(val);
                      }
                    },
                    items: ReportFilterState.availableFilters
                        .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e,
                                style: const TextStyle(color: Colors.white))))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(List<drift.TypedResult> txs, DateTimeRange? range) {
    if (txs.isEmpty) return const SizedBox();

    bool isSingleDay = true;
    if (range != null) {
      if (range.start.year != range.end.year ||
          range.start.month != range.end.month ||
          range.start.day != range.end.day) {
        isSingleDay = false;
      }
    } else {
      isSingleDay = false;
    }

    // Grouping
    Map<DateTime, double> dateGrouped = {};
    for (var r in txs) {
      final t = r.readTable(appDb.transactions);
      final date = t.createdAt;
      DateTime key;
      if (isSingleDay) {
        key = DateTime(date.year, date.month, date.day, date.hour);
      } else {
        key = DateTime(date.year, date.month, date.day);
      }
      dateGrouped[key] = (dateGrouped[key] ?? 0) + t.grandTotal;
    }

    final sortedKeys = dateGrouped.keys.toList()..sort();
    final displayKeys = sortedKeys.length > 14
        ? sortedKeys.sublist(sortedKeys.length - 14)
        : sortedKeys;

    double maxY = 0;
    for (var k in displayKeys) {
      if (dateGrouped[k]! > maxY) maxY = dateGrouped[k]!;
    }
    if (maxY == 0) maxY = 10000;

    final formatter =
        NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);

    return LayoutBuilder(builder: (context, constraints) {
      List<FlSpot> spots = [];
      int xIndex = 0;

      for (var k in displayKeys) {
        final val = dateGrouped[k]!;
        spots.add(FlSpot(xIndex.toDouble(), val));
        xIndex++;
      }

      return Container(
        child: AspectRatio(
          aspectRatio: constraints.maxWidth < 600 ? 1.2 : 2.5,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.show_chart,
                          color: Colors.blueAccent, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            isSingleDay
                                ? 'Tren Penjualan (Per Jam)'
                                : 'Tren Penjualan (Per Hari)',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text('Analisis performa pendapatan',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (displayKeys.length - 1).toDouble() > 0
                          ? (displayKeys.length - 1).toDouble()
                          : 1,
                      minY: 0,
                      maxY: maxY * 1.2,
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) =>
                              Colors.blueGrey.shade900.withValues(alpha: 0.95),
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          tooltipMargin: 8,
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              if (index < 0 || index >= displayKeys.length)
                                return null;
                              final k = displayKeys[index];
                              final label = isSingleDay
                                  ? '${k.hour.toString().padLeft(2, '0')}:00'
                                  : DateFormat('dd MMM yyyy').format(k);
                              final val = formatter.format(spot.y);
                              return LineTooltipItem(
                                '$label\n',
                                const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500),
                                children: [
                                  TextSpan(
                                    text: val,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: 0.5),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value == 0 || value == meta.max)
                                return const SizedBox.shrink();
                              String text = '';
                              if (value >= 1000000) {
                                text =
                                    '${(value / 1000000).toStringAsFixed(1)}Jt';
                              } else if (value >= 1000) {
                                text = '${(value / 1000).toStringAsFixed(0)}K';
                              } else {
                                text = value.toStringAsFixed(0);
                              }
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(text,
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 ||
                                  index >= displayKeys.length ||
                                  value != index.toDouble())
                                return const SizedBox.shrink();
                              final k = displayKeys[index];
                              final text = isSingleDay
                                  ? '${k.hour.toString().padLeft(2, '0')}:00'
                                  : DateFormat('dd/MM').format(k);
                              return SideTitleWidget(
                                meta: meta,
                                space: 8,
                                child: Text(text,
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade100,
                            strokeWidth: 1.5,
                            dashArray: [6, 4]),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: false, // Diubah menjadi false agar zigzag
                          color: const Color(0xFF3B82F6),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: const Color(0xFF3B82F6),
                                );
                              }),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                const Color(0xFF3B82F6).withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
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
    final isTablet = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1000;
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
        _SummaryCard(
            title: 'Pendapatan',
            value: 'Rp ${formatter.format(revenue.toInt())}',
            icon: Icons.attach_money,
            color: Colors.green),
        _SummaryCard(
            title: 'Piutang (Kasbon)',
            value: 'Rp ${formatter.format(piutang.toInt())}',
            icon: Icons.money_off,
            color: Colors.orange),
        _SummaryCard(
            title: 'Pengeluaran',
            value: 'Rp ${formatter.format(expense.toInt())}',
            icon: Icons.trending_down,
            color: Colors.red),
        _SummaryCard(
            title: 'Laba Bersih',
            value: 'Rp ${formatter.format(netProfit.toInt())}',
            icon: Icons.savings,
            color: Colors.blue),
      ],
    );
  }

  Widget _buildLowStockAlert() {
    return StreamBuilder<List<drift.TypedResult>>(
      stream: _lowStockStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final results = snapshot.data!;
        if (results.isEmpty) {
          return Card(
            color: Colors.green.shade50,
            child: const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                  child: Text('Semua stok produk aman.',
                      style: TextStyle(color: Colors.green))),
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
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey.shade100),
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
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 20),
                  ),
                  title: Text(product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  subtitle: Text('SKU: ${product.sku ?? '-'}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sisa: ${inv.stock}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.red),
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
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade100),
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
                  color: (isKasbon ? Colors.orange : Colors.blueAccent)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long,
                    color: isKasbon ? Colors.orange : Colors.blueAccent,
                    size: 20),
              ),
              title: Text(tx.receiptNumber,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Oleh: $cashierName • $hour:$minute',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  if (tx.discount > 0 || tx.pointsUsed > 0)
                    Text(
                      [
                        if (tx.discount > 0) 'Diskon Promo',
                        if (tx.pointsUsed > 0) 'Poin Dipakai'
                      ].join(' & '),
                      style: const TextStyle(
                          color: Colors.purple,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
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
                      style: const TextStyle(
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey),
                    ),
                  Text(
                    'Rp ${formatter.format(tx.grandTotal.toInt())}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isKasbon ? Colors.orange : Colors.green),
                  ),
                  if (isKasbon)
                    const Text('KASBON',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold)),
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Center(
            child: Text('Belum ada transaksi hari ini.',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        ),
      );
    }

    final formatter = NumberFormat('#,###', 'id_ID');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 56,
          dataRowMaxHeight: 70,
          dataRowMinHeight: 70,
          headingTextStyle: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5),
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF9FAFB)),
          dividerThickness: 1,
          columns: const [
            DataColumn(label: Text('KASIR')),
            DataColumn(label: Text('TRANSAKSI')),
            DataColumn(label: Text('PENDAPATAN')),
            DataColumn(label: Text('KASBON')),
          ],
          rows: data.entries.map((entry) {
            final count = entry.value['count'] as int;
            final revenue = entry.value['revenue'] as double;
            final piutang = entry.value['piutang'] as double;

            return DataRow(cells: [
              DataCell(Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Text(entry.key.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.key,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF111827))),
                ],
              )),
              DataCell(Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700)),
              )),
              DataCell(Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Rp ${formatter.format(revenue.toInt())}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.green)),
              )),
              DataCell(piutang > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Rp ${formatter.format(piutang.toInt())}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.orange)),
                    )
                  : const Text('-',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.w500))),
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
        });

    if (pickedRange != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Menyusun Laporan...')));

        // Prepare range
        final start = DateTime(pickedRange.start.year, pickedRange.start.month,
            pickedRange.start.day, 0, 0, 0);
        final end = DateTime(pickedRange.end.year, pickedRange.end.month,
            pickedRange.end.day, 23, 59, 59);

        // Fetch Transactions
        final txs = await (appDb.select(appDb.transactions)
              ..where((t) =>
                  t.createdAt.isBetweenValues(start, end) &
                  t.status.equals('COMPLETED')))
            .get();

        final payments = await (appDb.select(appDb.payments).join([
          drift.innerJoin(appDb.transactions,
              appDb.transactions.id.equalsExp(appDb.payments.transactionId))
        ])
              ..where(appDb.transactions.createdAt.isBetweenValues(start, end) &
                  appDb.transactions.status.equals('COMPLETED')))
            .get();

        double grossSales = 0;
        double discounts = 0;
        double netSales = 0;
        double totalCash = 0;
        double totalQris = 0;
        double totalKasbon = 0;

        for (var t in txs) {
          final pRow = payments
              .where((p) => p.readTable(appDb.payments).transactionId == t.id)
              .firstOrNull;
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
          drift.innerJoin(
              appDb.transactions,
              appDb.transactions.id
                  .equalsExp(appDb.transactionItems.transactionId)),
          drift.innerJoin(appDb.products,
              appDb.products.id.equalsExp(appDb.transactionItems.productId)),
        ])
              ..where(appDb.transactions.createdAt.isBetweenValues(start, end)))
            .get();

        Map<String, Map<String, dynamic>> productStats = {};
        for (var row in items) {
          final prod = row.readTable(appDb.products);
          final itm = row.readTable(appDb.transactionItems);
          if (!productStats.containsKey(prod.name)) {
            productStats[prod.name] = {
              'name': prod.name,
              'unit': prod.unit,
              'qty': 0,
              'total': 0.0
            };
          }
          productStats[prod.name]!['qty'] += itm.quantity;
          productStats[prod.name]!['total'] += itm.subtotal;
        }

        final topProducts = productStats.values.toList();
        topProducts
            .sort((a, b) => (b['qty'] as num).compareTo(a['qty'] as num));

        // Get Business Profile
        final business = await (appDb.select(appDb.businesses)..limit(1))
                .getSingleOrNull() ??
            const Business(
                id: 'BIZ-1',
                name: 'MODERN POS',
                address: '',
                phone: '',
                logoBase64: null,
                taxPercentage: 0.0,
                enableTableNumber: false,
                enableQueueNumber: false);

        // Fetch Expenses
        final exps = await (appDb.select(appDb.expenses)
              ..where((e) => e.date.isBetweenValues(start, end)))
            .get();
        double totalExpenses = 0;
        for (var e in exps) {
          totalExpenses += e.amount;
        }

        // Fetch Debt Payments
        final dps = await (appDb.select(appDb.debtPayments)
              ..where((d) => d.date.isBetweenValues(start, end)))
            .get();
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
        borderRadius: BorderRadius.circular(6),
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
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500))),
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
            child: Text(value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827))),
          ),
        ],
      ),
    );
  }
}
