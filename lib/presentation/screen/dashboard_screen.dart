import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../state/inventory_cubit.dart';
import '../state/inventory_state.dart';
import '../widgets/menu_card.dart';
import 'inventory_screen.dart';
import 'transactions_screen.dart';
import 'catalog_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Formateo de fecha industrial
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
          BlocBuilder<InventoryCubit, InventoryState>(
            builder: (context, state) {
              final isEmergency =
                  state is InventoryLoaded && state.isEmergencyMode;
              return Row(
                children: [
                  Text(
                    isEmergency ? "LOCAL" : "CLOUD",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: isEmergency
                          ? Colors.orangeAccent
                          : Colors.blueAccent,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isEmergency,
                      activeThumbColor: Colors.orangeAccent,
                      activeTrackColor: Colors.orangeAccent.withValues(
                        alpha: 0.3,
                      ),
                      onChanged: (_) =>
                          context.read<InventoryCubit>().toggleEmergencyMode(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          // Variables dinámicas para el dashboard
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

                // CARD: INVENTARIO (Estado Actual)
                MenuCard(
                  title: "Estado de Inventario",
                  subtitle: "Visualización de stock en tiempo real",
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

                // CARD: MOVIMIENTOS E HISTORIAL (Unificado)
                MenuCard(
                  title: "Movimientos",
                  subtitle:
                      "Registro de entradas, salidas e historial completo",
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
                _buildSectionHeader("ADMINISTRACIÓN"),
                const SizedBox(height: 12),

                // CARD: CATÁLOGO
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
}

class _ConnectionStatusBar extends StatelessWidget {
  const _ConnectionStatusBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        final isEmergency = state is InventoryLoaded && state.isEmergencyMode;
        final baseColor = isEmergency ? Colors.orangeAccent : Colors.blueAccent;

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
                    isEmergency
                        ? Icons.portable_wifi_off_rounded
                        : Icons.cloud_done_rounded,
                    color: baseColor,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEmergency
                        ? "MODO LOCAL (SQLITE)"
                        : "SISTEMA ONLINE (CLOUD)",
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
                  isEmergency ? "OFFLINE-STABLE" : "SYNC-ACTIVE",
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
