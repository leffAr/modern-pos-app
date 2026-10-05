import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

class ExportService {
  /// Generate and preview PDF Report
  static Future<void> exportToPdf({
    required String title,
    required List<List<String>> data,
    required List<String> headers,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Laporan: $title', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Tanggal Cetak: ${DateTime.now().toString().substring(0, 16)}'),
              pw.SizedBox(height: 24),
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.centerLeft,
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              ),
            ],
          );
        },
      ),
    );

    // Call printing package to preview/share the PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Report_${title.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Generate and preview Shift Report PDF with professional formatting & summary cards
  static Future<void> exportShiftReportPdf({
    required String businessName,
    required String period,
    required List<List<String>> data,
    required List<String> headers,
    required int totalShifts,
    required double totalOpeningCash,
    required double totalClosingCash,
    required double totalVariance,
  }) async {
    final doc = pw.Document();
    final fmt = NumberFormat('#,###', 'id_ID');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                    pw.SizedBox(height: 4),
                    pw.Text('LAPORAN SHIFT & KAS KASIR', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
                    pw.Text('Periode: $period', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Dicetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    pw.Text('Total Shift: $totalShifts', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Total Modal Awal', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('Rp ${fmt.format(totalOpeningCash.toInt())}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Total Kas Fisik Akhir', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('Rp ${fmt.format(totalClosingCash.toInt())}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Total Selisih (Laci)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        totalVariance == 0
                            ? 'Rp 0'
                            : (totalVariance > 0
                                ? '+Rp ${fmt.format(totalVariance.toInt())}'
                                : '-Rp ${fmt.format(totalVariance.abs().toInt())}'),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: totalVariance == 0
                              ? PdfColors.green800
                              : (totalVariance > 0 ? PdfColors.blue800 : PdfColors.red800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Table.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              headerAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Laporan_Shift_${period.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Generate and save Excel (.xlsx) Report
  static Future<String?> exportToExcel({
    required String title,
    required List<List<dynamic>> data,
    required List<String> headers,
  }) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Style for Headers
      CellStyle headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#1E40AF'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Tambahkan Header
      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());
      
      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      final formatter = NumberFormat('#,###', 'id_ID');

      // Tambahkan Data
      for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
        var row = data[rowIndex];
        List<CellValue> cellValues = [];
        for (var e in row) {
          if (e is num) {
            cellValues.add(TextCellValue(formatter.format(e)));
          } else {
            // Check if string is a pure large number string (e.g. "10000") that should be formatted
            // But we will let the caller pass nums directly for safety.
            cellValues.add(TextCellValue(e?.toString() ?? ''));
          }
        }
        sheetObject.appendRow(cellValues);
        
        // Opsional: berikan warna selang-seling agar rapi
        if (rowIndex % 2 == 1 && row.isNotEmpty && row[0].toString() != 'TOTAL' && row[0].toString() != 'TOTAL KESELURUHAN') {
          for (int i = 0; i < row.length; i++) {
            var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: rowIndex + 1));
            cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#F3F4F6'));
          }
        }
      }

      // Encode bytes
      var fileBytes = excel.encode();
      
      if (fileBytes != null) {
        final fileName = 'Laporan_${title.replaceAll(' ', '_')}';
        
        // Simpan menggunakan FileSaver (Bisa di Web, Windows, Android, dll)
        final path = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(fileBytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        
        if (path.isNotEmpty) {
          try {
            await OpenFilex.open(path);
          } catch (e) {
            print("Could not open file: $e");
          }
        }
        return path;
      }
    } catch (e) {
      print("Excel Export Error: $e");
    }
    return null;
  }
}
