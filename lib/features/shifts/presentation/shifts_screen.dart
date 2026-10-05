import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../../../core/state/report_filter_state.dart';
import '../../reports/data/export_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../pos/data/receipt_printer_service.dart';

class ShiftsScreen extends StatefulWidget {
  final String userRole;
  final String userName;
  const ShiftsScreen({super.key, required this.userRole, required this.userName});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final _openCashCtrl = TextEditingController();
  final _closeCashCtrl = TextEditingController();
  String _selectedShiftName = 'Shift 1';

  Stream<List<Shift>>? _adminShiftsStream;
  Stream<List<Shift>>? _cashierShiftsStream;
  String? _actualUserId;
  bool _isLoadingCashier = true;

  @override
  void initState() {
    super.initState();
    ReportFilterState.instance.addListener(_onFilterChanged);
    if (widget.userRole == 'Admin') {
      _adminShiftsStream = (appDb.select(appDb.shifts)..orderBy([(t) => drift.OrderingTerm.desc(t.openedAt)])).watch();
    } else {
      _loadCashierData();
    }
  }

  void _onFilterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCashierData() async {
    final user = await (appDb.select(appDb.users)..where((u) => u.name.equals(widget.userName))).getSingleOrNull();
    if (mounted) {
      setState(() {
        _actualUserId = user?.id ?? "U-1";
        _cashierShiftsStream = (appDb.select(appDb.shifts)..where((t) => t.status.equals('OPEN') & t.userId.equals(_actualUserId!))..limit(1)).watch();
        _isLoadingCashier = false;
      });
    }
  }

