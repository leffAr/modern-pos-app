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
import 'thermal_printer_service.dart';

class ReceiptPrinterService {
  static final _fmt = NumberFormat('#,###', 'id_ID');
  
  static String _formatRupiah(double val) {
    return _fmt.format(val);
  }

  /// Memuat font monospaced kasir modern standar Alfamart (RobotoMono dengan fallback Courier)
  static Future<pw.ThemeData> _getReceiptTheme() async {
    pw.Font baseFont;
    pw.Font boldFont;
    try {
      baseFont = await PdfGoogleFonts.robotoMonoRegular();
      boldFont = await PdfGoogleFonts.robotoMonoBold();
    } catch (_) {
      baseFont = pw.Font.courier();
      boldFont = pw.Font.courierBold();
    }
    return pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
    );
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
    // 1. Cek apakah mode koneksi adalah Direct Bluetooth atau Direct Network
    final connectionType = await ThermalPrinterService.getConnectionType();
    if (connectionType == PrinterConnectionType.bluetooth || connectionType == PrinterConnectionType.network) {
      try {
        final escBytes = await generateThermalEscPosBytes(
          business: business,
          items: items,
          subtotal: subtotal,
          tax: tax,
          discount: discount,
          total: total,
          paid: paid,
          change: change,
          paymentMethod: paymentMethod,
          cashierName: cashierName,
          tableNumber: tableNumber,
          queueNumber: queueNumber,
          dueDate: dueDate,
          pointsUsed: pointsUsed,
        );

        if (escBytes.isNotEmpty) {
          bool printed = false;
          if (connectionType == PrinterConnectionType.bluetooth) {
            printed = await ThermalPrinterService.printBytesViaBluetooth(escBytes);
          } else if (connectionType == PrinterConnectionType.network) {
            final prefs = await SharedPreferences.getInstance();
            final ip = prefs.getString(ThermalPrinterService.keyNetIp) ?? "192.168.1.200";
            final port = prefs.getInt(ThermalPrinterService.keyNetPort) ?? 9100;
            printed = await ThermalPrinterService.printBytesViaNetwork(ip, port, escBytes);
          }

          if (printed) {
            log('Struk berhasil dicetak langsung ke Thermal Printer ($connectionType)');
            return;
          } else {
            log('Direct thermal printing gagal/terputus, mengalihkan ke dialog cetak sistem...');
          }
        }
      } catch (e) {
        log('Direct thermal print error: $e, fallback ke PDF');
      }
    }

