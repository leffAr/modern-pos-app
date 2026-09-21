import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
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
    if (widget.userRole == 'Admin') {
      _adminShiftsStream = (appDb.select(appDb.shifts)..orderBy([(t) => drift.OrderingTerm.desc(t.openedAt)])).watch();
    } else {
      _loadCashierData();
    }
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
    _openCashCtrl.dispose();
    _closeCashCtrl.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Shift & Kas')),
      body: StreamBuilder<List<Shift>>(
        stream: _adminShiftsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final shifts = snapshot.data ?? [];
          
          if (shifts.isEmpty) {
            return const Center(child: Text('Belum ada data shift.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shifts.length,
            itemBuilder: (context, index) {
              final shift = shifts[index];
              final isClosed = shift.status == 'CLOSED';
              
              double selisih = 0;
              if (isClosed && shift.closingCash != null && shift.expectedCash != null) {
                selisih = shift.closingCash! - shift.expectedCash!;
              }

              return Card(
                child: ExpansionTile(
                  leading: Icon(
                    isClosed ? Icons.lock : Icons.lock_open,
                    color: isClosed ? Colors.grey : Colors.green,
                  ),
                  title: Text('${shift.shiftName} - ${shift.userId} (${DateFormat('dd MMM, HH:mm').format(shift.openedAt)})'),
                  subtitle: Text(
                    isClosed 
                      ? (selisih == 0 ? 'Sesuai' : (selisih > 0 ? 'Lebih: Rp ${formatter.format(selisih)}' : 'Kurang: Rp ${formatter.format(selisih.abs())}'))
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
                                  closedAt: shift.closedAt!,
                                  openingCash: shift.openingCash,
                                  totalCashSales: 0.0, // Simplify for reprint, or compute it again
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
          );
        },
      ),
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
