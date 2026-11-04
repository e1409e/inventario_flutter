import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/backup_exporter.dart';
import '../state/inventory_cubit.dart';
import '../state/inventory_state.dart';
import '../widgets/menu_card.dart';
import 'catalog_screen.dart';
import 'inventory_screen.dart';
import 'transactions_screen.dart';

/// Pantalla principal de navegación y administración del sistema de almacén.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());
    final String dayName = DateFormat(
      'EEEE',
    ).format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TRIPLE AAA | WAREHOUSE'),
            Text(
              '$dayName // $formattedDate',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.sync_rounded,
              size: 20,
              color: Colors.blueAccent,
            ),
            tooltip: 'Sincronizar catálogo y existencias',
            onPressed: () => context.read<InventoryCubit>().loadInventory(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          int productCount = 0;

          if (state is InventoryLoaded) {
            productCount = state.products.length;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("OPERACIONES DIARIAS"),
                const SizedBox(height: 12),

                MenuCard(
                  title: "Estado de Inventario",
                  subtitle: "Visualización de stock y reportes en tiempo real",
                  icon: Icons.inventory_2_outlined,
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InventoryScreen(),
                      ),
                    );
                  },
                ),

                MenuCard(
                  title: "Movimientos",
                  subtitle:
                      "Registro de entradas, salidas, historial y cierres diarios",
                  icon: Icons.swap_vert_rounded,
                  color: Colors.greenAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TransactionsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("ADMINISTRACIÓN Y MANTENIMIENTO"),
                const SizedBox(height: 12),

                MenuCard(
                  title: "Catálogo Maestro",
                  subtitle: "$productCount productos registrados",
                  icon: Icons.settings_outlined,
                  color: Colors.purpleAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CatalogScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                MenuCard(
                  title: "Mantenimiento de Base de Datos",
                  subtitle:
                      "Respaldar en bóveda local/archivos y depurar historial (> 3 meses)",
                  icon: Icons.cleaning_services_rounded,
                  color: Colors.redAccent,
                  onTap: () => _showPurgeConfirmationDialog(context),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const _ConnectionStatusBar(),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  /// Ejecuta el asistente de respaldo histórico (SQLite local, JSON, CSV y PDF)
  /// antes de eliminar de Turso los registros con antigüedad superior a 90 días.
  Future<void> _showPurgeConfirmationDialog(BuildContext context) async {
    final repository = context.read<InventoryCubit>().repository;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    final cutoffFormatted = DateFormat('dd/MM/yyyy').format(cutoffDate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final oldTransactions = await repository.getTransactionsOlderThan(
        cutoffDate,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (oldTransactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No existen movimientos anteriores al $cutoffFormatted (> 3 meses) para depurar.",
            ),
            backgroundColor: Colors.blueGrey,
          ),
        );
        return;
      }

      bool exportJson = true;
      bool exportExcel = true;
      bool exportPdf = true;
      bool isProcessing = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent, width: 0.8),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "RESPALDO Y DEPURACIÓN HISTÓRICA",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Se detectaron ${oldTransactions.length} movimientos anteriores al $cutoffFormatted.",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "• Se archivarán automáticamente en la bóveda SQLite local.\n"
                        "• El stock actual de los productos permanece intacto.\n"
                        "• Selecciona los formatos adicionales de exportación:",
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: exportJson,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.blueAccent,
                        title: const Text(
                          "Respaldo JSON (Estructura completa)",
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: isProcessing
                            ? null
                            : (v) =>
                                  setDialogState(() => exportJson = v ?? true),
                      ),
                      CheckboxListTile(
                        value: exportExcel,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.greenAccent,
                        title: const Text(
                          "Respaldo Excel (CSV detallado)",
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: isProcessing
                            ? null
                            : (v) =>
                                  setDialogState(() => exportExcel = v ?? true),
                      ),
                      CheckboxListTile(
                        value: exportPdf,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.redAccent,
                        title: const Text(
                          "Reporte PDF de Auditoría",
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: isProcessing
                            ? null
                            : (v) =>
                                  setDialogState(() => exportPdf = v ?? true),
                      ),
                      if (isProcessing) ...[
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Generando respaldos y depurando Turso...",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isProcessing
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text(
                      "CANCELAR",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            if (!exportJson && !exportExcel && !exportPdf) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Selecciona al menos un formato de archivo antes de continuar.",
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isProcessing = true);

                            try {
                              final backupPath =
                                  await BackupExporter.generateFullBackupFiles(
                                    transactions: oldTransactions,
                                    cutoffDate: cutoffDate,
                                    exportJson: exportJson,
                                    exportExcel: exportExcel,
                                    exportPdf: exportPdf,
                                  );

                              final deletedCount = await repository
                                  .archiveLocallyAndDeleteFromCloud(
                                    oldTransactions,
                                    cutoffDate,
                                  );

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 6),
                                    backgroundColor: Colors.teal.shade800,
                                    content: Text(
                                      "Mantenimiento completado: $deletedCount movimientos archivados.\nUbicación: $backupPath",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isProcessing = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.redAccent,
                                    content: Text(
                                      "Operación abortada por seguridad (sin cambios en Turso): $e",
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.backup_rounded, size: 16),
                    label: const Text(
                      "RESPALDAR Y DEPURAR",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al consultar registros históricos: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

/// Barra inferior de estado operativo del sistema.
class _ConnectionStatusBar extends StatelessWidget {
  const _ConnectionStatusBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        final hasError = state is InventoryError;
        final baseColor = hasError ? Colors.redAccent : Colors.blueAccent;

        return Container(
          height: 28,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.05),
            border: Border(
              top: BorderSide(
                color: baseColor.withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasError
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_done_rounded,
                    color: baseColor,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasError
                        ? "ERROR DE CONEXIÓN REMOTA"
                        : "SISTEMA ONLINE (TURSO CLOUD + BÓVEDA LOCAL)",
                    style: TextStyle(
                      color: baseColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (state is InventoryLoading)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white30,
                  ),
                )
              else
                Text(
                  hasError ? "RETRY-REQUIRED" : "CLOUD-READY",
                  style: TextStyle(
                    color: baseColor.withValues(alpha: 0.5),
                    fontSize: 8,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
