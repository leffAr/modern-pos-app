import 'dart:convert';
import 'dart:developer';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../core/database/database.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptPrinterService {
  static final _fmt = NumberFormat('#,###', 'id_ID');
  
  static String _formatRupiah(double val) {
    return _fmt.format(val);
  }

  /// Mencetak menggunakan PDF (Native Print Dialog / Uji Coba Layar)
  static Future<void> printReceipt({
    required Business business,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    String? discountNotes,
    required double tax,
    required double total,
    required double paid,
    required double change,
    required String paymentMethod,
    required String cashierName,
    String? tableNumber,
    int? queueNumber,
    DateTime? dueDate,
    double pointsUsed = 0,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logoImage;
    if (business.logoBase64 != null && business.logoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(business.logoBase64!);
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {
        log('Failed to decode logo: $e');
      }
    } else {
      try {
        final byteData = await rootBundle.load('assets/images/logo_v2.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (e) {
        log('Failed to load default logo: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final paperSize = prefs.getString("paperSize") ?? "80";
    final format = paperSize == "58" ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  height: 50,
                  child: pw.Image(logoImage),
                ),
              pw.Text(business.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              if (business.address != null) pw.Text(business.address!, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
              if (business.phone != null) pw.Text('Telp: ${business.phone!}', style: const pw.TextStyle(fontSize: 10)),
              
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Ksr: $cashierName', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              if (queueNumber != null) ...[
                pw.SizedBox(height: 4),
                pw.Text('ANTRIAN', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('$queueNumber', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
              ],
              
              if (tableNumber != null && tableNumber.isNotEmpty) ...[
                pw.Text('Meja / Pemesan: $tableNumber', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
              ],
              
              if (queueNumber != null || (tableNumber != null && tableNumber.isNotEmpty))
                pw.Divider(borderStyle: pw.BorderStyle.dashed),

              // Items
              pw.SizedBox(height: 4),
              ...items.map((item) {
                final qty = item['qty'];
                final price = item['price'];
                final itemTotal = qty * price;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item['variantName'] != null ? '${item['name']} - ${item['variantName']}' : item['name'], style: const pw.TextStyle(fontSize: 10)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('  $qty x ${_formatRupiah(price)}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(_formatRupiah(itemTotal), style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                  ],
                );
              }),
              pw.SizedBox(height: 4),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              // Ringkasan
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_formatRupiah(subtotal), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(discountNotes ?? 'Diskon Promo', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('-${_formatRupiah(discount)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              if (pointsUsed > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Potongan Poin', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('-${_formatRupiah(pointsUsed)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PPN (11%)', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_formatRupiah(tax), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_formatRupiah(total), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(paymentMethod == 'QRIS' ? 'Bayar (QRIS)' : (paymentMethod == 'KASBON' ? 'Bayar (Kasbon)' : 'Tunai'), style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_formatRupiah(paid), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (paymentMethod == 'CASH')
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kembali', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(_formatRupiah(change), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              if (paymentMethod == 'KASBON' && dueDate != null) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Jatuh Tempo', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text(DateFormat('dd MMM yyyy').format(dueDate), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  ],
                ),
              ],
              
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),
              pw.Text('Harga sudah termasuk pajak', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Text('Terima Kasih Atas Kunjungan Anda', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Barang yang sudah dibeli tidak dapat ditukar/dikembalikan.', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Struk_Kasir_$cashierName',
      );
    } catch (e) {
      log('Error saat print pdf: $e');
    }
  }

  static Future<void> printShiftReport({
    required Business business,
    required String shiftName,
    required String cashierName,
    required DateTime openedAt,
    required DateTime closedAt,
    required double openingCash,
    required double totalCashSales,
    required double totalQrisSales,
    required double expectedCash,
    required double actualCash,
    required double variance,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logoImage;
    if (business.logoBase64 != null && business.logoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(business.logoBase64!);
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final paperSize = prefs.getString("paperSize") ?? "80";
    final format = paperSize == "58" ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  height: 50,
                  child: pw.Image(logoImage),
                ),
              pw.Text(business.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('LAPORAN PENUTUPAN SHIFT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kasir:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(cashierName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Shift:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(shiftName, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Mulai:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(openedAt), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tutup:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(closedAt), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Modal Kas Awal:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_formatRupiah(openingCash), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Penjualan Tunai (+):', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_formatRupiah(totalCashSales), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Penjualan QRIS (Lain):', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_formatRupiah(totalQrisSales), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Seharusnya di Laci:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_formatRupiah(expectedCash), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Fisik Uang Laci:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_formatRupiah(actualCash), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Selisih (Kurang/Lebih):', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_formatRupiah(variance), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              
              pw.SizedBox(height: 16),
              pw.Text('Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('*** TERIMA KASIH ***', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Laporan_Shift_$shiftName',
      );
    } catch (e) {
      log('Error saat print laporan shift: $e');
    }
  }

  static Future<void> printAdminReport({
    required Business business,
    required DateTime startDate,
    required DateTime endDate,
    required double totalGrossSales,
    required double totalDiscounts,
    required double totalNetSales,
    required double totalExpenses,
    required double finalNetProfit,
    required double totalCash,
    required double totalQris,
    required double totalKasbon,
    required int totalTransactions,
    required List<Map<String, dynamic>> topProducts,
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logoImage;
    if (business.logoBase64 != null && business.logoBase64!.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(base64Decode(business.logoBase64!));
      } catch (e) {}
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null) pw.Container(width: 50, height: 50, child: pw.Image(logoImage), margin: const pw.EdgeInsets.only(right: 16)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(business.name, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Laporan Keuangan & Penjualan', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700)),
                      pw.Text('Periode: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),
              
              // Ringkasan Pendapatan
              pw.Text('Ringkasan Pendapatan', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Transaksi', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('$totalTransactions Transaksi', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Penjualan Kotor', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Rp ${_formatRupiah(totalGrossSales)}', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Diskon Promo (-)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.red)),
                  pw.Text('- Rp ${_formatRupiah(totalDiscounts)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.red)),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dotted),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Pendapatan Bersih (Net)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rp ${_formatRupiah(totalNetSales)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Pengeluaran (-)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.red)),
                  pw.Text('- Rp ${_formatRupiah(totalExpenses)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.red)),
                ],
              ),
              pw.Divider(borderStyle: pw.BorderStyle.dotted),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Laba Bersih', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rp ${_formatRupiah(finalNetProfit)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                ],
              ),
              
              pw.SizedBox(height: 24),
              
              // Metode Pembayaran
              pw.Text('Rincian Metode Pembayaran', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tunai (CASH)', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Rp ${_formatRupiah(totalCash)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('QRIS / Transfer / Non-Tunai', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Rp ${_formatRupiah(totalQris)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Piutang (KASBON)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.orange800)),
                  pw.Text('Rp ${_formatRupiah(totalKasbon)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                ],
              ),
              
              pw.SizedBox(height: 32),
              
              // Top Produk
              pw.Text('Produk Terlaris', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
              pw.Divider(),
              pw.SizedBox(height: 8),
              if (topProducts.isEmpty)
                pw.Text('Belum ada data penjualan produk.', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey))
              else
                pw.Table.fromTextArray(
                  headers: ['Nama Produk', 'Jumlah Terjual', 'Total Omset'],
                  data: topProducts.map((p) => [
                    p['name'],
                    '${p['qty']} ${p['unit']}',
                    'Rp ${_formatRupiah(p['total'])}',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Dicetak pada: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Laporan_Keuangan_MODERNPOS',
      );
    } catch (e) {
      log('Error saat print laporan admin: $e');
    }
  }

  /// Menghasilkan [Byte List] murni berstandar ESC/POS untuk dikirim via Socket Bluetooth ke Printer Thermal Fisik
  static Future<List<int>> generateThermalEscPosBytes({
    required Business business,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    double discount = 0.0,
    required double total,
    required double paid,
    required double change,
    required String paymentMethod,
    required String cashierName,
    String? tableNumber,
    int? queueNumber,
    DateTime? dueDate,
    double pointsUsed = 0,
  }) async {
    List<int> bytes = [];
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      if (business.logoBase64 != null && business.logoBase64!.isNotEmpty) {
        try {
          final logoBytes = base64Decode(business.logoBase64!);
          final image = img.decodeImage(logoBytes);
          if (image != null) {
            bytes += generator.imageRaster(image);
            bytes += generator.emptyLines(1);
          }
        } catch (e) {
          log('Failed to decode logo for thermal: $e');
        }
      } else {
        try {
          final byteData = await rootBundle.load('assets/images/logo_v2.png');
          final image = img.decodeImage(byteData.buffer.asUint8List());
          if (image != null) {
            bytes += generator.imageRaster(image);
            bytes += generator.emptyLines(1);
          }
        } catch (e) {
          log('Failed to load default logo for thermal: $e');
        }
      }

      bytes += generator.text(business.name, styles: const PosStyles(align: PosAlign.center, bold: true));
      if (business.address != null) bytes += generator.text(business.address!, styles: const PosStyles(align: PosAlign.center));
      if (business.phone != null) bytes += generator.text('Telp: ${business.phone!}', styles: const PosStyles(align: PosAlign.center));
      
      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: DateFormat('dd/MM/yy HH:mm').format(DateTime.now()), width: 6),
        PosColumn(text: 'Ksr: $cashierName', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();

      if (queueNumber != null) {
        bytes += generator.text('ANTRIAN', styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.text('$queueNumber', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
        bytes += generator.emptyLines(1);
      }

      if (tableNumber != null && tableNumber.isNotEmpty) {
        bytes += generator.text('Meja/Nama: $tableNumber', styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.emptyLines(1);
      }
      
      if (queueNumber != null || (tableNumber != null && tableNumber.isNotEmpty)) {
        bytes += generator.hr();
      }

      for (var item in items) {
        bytes += generator.text(item['variantName'] != null ? '${item['name']} - ${item['variantName']}' : item['name']);
        bytes += generator.row([
          PosColumn(text: '  ${item['qty']} x ${_formatRupiah(item['price'])}', width: 7),
          PosColumn(text: _formatRupiah((item['qty'] * item['price']).toDouble()), width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();
      bytes += generator.row([
        PosColumn(text: 'Subtotal', width: 6),
        PosColumn(text: _formatRupiah(subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (discount > 0) {
        bytes += generator.row([
          PosColumn(text: 'Diskon Promo', width: 6),
          PosColumn(text: '-${_formatRupiah(discount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      
      if (pointsUsed > 0) {
        bytes += generator.row([
          PosColumn(text: 'Potongan Poin', width: 6),
          PosColumn(text: '-${_formatRupiah(pointsUsed)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: 'PPN (11%)', width: 6),
        PosColumn(text: _formatRupiah(tax), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr();
      
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: _formatRupiah(total), width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: paymentMethod == 'QRIS' ? 'BAYAR(QRIS)' : (paymentMethod == 'KASBON' ? 'BAYAR(KSBN)' : 'TUNAI'), width: 6),
        PosColumn(text: _formatRupiah(paid), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (paymentMethod == 'CASH') {
        bytes += generator.row([
          PosColumn(text: 'KEMBALI', width: 6),
          PosColumn(text: _formatRupiah(change), width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      if (paymentMethod == 'KASBON' && dueDate != null) {
        bytes += generator.row([
          PosColumn(text: 'JATUH TEMPO', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: DateFormat('dd MMM yyyy').format(dueDate), width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
      }
      
      bytes += generator.emptyLines(1);
      bytes += generator.text('Harga sudah termasuk pajak', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Terima Kasih Atas Kunjungan Anda', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('Brg yg sudah dibeli tdk dapat ditukar', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.emptyLines(2);
      
      bytes += generator.cut();
      
      log("Berhasil men-generate ${bytes.length} bytes ESC/POS data.");
    } catch (e) {
      log("Error generating ESC/POS bytes: $e");
    }
    return bytes;
  }

  
  static Future<void> printProductLabels({
    required Business business,
    required List<Product> products,
  }) async {
    final doc = pw.Document();
    
    // Label printer dimensions (standard label 50x30 mm)
    final format = const PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);

    for (final product in products) {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(business.name, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 1),
                  pw.Text(product.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), maxLines: 1),
                  pw.Text('Rp ${_formatRupiah(product.sellingPrice)}', style: pw.TextStyle(fontSize: 9)),
                  pw.SizedBox(height: 2),
                  if (product.barcode != null && product.barcode!.isNotEmpty)
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: product.barcode!,
                      width: 40 * PdfPageFormat.mm,
                      height: 10 * PdfPageFormat.mm,
                      textStyle: const pw.TextStyle(fontSize: 7),
                    )
                  else if (product.sku != null && product.sku!.isNotEmpty)
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: product.sku!,
                      width: 40 * PdfPageFormat.mm,
                      height: 10 * PdfPageFormat.mm,
                      textStyle: const pw.TextStyle(fontSize: 7),
                    )
                ],
              ),
            );
          },
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (PdfPageFormat f) async => doc.save(), name: 'Label_Produk');
  }
}
