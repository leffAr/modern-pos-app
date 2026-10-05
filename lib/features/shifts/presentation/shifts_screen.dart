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

class ShiftBreakdown {
  final double openingCash;
  final double cashSales;
  final double qrisSales;
  final double debtPayments;
  final double expenses;
  final double expectedCash;

  const ShiftBreakdown({
    required this.openingCash,
    required this.cashSales,
    required this.qrisSales,
    required this.debtPayments,
    required this.expenses,
    required this.expectedCash,
  });
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final _openCashCtrl = TextEditingController();
  final _closeCashCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedShiftName = 'Shift 1';

  Stream<List<Shift>>? _adminShiftsStream;
  Stream<List<Shift>>? _cashierShiftsStream;
  String? _actualUserId;
  bool _isLoadingCashier = true;

  String? _activeShiftId;
  Future<ShiftBreakdown>? _breakdownFuture;

  static String _cleanShiftName(String raw) {
    if (raw.contains(' [Ket: ')) {
      return raw.split(' [Ket: ').first;
    }
    return raw;
  }

  static String? _extractShiftNotes(String raw) {
    if (raw.contains(' [Ket: ')) {
      final notePart = raw.substring(raw.indexOf(' [Ket: ') + 7);
      return notePart.endsWith(']') ? notePart.substring(0, notePart.length - 1) : notePart;
    }
    return null;
  }

  Future<ShiftBreakdown> _calculateShiftBreakdown(Shift shift) async {
    // Ambil pembayaran transaksi tunai dan QRIS kasir ini sejak dibuka
    final payments = await (appDb.select(appDb.payments).join([
      drift.innerJoin(appDb.transactions, appDb.transactions.id.equalsExp(appDb.payments.transactionId))
    ])..where(
      appDb.transactions.createdAt.isBiggerOrEqualValue(shift.openedAt) &
      appDb.transactions.userId.equals(shift.userId)
    )).get();

    double cashSales = 0;
    double qrisSales = 0;
    for (var row in payments) {
      final p = row.readTable(appDb.payments);
      if (p.method == 'CASH') {
        cashSales += (p.amount - p.changeAmount);
      } else if (p.method == 'QRIS') {
        qrisSales += p.amount;
      }
    }

    // Ambil pembayaran piutang / kasbon sejak openedAt
    final dps = await (appDb.select(appDb.debtPayments)
      ..where((d) => d.date.isBiggerOrEqualValue(shift.openedAt))
    ).get();
    double debtPayments = 0;
    for (var dp in dps) {
      debtPayments += dp.amount;
    }

    // Ambil pengeluaran operasional kasir sejak openedAt
    final exps = await (appDb.select(appDb.expenses)
      ..where((e) => e.date.isBiggerOrEqualValue(shift.openedAt) & e.userId.equals(shift.userId))
    ).get();
    double expenses = 0;
    for (var exp in exps) {
      expenses += exp.amount;
    }

    final expectedCash = shift.openingCash + cashSales + debtPayments - expenses;

    return ShiftBreakdown(
      openingCash: shift.openingCash,
      cashSales: cashSales,
      qrisSales: qrisSales,
      debtPayments: debtPayments,
      expenses: expenses,
      expectedCash: expectedCash,
    );
  }

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
    _notesCtrl.dispose();
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

      final baseName = _cleanShiftName(shift.shiftName);
      final note = _extractShiftNotes(shift.shiftName);

