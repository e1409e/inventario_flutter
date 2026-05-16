import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/entities/inventory_transaction.dart';
import '../state/inventory_cubit.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos la referencia al repositorio a través del Cubit
    final repository = context.read<InventoryCubit>().repository;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("HISTORIAL DE MOVIMIENTOS")),
      body: FutureBuilder<List<InventoryTransaction>>(
        // Llamamos al método que construimos en el repositorio
        future: repository.getTransactionHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error al cargar historial: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _buildTransactionCard(tx);
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(InventoryTransaction tx) {
    final isInbound = tx.type == TransactionType.inbound;
    final color = isInbound ? Colors.greenAccent : Colors.orangeAccent;
    final icon = isInbound
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final title = isInbound ? "ENTRADA" : "SALIDA";

    final formattedDate = DateFormat(
      'dd/MM/yyyy • hh:mm a',
    ).format(tx.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            // CORRECCIÓN APLICADA AQUÍ: Sin chequeos de null
            if (tx.description.isNotEmpty &&
                tx.description != "Sin descripción") ...[
              const SizedBox(height: 4),
              Text(
                tx.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tx.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        "${item.quantity} unds",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            "NO HAY MOVIMIENTOS REGISTRADOS",
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
