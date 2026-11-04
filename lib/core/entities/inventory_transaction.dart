import 'transaction_item.dart';

/// Define la dirección del flujo de mercancía en el almacén.
enum TransactionType { inbound, outbound }

/// Catálogo centralizado de motivos operativos para clasificar movimientos.
class TransactionCategories {
  static const String defaultCategory = 'Sin Definir';

  /// Categorías válidas para salidas de almacén ([TransactionType.outbound]).
  static const List<String> outboundCategories = [
    'Facturas',
    'Tienda',
    'Deposito 2',
    'Averia',
    'Ajuste de inventario',
    'Prestamo',
    'Sin Definir',
  ];

  /// Categorías válidas para entradas de almacén ([TransactionType.inbound]).
  static const List<String> inboundCategories = [
    'Entrega',
    'Devolucion',
    'Traslado',
    'Prestadas',
    'Sin Definir',
  ];

  /// Retorna la lista de categorías correspondiente al [type] especificado.
  static List<String> forType(TransactionType type) {
    return type == TransactionType.inbound
        ? inboundCategories
        : outboundCategories;
  }
}

/// Representa un movimiento de inventario (entrada o salida) con su detalle.
class InventoryTransaction {
  /// Identificador único de la transacción (UUID v4).
  final String id;

  /// Fecha y hora contable del movimiento.
  final DateTime timestamp;

  /// Tipo de operación (entrada o salida).
  final TransactionType type;

  /// Categoría operativa del movimiento.
  final String category;

  /// Nota u observación adicional asociada al registro.
  final String description;

  /// Lista de productos y cantidades involucradas en la operación.
  final List<TransactionItem> items;

  /// Indica si el registro se encuentra respaldado en la nube.
  final bool isSynced;

  /// Identificador opcional del operador responsable (auditoría).
  final String? userId;

  const InventoryTransaction({
    required this.id,
    required this.timestamp,
    required this.type,
    this.category = TransactionCategories.defaultCategory,
    required this.description,
    required this.items,
    this.isSynced = true,
    this.userId,
  });

  /// Verifica si un producto específico forma parte de esta transacción.
  bool containsProduct(String productId) {
    return items.any((item) => item.productId == productId);
  }

  /// Crea una copia de la transacción actualizando las propiedades indicadas.
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
