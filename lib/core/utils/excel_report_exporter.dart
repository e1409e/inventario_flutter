import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import '../entities/inventory_transaction.dart';
import '../entities/paginated_transactions.dart';

class ExcelReportExporter {
  /// Genera un archivo CSV con BOM UTF-8 (compatible nativamente con Excel en español)
  /// En Windows/Linux lo guarda en Descargas o Documentos; en Android abre el menú Compartir.
  static Future<String> exportDailyMovementToExcelCsv({
    required List<DailyProductMovement> movements,
    required DateTime reportDate,
    required TransactionType type,
  }) async {
    final isInbound = type == TransactionType.inbound;
    final tipoStr = isInbound ? "ENTRADAS" : "SALIDAS";
    final dateFileStr = DateFormat('yyyy-MM-dd').format(reportDate);
    final dateDisplayStr = DateFormat('dd/MM/yyyy').format(reportDate);

    final buffer = StringBuffer();

    // Encabezado informativo
    buffer.writeln("TRIPLE AAA FOOD DISTRIBUTION - REPORTE DIARIO DE $tipoStr");
    buffer.writeln("FECHA OPERATIVA:;$dateDisplayStr");
    buffer.writeln("PRODUCTOS MOVILIZADOS:;${movements.length}");
    buffer.writeln("");

    // Cabeceras de columnas (usamos ';' para que Excel en español separe las columnas automáticamente)
    buffer.writeln(
      "IPN / CODIGO;PRODUCTO;CANTIDAD TOTAL;UNIDAD;TIPO MOVIMIENTO;FECHA",
    );

    for (final m in movements) {
      final sku = (m.sku != null && m.sku!.isNotEmpty) ? m.sku! : 'N/A';
      final cleanName = m.productName.replaceAll(';', ',').toUpperCase();
      final qtyStr = m.totalQuantity % 1 == 0
          ? m.totalQuantity.toStringAsFixed(0)
          : m.totalQuantity.toStringAsFixed(2).replaceAll('.', ',');

      buffer.writeln(
        "$sku;$cleanName;$qtyStr;${m.unit.toUpperCase()};$tipoStr;$dateDisplayStr",
      );
    }

    // Agregamos BOM UTF-8 (0xEF, 0xBB, 0xBF) para que Excel reconozca tildes y Ñ sin errores
    final utf8Bytes = utf8.encode(buffer.toString());
    final bytesWithBom = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8Bytes]);

    final fileName = "Reporte_${tipoStr}_TripleAAA_$dateFileStr.csv";

    // En Escritorio (Windows / Linux) guardamos directamente en Descargas o Documentos
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      Directory? targetDir = await getDownloadsDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final filePath = p.join(targetDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(bytesWithBom);
      return filePath;
    } else {
      // En Android / iOS abrimos el diálogo nativo para guardar o enviar por WhatsApp/Correo
      await Printing.sharePdf(bytes: bytesWithBom, filename: fileName);
      return "Compartido exitosamente ($fileName)";
    }
  }
}
