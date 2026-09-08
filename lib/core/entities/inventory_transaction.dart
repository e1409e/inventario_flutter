import 'transaction_item.dart';
enum TransactionType { inbound, outbound }

class InventoryTransaction {
  final String id; // UUID
  final DateTime timestamp;
  final TransactionType type;
  final String description;
  final List<TransactionItem> items;
  final bool isSynced;
  final String? userId; // ¿Quién hizo el movimiento? (Para auditoría)

  InventoryTransaction({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.description,
    required this.items,
    this.isSynced = false,
    this.userId,
  });

  // Permite saber si un producto específico participó en esta transacción.
  bool containsProduct(String productId) {
    return items.any((item) => item.productId == productId);
  }

  // Método copyWith para cuando la app logre sincronizar con Supabase
  InventoryTransaction copyWith({bool? isSynced}) {
    return InventoryTransaction(
      id: id,
      timestamp: timestamp,
      type: type,
      description: description,
      items: items,
      userId: userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}