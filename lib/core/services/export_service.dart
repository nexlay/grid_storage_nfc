import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:grid_storage_nfc/features/inventory/domain/entities/storage_box.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ExportService {
  /// Eksportuje listę do pliku PDF
  Future<void> exportToPdf(List<StorageBox> items) async {
    if (items.isEmpty) return;

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text('Inventory Export',
              style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(color: PdfColors.grey600)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'ID / Barcode',
              'Item Name',
              'Qty',
              'Min Limit',
              'Last Used'
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            data: items.map((box) {
              return [
                box.barcode ?? 'N/A',
                box.itemName,
                box.quantity.toString(),
                box.threshold.toString(),
                DateFormat('yyyy-MM-dd HH:mm').format(box.lastUsed),
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final Uint8List bytes = await doc.save();
    final filename =
        'inventory_export_${DateTime.now().millisecondsSinceEpoch}.pdf';

    await _shareData(
        bytes, filename, 'application/pdf', 'Inventory PDF Export');
  }

  /// Eksportuje listę do pliku Excel (.xlsx)
  Future<void> exportToExcel(List<StorageBox> items) async {
    if (items.isEmpty) return;

    var excel = Excel.createExcel();
    String defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheetName, 'Inventory');
    Sheet sheetObject = excel['Inventory'];

    sheetObject.appendRow([
      TextCellValue('ID / Barcode'),
      TextCellValue('Item Name'),
      TextCellValue('Quantity'),
      TextCellValue('Min Alert'),
      TextCellValue('Last Used')
    ]);

    for (var box in items) {
      sheetObject.appendRow([
        TextCellValue(box.barcode ?? 'N/A'),
        TextCellValue(box.itemName),
        IntCellValue(box.quantity),
        IntCellValue(box.threshold),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(box.lastUsed)),
      ]);
    }

    var fileBytes = excel.save();
    if (fileBytes != null) {
      final filename =
          'inventory_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      await _shareData(
          Uint8List.fromList(fileBytes),
          filename,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'Inventory Excel Export');
    }
  }

  /// Helper do bezpiecznego udostępniania plików (kompatybilny z najnowszym share_plus)
  Future<void> _shareData(
      Uint8List bytes, String filename, String mimeType, String text) async {
    XFile xFile;

    if (kIsWeb) {
      // Dla środowiska Web (z wykorzystaniem fromData)
      xFile = XFile.fromData(bytes, name: filename, mimeType: mimeType);
    } else {
      // Bezpieczny zapis pliku dla Android/iOS/Windows
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(bytes);

      // Tworzymy XFile bezpośrednio ze ścieżki pliku
      xFile = XFile(file.path, mimeType: mimeType);
    }

    // NOWA składnia wymuszona przez paczkę share_plus w najnowszej wersji
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: text,
      ),
    );
  }
}
