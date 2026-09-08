// lib/presentation/widgets/transaction_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/entities/inventory_transaction.dart';

class TransactionCard extends StatelessWidget {
  final InventoryTransaction transaction;

  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final bool isInbound = transaction.type == TransactionType.inbound;
    final Color accentColor = isInbound ? Colors.greenAccent : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4), // Look más cuadrado/industrial
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isInbound ? Icons.add_box : Icons.unarchive, color: accentColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isInbound ? "ENTRADA" : "SALIDA",
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                  ),
                ],
              ),
              Text(
                DateFormat('HH:mm | dd/MM/yy').format(transaction.timestamp),
                style: const TextStyle(fontSize: 10, color: Colors.white38, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            transaction.description,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            "${transaction.items.length} productos afectados",
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}