      tableData.add([
        baseName,
        cashierName,
        openedStr,
        closedStr,
        openCashStr,
        closeCashStr,
        selisihStr,
        isClosed ? 'Ditutup' : 'Buka',
        note ?? '-',
      ]);
    }

    await ExportService.exportShiftReportPdf(
      businessName: business.name,
      period: ReportFilterState.instance.displayLabel,
      headers: ['Shift', 'Kasir', 'Buka', 'Tutup', 'Modal Awal', 'Kas Akhir', 'Selisih', 'Status', 'Catatan'],
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
                    final baseName = _cleanShiftName(shift.shiftName);
                    final note = _extractShiftNotes(shift.shiftName);
                    
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
                        title: Text('$baseName - ${shift.userId} (${DateFormat('dd MMM, HH:mm').format(shift.openedAt)})'),
                        subtitle: Text(
                          isClosed 
                            ? (selisih == 0 ? 'Sesuai (Pas)' : (selisih > 0 ? 'Lebih: +Rp ${formatter.format(selisih.toInt())}' : 'MINES: -Rp ${formatter.format(selisih.abs().toInt())}'))
                            : 'Sedang Berlangsung',
                          style: TextStyle(
                            color: isClosed ? (selisih == 0 ? Colors.green : (selisih > 0 ? Colors.blue : Colors.red)) : Colors.orange,
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
                                  _buildDetailRow(
                                    'Selisih',
                                    selisih == 0
                                        ? 'Rp 0 (Sesuai)'
                                        : (selisih > 0
                                            ? '+Rp ${formatter.format(selisih.toInt())} (LEBIH)'
                                            : '-Rp ${formatter.format(selisih.abs().toInt())} (MINES)'),
                                    color: selisih == 0 ? Colors.green : (selisih > 0 ? Colors.blue : Colors.red),
                                  ),
                                  if (note != null && note.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.shade300),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.notes, size: 18, color: Colors.amber.shade900),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Keterangan Kasir: $note',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.amber.shade900,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                        shiftName: baseName,
                                        cashierName: cashierRealName,
                                        openedAt: shift.openedAt,
                                        closedAt: shift.closedAt!,
                                        openingCash: shift.openingCash,
                                        totalCashSales: 0.0,
                                        totalQrisSales: 0.0,
                                        expectedCash: shift.expectedCash ?? 0.0,
                                        actualCash: shift.closingCash ?? 0.0,
                                        variance: selisih,
                                        notes: note,
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
    if (_activeShiftId != shift.id) {
      _activeShiftId = shift.id;
      _breakdownFuture = _calculateShiftBreakdown(shift);
    }

    return FutureBuilder<ShiftBreakdown>(
      future: _breakdownFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final breakdown = snapshot.data ?? ShiftBreakdown(
          openingCash: shift.openingCash,
          cashSales: 0.0,
          qrisSales: 0.0,
          debtPayments: 0.0,
          expenses: 0.0,
          expectedCash: shift.openingCash,
        );

        final cleanShiftTitle = _cleanShiftName(shift.shiftName);
        final rawCash = _closeCashCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
        final hasInput = rawCash.isNotEmpty;
        final closingCash = double.tryParse(rawCash) ?? 0.0;
        final selisih = closingCash - breakdown.expectedCash;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Shift Aktif
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, size: 10, color: Colors.green.shade800),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AKTIF BERJALAN',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              cleanShiftTitle,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dibuka: ${DateFormat('dd MMMM yyyy, HH:mm').format(shift.openedAt)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Perbarui Rincian Uang Laci',
                    onPressed: () {
                      setState(() {
                        _breakdownFuture = _calculateShiftBreakdown(shift);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card Rincian Uang di Laci Seharusnya
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.indigo.shade100, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade700,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.point_of_sale, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'RINCIAN UANG DI LACI SEHARUSNYA',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildBreakdownItem(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Kas / Modal Awal',
                            amount: breakdown.openingCash,
                            color: Colors.grey.shade800,
                          ),
                          const Divider(height: 16),
                          _buildBreakdownItem(
                            icon: Icons.add_circle_outline,
                            label: 'Penjualan Tunai (+)',
                            amount: breakdown.cashSales,
                            color: Colors.green.shade700,
                          ),
                          if (breakdown.debtPayments > 0) ...[
                            const Divider(height: 16),
                            _buildBreakdownItem(
                              icon: Icons.payments_outlined,
                              label: 'Bayar Piutang Tunai (+)',
                              amount: breakdown.debtPayments,
                              color: Colors.teal.shade700,
                            ),
                          ],
                          if (breakdown.expenses > 0) ...[
                            const Divider(height: 16),
                            _buildBreakdownItem(
                              icon: Icons.remove_circle_outline,
                              label: 'Kas Keluar / Beban (-)',
                              amount: breakdown.expenses,
                              color: Colors.red.shade700,
                              isNegative: true,
                            ),
                          ],
                          const Divider(thickness: 1.5, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL SEHARUSNYA DI LACI',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo),
                                  ),
                                  Text(
                                    'Perhitungan Otomatis Sistem',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                              Text(
                                'Rp ${formatter.format(breakdown.expectedCash.toInt())}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (breakdown.qrisSales > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.qr_code_2, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 6),
                                Text('Penjualan QRIS (Non-Tunai):', style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
                              ],
                            ),
                            Text(
                              'Rp ${formatter.format(breakdown.qrisSales.toInt())}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form Kas Akhir Fisik
              const Text(
                'Input Kas Akhir Fisik Laci',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Hitung seluruh uang fisik di laci kasir saat ini dan masukkan nominalnya di bawah ini:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _closeCashCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Uang Kas Akhir Fisik di Laci (Rp)',
                  prefixIcon: const Icon(Icons.money),
                  prefixText: 'Rp ',
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: hasInput
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _closeCashCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Live Selisih Card (Mines / Pas / Surplus)
              if (!hasInput)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calculate_outlined, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ketik nominal fisik uang kas di atas untuk melihat kalkulasi selisih secara otomatis.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildVarianceIndicator(selisih),

              const SizedBox(height: 20),

              // Input Keterangan Kasir
              const Text(
                'Keterangan / Catatan Kasir',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Berikan penjelasan catatan serah terima atau alasan jika terjadi selisih kas:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Keterangan Kasir (Opsional / Wajib jika Mines)',
                  hintText: 'Contoh: Kembalian kurang Rp 2.000 karena tidak ada uang pecahan kecil...',
                  prefixIcon: const Icon(Icons.edit_note),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                  helperText: (hasInput && selisih < 0)
                      ? '⚠️ Kas laci MINES: Sangat disarankan menuliskan keterangan penyebab selisih.'
                      : 'Catatan akan tersimpan dan dicetak di struk laporan shift.',
                  helperStyle: TextStyle(
                    color: (hasInput && selisih < 0) ? Colors.red.shade700 : Colors.grey.shade600,
                    fontWeight: (hasInput && selisih < 0) ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Tutup Shift
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock, size: 20),
                  label: const Text('Tutup Shift Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () => _handleCloseShift(shift, breakdown),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownItem({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    bool isNegative = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '${isNegative ? '-' : ''}Rp ${formatter.format(amount.toInt())}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildVarianceIndicator(double selisih) {
    final isMinus = selisih < 0;
    final isZero = selisih == 0;

    final Color bgColor = isMinus
        ? Colors.red.shade50
        : (isZero ? Colors.green.shade50 : Colors.blue.shade50);
    final Color borderColor = isMinus
        ? Colors.red.shade400
        : (isZero ? Colors.green.shade400 : Colors.blue.shade400);
    final Color textColor = isMinus
        ? Colors.red.shade800
        : (isZero ? Colors.green.shade800 : Colors.blue.shade800);
    final IconData icon = isMinus
        ? Icons.error_outline
        : (isZero ? Icons.check_circle_outline : Icons.info_outline);

    final String statusTitle = isMinus
        ? 'MINES (KURANG KAS)'
        : (isZero ? 'PAS (SEIMBANG)' : 'LEBIH (SURPLUS)');

    final String formattedDiff = isMinus
        ? '- Rp ${formatter.format(selisih.abs().toInt())}'
        : (isZero ? 'Rp 0' : '+ Rp ${formatter.format(selisih.toInt())}');

    final String description = isMinus
        ? 'Uang fisik di laci KURANG Rp ${formatter.format(selisih.abs().toInt())} dari yang seharusnya tercatat.'
        : (isZero
            ? 'Uang fisik di laci COCOK tepat dengan perhitungan sistem.'
            : 'Uang fisik di laci LEBIH Rp ${formatter.format(selisih.toInt())} dari yang seharusnya tercatat.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: textColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'STATUS: $statusTitle',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formattedDiff,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: textColor.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCloseShift(Shift shift, ShiftBreakdown breakdown) async {
    if (_closeCashCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan jumlah kas fisik uang di laci terlebih dahulu!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final rawCash = _closeCashCtrl.text.replaceAll('.', '').replaceAll(',', '').trim();
    final closingCash = double.tryParse(rawCash) ?? 0.0;
    final expectedCash = breakdown.expectedCash;
    final selisih = closingCash - expectedCash;
    final notes = _notesCtrl.text.trim();

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isMinus = selisih < 0;
        final isZero = selisih == 0;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.indigo.shade700),
              const SizedBox(width: 8),
              const Text('Konfirmasi Tutup Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Modal Kas Awal', 'Rp ${formatter.format(breakdown.openingCash.toInt())}'),
                _buildDetailRow('Penjualan Tunai (+)', 'Rp ${formatter.format(breakdown.cashSales.toInt())}', color: Colors.green.shade700),
                if (breakdown.debtPayments > 0)
                  _buildDetailRow('Bayar Piutang (+)', 'Rp ${formatter.format(breakdown.debtPayments.toInt())}', color: Colors.teal.shade700),
                if (breakdown.expenses > 0)
                  _buildDetailRow('Kas Keluar (-)', '-Rp ${formatter.format(breakdown.expenses.toInt())}', color: Colors.red.shade700),
                if (breakdown.qrisSales > 0)
                  _buildDetailRow('Penjualan QRIS (Lain)', 'Rp ${formatter.format(breakdown.qrisSales.toInt())}', color: Colors.blue.shade700),
                const Divider(thickness: 1.2),
                _buildDetailRow('Total Seharusnya di Laci', 'Rp ${formatter.format(expectedCash.toInt())}', color: Colors.indigo.shade800),
                _buildDetailRow('Fisik Uang di Laci', 'Rp ${formatter.format(closingCash.toInt())}', color: Colors.indigo.shade800),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMinus ? Colors.red.shade50 : (isZero ? Colors.green.shade50 : Colors.blue.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMinus ? Colors.red.shade300 : (isZero ? Colors.green.shade300 : Colors.blue.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selisih Kas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMinus ? Colors.red.shade800 : (isZero ? Colors.green.shade800 : Colors.blue.shade800),
                        ),
                      ),
                      Text(
                        isMinus
                            ? '- Rp ${formatter.format(selisih.abs().toInt())} (MINES)'
                            : (isZero ? 'Rp 0 (PAS)' : '+ Rp ${formatter.format(selisih.toInt())} (LEBIH)'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isMinus ? Colors.red.shade800 : (isZero ? Colors.green.shade800 : Colors.blue.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Keterangan Kasir:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(notes, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Apakah data uang kas sudah benar dan shift siap ditutup?',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade700),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Tutup & Cetak Laporan'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final closedTime = DateTime.now();
      final updatedShiftName = notes.isNotEmpty ? '${_cleanShiftName(shift.shiftName)} [Ket: $notes]' : shift.shiftName;

      await appDb.update(appDb.shifts).replace(
        shift.copyWith(
          status: 'CLOSED',
          shiftName: updatedShiftName,
          closedAt: drift.Value(closedTime),
          closingCash: drift.Value(closingCash),
          expectedCash: drift.Value(expectedCash),
        ),
      );

      _closeCashCtrl.clear();
      _notesCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift Berhasil Ditutup! Menyiapkan cetak laporan...'),
            backgroundColor: Colors.green,
          ),
        );

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

        final kasirUser = await (appDb.select(appDb.users)..where((u) => u.id.equals(shift.userId))).getSingleOrNull();
        final cashierRealName = kasirUser?.name ?? shift.userId;

        await ReceiptPrinterService.printShiftReport(
          business: business,
          shiftName: _cleanShiftName(shift.shiftName),
          cashierName: cashierRealName,
          openedAt: shift.openedAt,
          closedAt: closedTime,
          openingCash: shift.openingCash,
          totalCashSales: breakdown.cashSales,
          totalQrisSales: breakdown.qrisSales,
          expectedCash: expectedCash,
          actualCash: closingCash,
          variance: selisih,
          totalExpenses: breakdown.expenses,
          totalDebtPayments: breakdown.debtPayments,
          notes: notes.isNotEmpty ? notes : null,
        );

        if (business.phone != null && business.phone!.isNotEmpty) {
          _showAdminWhatsAppDialog(
            business,
            _cleanShiftName(shift.shiftName),
            cashierRealName,
            expectedCash,
            closingCash,
            selisih,
            notes: notes.isNotEmpty ? notes : null,
          );
        }
      }
    }
  }

  void _showAdminWhatsAppDialog(
    Business business,
    String shiftName,
    String cashierName,
    double expected,
    double actual,
    double selisih, {
    String? notes,
  }) {
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
                formattedPhone = '62${formattedPhone.substring(1)}';
              } else if (formattedPhone.startsWith('+')) {
                formattedPhone = formattedPhone.substring(1);
              }

              final formatter = NumberFormat('#,###', 'id_ID');
              final selisihFormatted = selisih == 0
                  ? 'Rp 0 (PAS)'
                  : (selisih > 0
                      ? '+Rp ${formatter.format(selisih.toInt())} (LEBIH)'
                      : '-Rp ${formatter.format(selisih.abs().toInt())} (MINES)');

              var message = '📋 *Laporan Tutup Shift: $shiftName*\n'
                  '👤 Kasir: *$cashierName*\n\n'
                  '💼 Seharusnya di Laci: *Rp ${formatter.format(expected.toInt())}*\n'
                  '💵 Fisik Uang Laci: *Rp ${formatter.format(actual.toInt())}*\n'
                  '⚖️ Selisih Kas: *$selisihFormatted*\n';

              if (notes != null && notes.isNotEmpty) {
                message += '📝 Catatan Kasir: _${notes}_\n';
              }

              message += '\n🕒 Waktu Tutup: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}';

              final url = Uri.parse('whatsapp://send?phone=$formattedPhone&text=${Uri.encodeComponent(message)}');
              final urlWeb = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');

              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else if (await canLaunchUrl(urlWeb)) {
                  await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal membuka WhatsApp. Pastikan WA terinstal di perangkat ini.')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
