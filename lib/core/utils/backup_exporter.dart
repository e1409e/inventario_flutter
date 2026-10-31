import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../entities/inventory_transaction.dart';

class BackupExporter {
  static Future<String> generateFullBackupFiles({
    required List<InventoryTransaction> transactions,
    required DateTime cutoffDate,
    required bool exportJson,
    required bool exportExcel,
    required bool exportPdf,
  }) async {
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final cutoffStr = DateFormat('dd/MM/yyyy').format(cutoffDate);
    final List<String> savedFiles = [];

    Directory? baseDir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      baseDir = await getDownloadsDirectory();
      baseDir ??= await getApplicationDocumentsDirectory();
    }

    // 1. RESPALDO EN JSON (Estructura completa para restauración)
    if (exportJson) {
      final jsonList = transactions.map((tx) {
        return {
          'id': tx.id,
          'timestamp': tx.timestamp.toIso8601String(),
          'type': tx.type == TransactionType.inbound ? 'inbound' : 'outbound',
          'category': tx.category,
          'description': tx.description,
          'items': tx.items
              .map(
                (i) => {
                  'product_id': i.productId,
                  'product_name': i.productName,
                  'quantity': i.quantity,
                },
              )
              .toList(),
        };
      }).toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert({
        'backup_created_at': DateTime.now().toIso8601String(),
        'cutoff_date': cutoffDate.toIso8601String(),
        'total_transactions': transactions.length,
        'transactions': jsonList,
      });

      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      final jsonFileName = 'Respaldo_Turso_$stamp.json';

      if (baseDir != null) {
        final path = p.join(baseDir.path, jsonFileName);
        await File(path).writeAsBytes(jsonBytes);
        savedFiles.add(jsonFileName);
      } else {
        await Printing.sharePdf(bytes: jsonBytes, filename: jsonFileName);
        savedFiles.add(jsonFileName);
      }
    }

    // 2. RESPALDO EN EXCEL (CSV detallado línea por línea)
    if (exportExcel) {
      final buffer = StringBuffer();
      buffer.writeln(
        "TRIPLE AAA FOOD DISTRIBUTION - RESPALDO HISTORICO (ANTERIOR AL $cutoffStr)",
      );
      buffer.writeln("TRANSACCIONES RESPALDADAS:;${transactions.length}");
      buffer.writeln("");
      buffer.writeln(
        "ID TRANSACCION;FECHA Y HORA;FLUJO;CATEGORIA;PRODUCTO;CANTIDAD;NOTA",
      );

      for (final tx in transactions) {
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(tx.timestamp);
        final flujo = tx.type == TransactionType.inbound ? 'ENTRADA' : 'SALIDA';
        final cleanNote = tx.description
            .replaceAll(';', ',')
            .replaceAll('\n', ' ');

        for (final item in tx.items) {
          final cleanProd = item.productName.replaceAll(';', ',').toUpperCase();
          final qty = item.quantity % 1 == 0
              ? item.quantity.toStringAsFixed(0)
              : item.quantity.toStringAsFixed(2).replaceAll('.', ',');

          buffer.writeln(
            "${tx.id};$dateStr;$flujo;${tx.category.toUpperCase()};$cleanProd;$qty;$cleanNote",
          );
        }
      }

      final utf8Bytes = utf8.encode(buffer.toString());
      final csvBytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8Bytes]);
      final csvFileName = 'Respaldo_Turso_$stamp.csv';

      if (baseDir != null) {
        final path = p.join(baseDir.path, csvFileName);
        await File(path).writeAsBytes(csvBytes);
        savedFiles.add(csvFileName);
      } else {
        await Printing.sharePdf(bytes: csvBytes, filename: csvFileName);
        savedFiles.add(csvFileName);
      }
    }

    // 3. RESPALDO EN PDF (Documento formal de auditoría)
    if (exportPdf) {
      final pdf = pw.Document();
      final List<List<String>> rows = [];

      for (final tx in transactions) {
        final dateStr = DateFormat('dd/MM/yy HH:mm').format(tx.timestamp);
        final flujo = tx.type == TransactionType.inbound ? 'ENT' : 'SAL';
        final itemsSummary = tx.items
            .map(
              (i) =>
                  "${i.productName} (${i.quantity % 1 == 0 ? i.quantity.toStringAsFixed(0) : i.quantity})",
            )
            .join(', ');

        rows.add([dateStr, flujo, tx.category.toUpperCase(), itemsSummary]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          build: (context) => [
            pw.Text(
              "RESPALDO HISTÓRICO DE AUDITORÍA - TRIPLE AAA",
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              "Movimientos anteriores al $cutoffStr  |  Total registros: ${transactions.length}",
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Divider(color: PdfColors.blueGrey),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ["FECHA", "TIPO", "CATEGORÍA", "PRODUCTOS Y CANTIDADES"],
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              columnWidths: {
                0: const pw.FixedColumnWidth(65),
                1: const pw.FixedColumnWidth(35),
                2: const pw.FixedColumnWidth(75),
                3: const pw.FlexColumnWidth(),
              },
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final pdfFileName = 'Respaldo_Turso_$stamp.pdf';

      if (baseDir != null) {
        final path = p.join(baseDir.path, pdfFileName);
        await File(path).writeAsBytes(pdfBytes);
        savedFiles.add(pdfFileName);
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: pdfFileName);
        savedFiles.add(pdfFileName);
      }
    }

    if (baseDir != null) {
      return "${baseDir.path} (${savedFiles.join(', ')})";
    }
    return savedFiles.join(', ');
  }
}