  @override
  void dispose() {
    ReportFilterState.instance.removeListener(_onFilterChanged);
    _openCashCtrl.dispose();
    _closeCashCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportShiftsPdf(BuildContext context) async {
    final range = ReportFilterState.instance.dateRange;
    final allShifts = await (appDb.select(appDb.shifts)..orderBy([(t) => drift.OrderingTerm.desc(t.openedAt)])).get();

    final filteredShifts = allShifts.where((s) {
      if (range == null) return true;
      final start = range.start;
      final end = range.end.add(const Duration(days: 1));
      return (s.openedAt.isAfter(start) || s.openedAt.isAtSameMomentAs(start)) && s.openedAt.isBefore(end);
    }).toList();

    if (filteredShifts.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada data shift pada periode ini untuk diexport!')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menyiapkan file PDF Laporan Shift...')),
      );
    }

    final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull() ??
        const Business(
          id: 'BIZ-1',
          name: 'MODERN POS',
          address: '',
          phone: '',
          logoBase64: null,
          taxPercentage: 0.0,
          enableTableNumber: false,
          enableQueueNumber: false,
        );

    final allUsers = await appDb.select(appDb.users).get();
    final userMap = {for (var u in allUsers) u.id: u.name};

    double totalOpeningCash = 0;
    double totalClosingCash = 0;
    double totalVariance = 0;

    final List<List<String>> tableData = [];

    for (var shift in filteredShifts) {
      final isClosed = shift.status == 'CLOSED';
      double selisih = 0;
      if (isClosed && shift.closingCash != null && shift.expectedCash != null) {
        selisih = shift.closingCash! - shift.expectedCash!;
      }

      totalOpeningCash += shift.openingCash;
      if (shift.closingCash != null) {
        totalClosingCash += shift.closingCash!;
      }
      totalVariance += selisih;

      final cashierName = userMap[shift.userId] ?? shift.userId;
      final openedStr = DateFormat('dd/MM HH:mm').format(shift.openedAt);
      final closedStr = shift.closedAt != null ? DateFormat('dd/MM HH:mm').format(shift.closedAt!) : '-';
      final openCashStr = 'Rp ${formatter.format(shift.openingCash.toInt())}';
      final closeCashStr = shift.closingCash != null ? 'Rp ${formatter.format(shift.closingCash!.toInt())}' : '-';
      final selisihStr = !isClosed
          ? 'Berlangsung'
          : (selisih == 0 ? 'Sesuai' : (selisih > 0 ? '+Rp ${formatter.format(selisih.toInt())}' : '-Rp ${formatter.format(selisih.abs().toInt())}'));

      tableData.add([
        shift.shiftName,
        cashierName,
        openedStr,
        closedStr,
        openCashStr,
        closeCashStr,
        selisihStr,
        isClosed ? 'Ditutup' : 'Buka',
      ]);
    }

    await ExportService.exportShiftReportPdf(
      businessName: business.name,
      period: ReportFilterState.instance.displayLabel,
      headers: ['Shift', 'Kasir', 'Buka', 'Tutup', 'Modal Awal', 'Kas Akhir', 'Selisih', 'Status'],
      data: tableData,
      totalShifts: filteredShifts.length,
      totalOpeningCash: totalOpeningCash,
      totalClosingCash: totalClosingCash,
      totalVariance: totalVariance,
    );
  }

  final formatter = NumberFormat('#,###', 'id_ID');

  @override
  Widget build(BuildContext context) {
    if (widget.userRole == 'Admin') {
      return _buildAdminView();
    } else {
      return _buildCashierView();
    }
  }

  Widget _buildAdminView() {
    final range = ReportFilterState.instance.dateRange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Shift & Kas'),
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Pilih Rentang Waktu',
              onSelected: (val) async {
                if (val == 'CUSTOM') {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: range ?? DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 30)),
                      end: DateTime.now(),
                    ),
                  );
                  if (picked != null) {
                    ReportFilterState.instance.setCustomRange(picked);
                  }
                } else {
                  ReportFilterState.instance.setFilter(val);
                }
              },
              itemBuilder: (context) => [
                ...ReportFilterState.availableFilters.map((f) => PopupMenuItem(
                  value: f,
                  child: Row(
                    children: [
                      Icon(
                        ReportFilterState.instance.currentFilter == f
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: ReportFilterState.instance.currentFilter == f ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        f,
                        style: TextStyle(
                          fontWeight: ReportFilterState.instance.currentFilter == f ? FontWeight.bold : FontWeight.normal,
                          color: ReportFilterState.instance.currentFilter == f ? Colors.blue : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                )),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'CUSTOM',
                  child: Row(
                    children: [
                      Icon(
                        ReportFilterState.instance.currentFilter == 'Kustom'
                            ? Icons.check_circle
                            : Icons.calendar_month,
                        size: 18,
                        color: ReportFilterState.instance.currentFilter == 'Kustom' ? Colors.blue : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ReportFilterState.instance.currentFilter == 'Kustom'
                            ? 'Kustom (${ReportFilterState.instance.displayLabel})'
                            : 'Pilih Tanggal Kustom...',
                        style: TextStyle(
                          fontWeight: ReportFilterState.instance.currentFilter == 'Kustom' ? FontWeight.bold : FontWeight.normal,
                          color: ReportFilterState.instance.currentFilter == 'Kustom' ? Colors.blue : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      ReportFilterState.instance.displayLabel,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Export Laporan Shift ke PDF',
            onPressed: () => _exportShiftsPdf(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Shift>>(
        stream: _adminShiftsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final allShifts = snapshot.data ?? [];

          final shifts = allShifts.where((s) {
            if (range == null) return true;
            final start = range.start;
            final end = range.end.add(const Duration(days: 1));
            return (s.openedAt.isAfter(start) || s.openedAt.isAtSameMomentAs(start)) && s.openedAt.isBefore(end);
          }).toList();
          
          if (shifts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data shift untuk periode ${ReportFilterState.instance.displayLabel}.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ubah periode tanggal di atas untuk melihat riwayat shift lainnya.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          double totalOpening = 0;
          double totalClosing = 0;
          double totalSelisih = 0;
          for (var s in shifts) {
            totalOpening += s.openingCash;
            if (s.closingCash != null) totalClosing += s.closingCash!;
            if (s.closingCash != null && s.expectedCash != null) {
              totalSelisih += (s.closingCash! - s.expectedCash!);
            }
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Periode: ${ReportFilterState.instance.displayLabel}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text('Ditemukan: ${shifts.length} sesi shift', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => _exportShiftsPdf(context),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Total Modal Awal', 'Rp ${formatter.format(totalOpening.toInt())}', Colors.blue.shade700),
                        _buildStatColumn('Total Fisik Akhir', 'Rp ${formatter.format(totalClosing.toInt())}', Colors.green.shade700),
                        _buildStatColumn(
                          'Total Selisih',
                          totalSelisih == 0
                              ? 'Rp 0'
                              : (totalSelisih > 0 ? '+Rp ${formatter.format(totalSelisih.toInt())}' : '-Rp ${formatter.format(totalSelisih.abs().toInt())}'),
                          totalSelisih == 0 ? Colors.green.shade700 : (totalSelisih > 0 ? Colors.blue.shade700 : Colors.red.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: shifts.length,
                  itemBuilder: (context, index) {
                    final shift = shifts[index];
                    final isClosed = shift.status == 'CLOSED';
                    
                    double selisih = 0;
                    if (isClosed && shift.closingCash != null && shift.expectedCash != null) {
                      selisih = shift.closingCash! - shift.expectedCash!;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: Icon(
                          isClosed ? Icons.lock : Icons.lock_open,
                          color: isClosed ? Colors.grey : Colors.green,
                        ),
                        title: Text('${shift.shiftName} - ${shift.userId} (${DateFormat('dd MMM, HH:mm').format(shift.openedAt)})'),
                        subtitle: Text(
                          isClosed 
                            ? (selisih == 0 ? 'Sesuai' : (selisih > 0 ? 'Lebih: Rp ${formatter.format(selisih.toInt())}' : 'Kurang: Rp ${formatter.format(selisih.abs().toInt())}'))
                            : 'Sedang Berlangsung',
                          style: TextStyle(
                            color: isClosed ? (selisih == 0 ? Colors.green : Colors.red) : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Kas Awal', 'Rp ${formatter.format(shift.openingCash)}'),
                                if (isClosed) ...[
                                  const Divider(),
                                  _buildDetailRow('Kas Akhir (Seharusnya)', 'Rp ${formatter.format(shift.expectedCash ?? 0)}'),
                                  _buildDetailRow('Kas Akhir (Fisik Laci)', 'Rp ${formatter.format(shift.closingCash ?? 0)}'),
                                  const SizedBox(height: 8),
                                  _buildDetailRow('Selisih', 'Rp ${formatter.format(selisih)}', color: selisih == 0 ? Colors.green : Colors.red),
                                  const SizedBox(height: 8),
                                  Text('Ditutup pada: ${DateFormat('dd MMM yyyy, HH:mm').format(shift.closedAt!)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.print, size: 18),
                                    label: const Text('Cetak Laporan Shift'),
                                    onPressed: () async {
                                      final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull() ?? 
                                         const Business(id: 'BIZ-1', name: 'MODERN POS', address: '', phone: '', logoBase64: null, taxPercentage: 0.0, enableTableNumber: false, enableQueueNumber: false);
                                      
                                      final kasirUser = await (appDb.select(appDb.users)..where((u) => u.id.equals(shift.userId))).getSingleOrNull();
                                      final cashierRealName = kasirUser?.name ?? shift.userId;

                                      await ReceiptPrinterService.printShiftReport(
                                        business: business,
                                        shiftName: shift.shiftName,
                                        cashierName: cashierRealName,
                                        openedAt: shift.openedAt,
                                        closedAt: shift.closedAt!,
                                        openingCash: shift.openingCash,
                                        totalCashSales: 0.0,
                                        totalQrisSales: 0.0,
                                        expectedCash: shift.expectedCash ?? 0.0,
                                        actualCash: shift.closingCash ?? 0.0,
                                        variance: selisih,
                                      );
                                    },
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildCashierView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Shift Kasir')),
      body: _isLoadingCashier 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<List<Shift>>(
            stream: _cashierShiftsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              final shifts = snapshot.data ?? [];
              if (shifts.isEmpty) {
                return _buildOpenShiftForm();
              } else {
                return _buildActiveShiftInfo(shifts.first);
              }
            },
          ),
    );
  }

  Widget _buildOpenShiftForm() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront, size: 64, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text('Buka Shift Baru', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Pilih Shift dan masukkan uang modal awal di laci kasir.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedShiftName,
                decoration: const InputDecoration(
                  labelText: 'Pilih Shift',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: const [
                  DropdownMenuItem(value: 'Shift 1', child: Text('Shift 1 (Pagi)')),
                  DropdownMenuItem(value: 'Shift 2', child: Text('Shift 2 (Siang)')),
                  DropdownMenuItem(value: 'Shift 3', child: Text('Shift 3 (Malam)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedShiftName = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _openCashCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Uang Kas Awal (Rp)',
                  prefixIcon: Icon(Icons.money),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    if (_openCashCtrl.text.isEmpty) return;
                    final cash = double.tryParse(_openCashCtrl.text) ?? 0.0;
                    final actualUserId = _actualUserId ?? "U-1";

                    await appDb.into(appDb.shifts).insert(
                      ShiftsCompanion.insert(
                        id: 'SHF-${DateTime.now().millisecondsSinceEpoch}',
                        branchId: 'CABANG-1', 
                        userId: actualUserId,
                        shiftName: drift.Value(_selectedShiftName),
                        openingCash: drift.Value(cash),
                        status: const drift.Value('OPEN'),
                        openedAt: drift.Value(DateTime.now()),
                      )
                    );
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift Berhasil Dibuka!')));
                    }
                  },
                  child: const Text('Buka Shift Sekarang', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveShiftInfo(Shift shift) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shift Aktif', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${shift.shiftName} - Dimulai pada: ${DateFormat('dd MMMM yyyy, HH:mm').format(shift.openedAt)}'),
          const SizedBox(height: 24),
          
          Card(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet, color: Colors.indigo.shade700, size: 32),
              title: const Text('Kas Awal'),
              trailing: Text('Rp ${formatter.format(shift.openingCash)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
            ),
          ),
          const SizedBox(height: 24),

          // Tombol Tutup Shift
          const Spacer(),
          const Text('Hitung fisik uang di laci dan masukkan di bawah ini sebelum menutup shift:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _closeCashCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Uang Kas Akhir Fisik (Rp)',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              icon: const Icon(Icons.lock),
              label: const Text('Tutup Shift', style: TextStyle(fontSize: 16)),
              onPressed: () async {
                if (_closeCashCtrl.text.isEmpty) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan kas akhir fisik!')));
                   return;
                }
                final closingCash = double.tryParse(_closeCashCtrl.text) ?? 0.0;

                // Ambil penjualan TUNAI dan QRIS
                final payments = await (appDb.select(appDb.payments).join([
                   drift.innerJoin(appDb.transactions, appDb.transactions.id.equalsExp(appDb.payments.transactionId))
                ])..where(
                  appDb.transactions.createdAt.isBiggerOrEqualValue(shift.openedAt) &
                  appDb.transactions.userId.equals(shift.userId)
                )).get();

                double totalCashSales = 0;
                double totalQrisSales = 0;
                
                for (var row in payments) {
                  final p = row.readTable(appDb.payments);
                  if (p.method == 'CASH') {
                    totalCashSales += (p.amount - p.changeAmount);
                  } else if (p.method == 'QRIS') {
                    totalQrisSales += p.amount;
                  }
                }

                // Tambahkan DebtPayments yang diterima
                final dps = await (appDb.select(appDb.debtPayments)
                  ..where((d) => d.date.isBiggerOrEqualValue(shift.openedAt))
                ).get();
                for (var dp in dps) {
                  totalCashSales += dp.amount;
                }

                final expectedCash = shift.openingCash + totalCashSales;
                final selisih = closingCash - expectedCash;
                
                // Show Dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Ringkasan Tutup Shift', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Penjualan Tunai', 'Rp ${formatter.format(totalCashSales)}'),
                          _buildDetailRow('Penjualan QRIS', 'Rp ${formatter.format(totalQrisSales)}'),
                          const Divider(),
                          _buildDetailRow('Seharusnya di Laci', 'Rp ${formatter.format(expectedCash)}', color: Colors.blue.shade700),
                          _buildDetailRow('Fisik Uang Laci', 'Rp ${formatter.format(closingCash)}', color: Colors.indigo.shade700),
                          const SizedBox(height: 8),
                          _buildDetailRow('Selisih', 'Rp ${formatter.format(selisih)}', color: selisih == 0 ? Colors.green : Colors.red),
                          const SizedBox(height: 16),
                          const Text('Anda yakin ingin menutup shift ini?', style: TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Tutup & Cetak Laporan'),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    );
                  }
                );

                if (confirm == true) {
                  final closedTime = DateTime.now();
                  await appDb.update(appDb.shifts).replace(
                    shift.copyWith(
                      status: 'CLOSED',
                      closedAt: drift.Value(closedTime),
                      closingCash: drift.Value(closingCash),
                      expectedCash: drift.Value(expectedCash),
                    )
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift Berhasil Ditutup! Menyiapkan cetakan...')));
                    
                    // Fetch business details
                    final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull() ?? 
                       const Business(id: 'BIZ-1', name: 'MODERN POS', address: '', phone: '', logoBase64: null, taxPercentage: 0.0, enableTableNumber: false, enableQueueNumber: false);
                    
                    final kasirUser = await (appDb.select(appDb.users)..where((u) => u.id.equals(shift.userId))).getSingleOrNull();
                    final cashierRealName = kasirUser?.name ?? shift.userId;

                    await ReceiptPrinterService.printShiftReport(
                      business: business,
                      shiftName: shift.shiftName,
                      cashierName: cashierRealName,
                      openedAt: shift.openedAt,
                      closedAt: closedTime,
                      openingCash: shift.openingCash,
                      totalCashSales: totalCashSales,
                      totalQrisSales: totalQrisSales,
                      expectedCash: expectedCash,
                      actualCash: closingCash,
                      variance: selisih,
                    );
                    if (business.phone != null && business.phone!.isNotEmpty) {
                      _showAdminWhatsAppDialog(business, shift.shiftName, cashierRealName, expectedCash, closingCash, selisih);
                    }
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminWhatsAppDialog(Business business, String shiftName, String cashierName, double expected, double actual, double selisih) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Laporan ke Admin?'),
        content: Text('Kirim ringkasan tutup shift ke nomor WhatsApp Profil Toko (${business.phone})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Lewati'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Kirim WA'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              
              String formattedPhone = business.phone!.trim();
              if (formattedPhone.startsWith('0')) {
                formattedPhone = '62' + formattedPhone.substring(1);
              } else if (formattedPhone.startsWith('+')) {
                formattedPhone = formattedPhone.substring(1);
              }
              
              final formatter = NumberFormat('#,###', 'id_ID');
              final message = 'Laporan Tutup Shift: *' + shiftName + '*\nKasir: *' + cashierName + '*\n\nSeharusnya di Laci: Rp ' + formatter.format(expected) + '\nFisik Uang: Rp ' + formatter.format(actual) + '\nSelisih: Rp ' + formatter.format(selisih) + '\n\nWaktu Tutup: ' + DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
              
              final url = Uri.parse('whatsapp://send?phone=' + formattedPhone + '&text=' + Uri.encodeComponent(message));
              final urlWeb = Uri.parse('https://wa.me/' + formattedPhone + '?text=' + Uri.encodeComponent(message));
              
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else if (await canLaunchUrl(urlWeb)) {
                  await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka WhatsApp. Pastikan WA terinstal di perangkat ini.')));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ' + e.toString())));
              }
            },
          ),
        ]
      )
    );
  }

}
