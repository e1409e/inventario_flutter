import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../core/entities/product.dart';
import '../../core/entities/stock_status.dart';
import '../../core/entities/inventory_transaction.dart';
import '../../core/entities/paginated_transactions.dart';

class PdfReportGenerator {
  static Future<Uint8List> generateStockReport({
    required List<Product> products,
    required List<StockStatus> stockList,
    required Set<String> selectedIds,
  }) async {
    final pdf = pw.Document();
    final itemsToReport = selectedIds.isNotEmpty
        ? products.where((p) => selectedIds.contains(p.id)).toList()
        : products;

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // --- MAPEO DE DATOS SEGÚN TU FORMATO ---
    final List<List<String>> tableData = itemsToReport.map((p) {
      final stockMatch = stockList.where((s) => s.productId == p.id);
      final currentQuantity = stockMatch.isNotEmpty
          ? stockMatch.first.currentQuantity
          : 0.0;

      return [
        p.sku ?? 'N/A', // Columna 1: IPN / Código
        p.name.toUpperCase(), // Columna 2: Producto (Nombre)
        "${currentQuantity.toStringAsFixed(0)} ${p.unit.toUpperCase()}", // Columna 3: Stock Actual
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (pw.Context context) {
          return [
            // --- ENCABEZADO REFINADO ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "REPORTE DE ÍTEMS DE STOCK - TRIPLE AAA",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Triple AAA Food Distribution",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "Gestión de Inventario - San Francisco, Zulia",
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Lotes detectados: ${itemsToReport.length}",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "ID Operación: ${DateTime.now().millisecondsSinceEpoch}",
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 1, color: PdfColors.blueGrey),
            pw.SizedBox(height: 15),

            // --- TABLA ESTILO INDUSTRIAL ---
            pw.TableHelper.fromTextArray(
              headers: ["IPN / CÓDIGO", "PRODUCTO", "STOCK ACTUAL"],
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20.0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Generado el: $dateStr // TRIPLE AAA WAREHOUSE SYSTEM",
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey700,
                    font: pw.Font.courier(),
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// --- NUEVO: GENERADOR DE REPORTE DIARIO DE ENTRADAS O SALIDAS ---
  static Future<Uint8List> generateDailyMovementReport({
    required List<DailyProductMovement> movements,
    required DateTime reportDate,
    required TransactionType type,
  }) async {
    final pdf = pw.Document();
    final isInbound = type == TransactionType.inbound;

    final reportTitle = isInbound
        ? "REPORTE DIARIO DE ENTRADAS - TRIPLE AAA"
        : "REPORTE DIARIO DE SALIDAS - TRIPLE AAA";

    final quantityHeader = isInbound ? "TOTAL ENTRADA" : "TOTAL SALIDA";
    final accentColor = isInbound ? PdfColors.teal900 : PdfColors.deepOrange900;

    final targetDateStr = DateFormat('dd/MM/yyyy').format(reportDate);
    final generatedDateStr = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.now());

    // Calculamos la suma general de unidades/cajas movidas ese día
    final double grandTotal = movements.fold(
      0.0,
      (sum, item) => sum + item.totalQuantity,
    );

    final List<List<String>> tableData = movements.map((m) {
      final qtyFormatted = m.totalQuantity % 1 == 0
          ? m.totalQuantity.toStringAsFixed(0)
          : m.totalQuantity.toStringAsFixed(2);

      return [
        m.sku != null && m.sku!.isNotEmpty ? m.sku! : 'N/A',
        m.productName.toUpperCase(),
        "$qtyFormatted ${m.unit.toUpperCase()}",
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(35),
        build: (pw.Context context) {
          return [
            // --- ENCABEZADO INDUSTRIAL ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      reportTitle,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Triple AAA Food Distribution",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "Gestión de Inventario - San Francisco, Zulia",
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "FECHA OPERATIVA: $targetDateStr",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Productos movilizados: ${movements.length}",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "ID Operación: ${DateTime.now().millisecondsSinceEpoch}",
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 1, color: PdfColors.blueGrey),
            pw.SizedBox(height: 15),

            // --- TABLA DE PRODUCTOS MOVILIZADOS ---
            pw.TableHelper.fromTextArray(
              headers: ["IPN / CÓDIGO", "PRODUCTO", quantityHeader],
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
            ),

            pw.SizedBox(height: 12),

            // --- RESUMEN TOTAL AL FINAL DE LA TABLA ---
            pw.Container(
              alignment: pw.Alignment.centerRight,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Text(
                "TOTAL UNIDADES / BULTOS MOVILIZADOS: ${grandTotal % 1 == 0 ? grandTotal.toStringAsFixed(0) : grandTotal.toStringAsFixed(2)}",
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20.0),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Generado el: $generatedDateStr // TRIPLE AAA WAREHOUSE SYSTEM",
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey700,
                    font: pw.Font.courier(),
                  ),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
