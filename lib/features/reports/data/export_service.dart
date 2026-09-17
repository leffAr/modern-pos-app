import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

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
        
        return path;
      }
    } catch (e) {
      print("Excel Export Error: $e");
    }
    return null;
  }
}