    final theme = await _getReceiptTheme();
    final doc = pw.Document(theme: theme);

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
    final paperSize = prefs.getString("paperSize") ?? "58";
    final format = paperSize == "58" ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    final margin = paperSize == "58"
        ? const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8)
        : const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12);

    final totalItems = items.fold<int>(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1));
    final txCode = 'TRX-${DateFormat('yyMMddHHmm').format(DateTime.now())}';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: margin,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  height: 40,
                  child: pw.Image(logoImage),
                ),
              pw.Text(
                business.name.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 0.5),
              ),
              if (business.address != null && business.address!.isNotEmpty)
                pw.Text(
                  business.address!.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              if (business.phone != null && business.phone!.isNotEmpty)
                pw.Text(
                  'TELP: ${business.phone!}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7),
                ),

              pw.SizedBox(height: 6),
              pw.Text('================================', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('BON  : $txCode', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('KSR: ${cashierName.toUpperCase()}', style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TGL  : ${DateFormat('dd-MM-yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('JAM: ${DateFormat('HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),

              if (queueNumber != null) ...[
                pw.SizedBox(height: 4),
                pw.Text('NOMOR ANTRIAN', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('#$queueNumber', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ],

              if (tableNumber != null && tableNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('MEJA / PEMESAN : ${tableNumber.toUpperCase()}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ],

              pw.SizedBox(height: 2),
              pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),

              // Items List Alfamart Style
              ...items.map((item) {
                final qty = item['qty'] ?? 1;
                final price = item['price'] ?? 0.0;
                final itemTotal = (qty * price).toDouble();
                final itemName = '${item['name']}'.toUpperCase();
                final variant = item['variantName'] != null ? ' - ${item['variantName']}'.toUpperCase() : '';

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '$itemName$variant',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('   $qty x ${_formatRupiah(price)}', style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text(_formatRupiah(itemTotal), style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL ITEM ($totalItems PCS)', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(_formatRupiah(subtotal), style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              if (discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text((discountNotes ?? 'DISKON PROMO').toUpperCase(), style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('-${_formatRupiah(discount)}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              if (pointsUsed > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('POTONGAN POIN', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('-${_formatRupiah(pointsUsed)}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PPN (11%)', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text(_formatRupiah(tax), style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),

              pw.SizedBox(height: 2),
              pw.Text('================================', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 2),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL AKHIR', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rp ${_formatRupiah(total)}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('BAYAR (${paymentMethod == 'QRIS' ? 'QRIS' : (paymentMethod == 'KASBON' ? 'KASBON' : 'TUNAI')})', style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('Rp ${_formatRupiah(paid)}', style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              if (paymentMethod == 'CASH')
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('KEMBALI', style: const pw.TextStyle(fontSize: 7.5)),
                    pw.Text('Rp ${_formatRupiah(change)}', style: const pw.TextStyle(fontSize: 7.5)),
                  ],
                ),
              if (paymentMethod == 'KASBON' && dueDate != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('JATUH TEMPO', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                    pw.Text(DateFormat('dd-MM-yyyy').format(dueDate), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                  ],
                ),

              pw.SizedBox(height: 4),
              pw.Text('================================', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),

              // Footer Alfamart Style
              pw.Text('HARGA SUDAH TERMASUK PPN', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5)),
              pw.SizedBox(height: 2),
              pw.Text('TERIMA KASIH TELAH BERBELANJA', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              if (business.phone != null && business.phone!.isNotEmpty)
                pw.Text('KRITIK & SARAN: SMS/WA ${business.phone}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6.5)),
              pw.Text('BARANG YG SUDAH DIBELI TDK DAPAT DITUKAR', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6)),

              pw.SizedBox(height: 6),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: txCode,
                width: paperSize == "80" ? 140 : 100,
                height: 24,
                drawText: true,
                textStyle: const pw.TextStyle(fontSize: 6.5),
              ),
              pw.SizedBox(height: 4),
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
    final theme = await _getReceiptTheme();
    final doc = pw.Document(theme: theme);

    pw.MemoryImage? logoImage;
    if (business.logoBase64 != null && business.logoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(business.logoBase64!);
        logoImage = pw.MemoryImage(bytes);
      } catch (e) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final paperSize = prefs.getString("paperSize") ?? "58";
    final format = paperSize == "58" ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    final margin = paperSize == "58"
        ? const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8)
        : const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: margin,
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
      final prefs = await SharedPreferences.getInstance();
      final paperSize = prefs.getString(ThermalPrinterService.keyPaperSize) ?? "58";
      final printLogo = prefs.getBool(ThermalPrinterService.keyPrintLogoThermal) ?? true;
      final autoCut = prefs.getBool(ThermalPrinterService.keyAutoCut) ?? (paperSize == "80");

      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize == "80" ? PaperSize.mm80 : PaperSize.mm58, profile);

      if (printLogo) {
        img.Image? image;
        if (business.logoBase64 != null && business.logoBase64!.isNotEmpty) {
          try {
            final logoBytes = base64Decode(business.logoBase64!);
            image = img.decodeImage(logoBytes);
          } catch (e) {
            log('Failed to decode logo for thermal: $e');
          }
        } else {
          try {
            final byteData = await rootBundle.load('assets/images/logo_v2.png');
            image = img.decodeImage(byteData.buffer.asUint8List());
          } catch (e) {
            log('Failed to load default logo for thermal: $e');
          }
        }

        if (image != null) {
          try {
            final maxWidth = paperSize == "80" ? 320 : 200;
            if (image.width > maxWidth) {
              image = img.copyResize(image, width: maxWidth);
            }
            image = img.grayscale(image);
            bytes += generator.imageRaster(image);
            bytes += generator.emptyLines(1);
          } catch (e) {
            log('Error rasterizing logo on thermal: $e');
          }
        }
      }

      final txCode = 'TRX-${DateFormat('yyMMddHHmm').format(DateTime.now())}';
      final totalItems = items.fold<int>(0, (sum, item) => sum + ((item['qty'] as num?)?.toInt() ?? 1));

      bytes += generator.text(
        business.name.toUpperCase(),
        styles: const PosStyles(align: PosAlign.center, bold: true, width: PosTextSize.size1, height: PosTextSize.size1),
      );
      if (business.address != null && business.address!.isNotEmpty) {
        bytes += generator.text(business.address!.toUpperCase(), styles: const PosStyles(align: PosAlign.center));
      }
      if (business.phone != null && business.phone!.isNotEmpty) {
        bytes += generator.text('TELP: ${business.phone!}', styles: const PosStyles(align: PosAlign.center));
      }
      
      bytes += generator.hr(ch: '=');
      bytes += generator.row([
        PosColumn(text: 'BON: $txCode', width: 6),
        PosColumn(text: 'KSR: ${cashierName.toUpperCase()}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'TGL: ${DateFormat('dd-MM-yy').format(DateTime.now())}', width: 6),
        PosColumn(text: 'JAM: ${DateFormat('HH:mm').format(DateTime.now())}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      if (queueNumber != null) {
        bytes += generator.text('ANTRIAN', styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.text('#$queueNumber', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      }

      if (tableNumber != null && tableNumber.isNotEmpty) {
        bytes += generator.text('MEJA: ${tableNumber.toUpperCase()}', styles: const PosStyles(align: PosAlign.center, bold: true));
      }
      
      bytes += generator.hr(ch: '-');

      for (var item in items) {
        final name = (item['variantName'] != null ? '${item['name']} - ${item['variantName']}' : item['name']).toString().toUpperCase();
        final qty = item['qty'] ?? 1;
        final price = item['price'] ?? 0.0;
        final itemTotal = (qty * price).toDouble();

        bytes += generator.text(name, styles: const PosStyles(bold: false));
        bytes += generator.row([
          PosColumn(text: '  $qty x ${_formatRupiah(price)}', width: 7),
          PosColumn(text: _formatRupiah(itemTotal), width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr(ch: '-');
      bytes += generator.row([
        PosColumn(text: 'TOTAL ITEM ($totalItems PCS)', width: 6),
        PosColumn(text: _formatRupiah(subtotal), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (discount > 0) {
        bytes += generator.row([
          PosColumn(text: 'DISKON PROMO', width: 6),
          PosColumn(text: '-${_formatRupiah(discount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      
      if (pointsUsed > 0) {
        bytes += generator.row([
          PosColumn(text: 'POTONGAN POIN', width: 6),
          PosColumn(text: '-${_formatRupiah(pointsUsed)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: 'PPN (11%)', width: 6),
        PosColumn(text: _formatRupiah(tax), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '=');
      
      bytes += generator.row([
        PosColumn(text: 'TOTAL AKHIR', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Rp ${_formatRupiah(total)}', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: paymentMethod == 'QRIS' ? 'BAYAR (QRIS)' : (paymentMethod == 'KASBON' ? 'BAYAR (KSBN)' : 'TUNAI'), width: 6),
        PosColumn(text: 'Rp ${_formatRupiah(paid)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      if (paymentMethod == 'CASH') {
        bytes += generator.row([
          PosColumn(text: 'KEMBALI', width: 6),
          PosColumn(text: 'Rp ${_formatRupiah(change)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      if (paymentMethod == 'KASBON' && dueDate != null) {
        bytes += generator.row([
          PosColumn(text: 'JATUH TEMPO', width: 6, styles: const PosStyles(bold: true)),
          PosColumn(text: DateFormat('dd-MM-yyyy').format(dueDate), width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]);
      }
      
      bytes += generator.hr(ch: '=');
      bytes += generator.text('HARGA SUDAH TERMASUK PPN', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('TERIMA KASIH TELAH BERBELANJA', styles: const PosStyles(align: PosAlign.center, bold: true));
      if (business.phone != null && business.phone!.isNotEmpty) {
        bytes += generator.text('KRITIK & SARAN: ${business.phone!}', styles: const PosStyles(align: PosAlign.center));
      }
      bytes += generator.text('BARANG YG SUDAH DIBELI TDK DAPAT DITUKAR', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.emptyLines(1);
      bytes += generator.qrcode(txCode, size: QRSize.size3, align: PosAlign.center);
      bytes += generator.emptyLines(2);
      
      if (autoCut) {
        bytes += generator.cut();
      } else {
        bytes += generator.emptyLines(2);
      }
      
      log("Berhasil men-generate ${bytes.length} bytes ESC/POS data.");
    } catch (e) {
      log("Error generating ESC/POS bytes: $e");
    }
    return bytes;
  }

  /// Mencetak sampel struk uji coba langsung ke printer aktif
  static Future<bool> printTestReceipt({required Business business}) async {
    final connectionType = await ThermalPrinterService.getConnectionType();
    const testItems = [
      {"name": "Item Uji Coba A", "qty": 1, "price": 15000.0, "variantName": null},
      {"name": "Item Uji Coba B", "qty": 2, "price": 5000.0, "variantName": "Ukuran M"},
    ];

    if (connectionType == PrinterConnectionType.bluetooth || connectionType == PrinterConnectionType.network) {
      final bytes = await generateThermalEscPosBytes(
        business: business,
        items: testItems,
        subtotal: 25000.0,
        tax: 0.0,
        discount: 0.0,
        total: 25000.0,
        paid: 50000.0,
        change: 25000.0,
        paymentMethod: "CASH",
        cashierName: "Admin (Test)",
      );

      if (bytes.isNotEmpty) {
        if (connectionType == PrinterConnectionType.bluetooth) {
          return await ThermalPrinterService.printBytesViaBluetooth(bytes);
        } else {
          final prefs = await SharedPreferences.getInstance();
          final ip = prefs.getString(ThermalPrinterService.keyNetIp) ?? "192.168.1.200";
          final port = prefs.getInt(ThermalPrinterService.keyNetPort) ?? 9100;
          return await ThermalPrinterService.printBytesViaNetwork(ip, port, bytes);
        }
      }
      return false;
    } else {
      await printReceipt(
        business: business,
        items: testItems,
        subtotal: 25000.0,
        discount: 0.0,
        tax: 0.0,
        total: 25000.0,
        paid: 50000.0,
        change: 25000.0,
        paymentMethod: "CASH",
        cashierName: "Admin (Test)",
      );
      return true;
    }
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
