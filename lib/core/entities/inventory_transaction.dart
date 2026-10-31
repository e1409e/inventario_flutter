import 'transaction_item.dart';

enum TransactionType { inbound, outbound }

class TransactionCategories {
  static const String defaultCategory = 'Sin Definir';

  static const List<String> outboundCategories = [
    'Facturas',
    'Tienda',
    'Deposito 2',
    'Averia',
    'Ajuste de inventario',
    'Prestamo',
    'Sin Definir',
  ];

  static const List<String> inboundCategories = [
    'Entrega',
    'Devolucion',
    'Traslado',
    'Prestadas',
    'Sin Definir',
  ];

  static List<String> forType(TransactionType type) {
    return type == TransactionType.inbound
        ? inboundCategories
        : outboundCategories;
  }
}

class InventoryTransaction {
  final String id; // UUID
  final DateTime timestamp;
  final TransactionType type;
  final String category; // <-- NUEVO CAMPO DE CATEGORÍA
  final String description;
  final List<TransactionItem> items;
  final bool isSynced;
  final String? userId;

  InventoryTransaction({
    required this.id,
    required this.timestamp,
    required this.type,
    this.category = TransactionCategories.defaultCategory,
    required this.description,
    required this.items,
    this.isSynced = false,
    this.userId,
  });

  bool containsProduct(String productId) {
    return items.any((item) => item.productId == productId);
  }

  InventoryTransaction copyWith({bool? isSynced, String? category}) {
    return InventoryTransaction(
      id: id,
      timestamp: timestamp,
      type: type,
      category: category ?? this.category,
      description: description,
      items: items,
      userId: userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
