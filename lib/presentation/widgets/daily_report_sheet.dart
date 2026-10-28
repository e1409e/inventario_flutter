import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/entities/inventory_transaction.dart';
import '../../core/entities/paginated_transactions.dart';
import '../../core/utils/pdf_report_generator.dart';
import '../../core/utils/excel_report_exporter.dart';
import '../state/inventory_cubit.dart';

class DailyReportSheet extends StatefulWidget {
  const DailyReportSheet({super.key});

  @override
  State<DailyReportSheet> createState() => _DailyReportSheetState();
}

class _DailyReportSheetState extends State<DailyReportSheet> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _error;

  List<DailyProductMovement> _inboundMovements = [];
  List<DailyProductMovement> _outboundMovements = [];

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = context.read<InventoryCubit>().repository;

      // Consultamos en paralelo el total de entradas y salidas del día elegido
      final results = await Future.wait([
        repo.getDailyMovementsSummary(
          date: _selectedDate,
          type: TransactionType.inbound,
        ),
        repo.getDailyMovementsSummary(
          date: _selectedDate,
          type: TransactionType.outbound,
        ),
      ]);

      if (mounted) {
        setState(() {
          _inboundMovements = results[0];
          _outboundMovements = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadDailyData();
    }
  }

  Future<void> _exportPdf(TransactionType type) async {
    final isInbound = type == TransactionType.inbound;
    final data = isInbound ? _inboundMovements : _outboundMovements;

    if (data.isEmpty) {
      _showSnack(
        "No hay ${isInbound ? 'entradas' : 'salidas'} registradas en esta fecha.",
        isError: true,
      );
      return;
    }

    try {
      final pdfBytes = await PdfReportGenerator.generateDailyMovementReport(
        movements: data,
        reportDate: _selectedDate,
        type: type,
      );

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final tipoStr = isInbound ? 'Entradas' : 'Salidas';

      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Reporte_Diario_${tipoStr}_$dateStr.pdf',
        );
      }
    } catch (e) {
      _showSnack("Error al generar PDF: $e", isError: true);
    }
  }

  Future<void> _exportExcel(TransactionType type) async {
    final isInbound = type == TransactionType.inbound;
    final data = isInbound ? _inboundMovements : _outboundMovements;

    if (data.isEmpty) {
      _showSnack(
        "No hay ${isInbound ? 'entradas' : 'salidas'} registradas en esta fecha.",
        isError: true,
      );
      return;
    }

    try {
      final resultPath =
          await ExcelReportExporter.exportDailyMovementToExcelCsv(
            movements: data,
            reportDate: _selectedDate,
            type: type,
          );
      _showSnack("Archivo Excel (CSV) listo: $resultPath");
    } catch (e) {
      _showSnack("Error al exportar Excel: $e", isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: isError ? Colors.redAccent : Colors.teal.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del Modal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "REPORTES DIARIOS POR FLUJO",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Totales consolidados por producto y fecha única",
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),

          // Selector de Día
          Row(
            children: [
              const Text(
                "FECHA DEL REPORTE:",
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Colors.blueAccent,
                  ),
                  label: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blueAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                "Error al consultar el día: $_error",
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            )
          else ...[
            // TARJETA 1: REPORTE DE ENTRADAS DEL DÍA
            _buildReportSectionCard(
              title: "REPORTE DE ENTRADAS",
              subtitle:
                  "${_inboundMovements.length} productos ingresaron el $formattedDate",
              color: Colors.greenAccent,
              icon: Icons.arrow_downward_rounded,
              items: _inboundMovements,
              onPdfTap: () => _exportPdf(TransactionType.inbound),
              onExcelTap: () => _exportExcel(TransactionType.inbound),
            ),
            const SizedBox(height: 14),

            // TARJETA 2: REPORTE DE SALIDAS DEL DÍA
            _buildReportSectionCard(
              title: "REPORTE DE SALIDAS",
              subtitle:
                  "${_outboundMovements.length} productos salieron el $formattedDate",
              color: Colors.orangeAccent,
              icon: Icons.arrow_upward_rounded,
              items: _outboundMovements,
              onPdfTap: () => _exportPdf(TransactionType.outbound),
              onExcelTap: () => _exportExcel(TransactionType.outbound),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildReportSectionCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required List<DailyProductMovement> items,
    required VoidCallback onPdfTap,
    required VoidCallback onExcelTap,
  }) {
    final bool hasData = items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasData ? color.withValues(alpha: 0.35) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Botón PDF / Imprimir
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: hasData ? onPdfTap : null,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text(
                    "PDF / IMPRIMIR",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Botón EXCEL (CSV)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasData ? onExcelTap : null,
                  icon: const Icon(Icons.table_view_rounded, size: 16),
                  label: const Text(
                    "EXCEL (CSV)",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    side: BorderSide(
                      color: hasData
                          ? Colors.greenAccent.withValues(alpha: 0.6)
                          : Colors.white10,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
