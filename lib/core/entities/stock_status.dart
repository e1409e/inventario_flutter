/// Representa el estado de existencias actual de un producto en almacén.
class StockStatus {
  /// Identificador del producto asociado en el catálogo.
  final String productId;

  /// Cantidad física disponible actualmente.
  final double currentQuantity;

  /// Fecha y hora de la última modificación de inventario.
  final DateTime lastUpdated;

  const StockStatus({
    required this.productId,
    required this.currentQuantity,
    required this.lastUpdated,
  });

  /// Evalúa si las existencias actuales están en o por debajo del mínimo requerido.
  bool isLowStock(double minStock) => currentQuantity <= minStock;
}
