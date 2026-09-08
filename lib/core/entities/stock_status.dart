class StockStatus {
  final String productId;
  final double currentQuantity;
  final DateTime lastUpdated;

  StockStatus({
    required this.productId,
    required this.currentQuantity,
    required this.lastUpdated,
  });

  // Un getter útil para saber si estamos en alerta roja
  bool isLowStock(double minStock) => currentQuantity <= minStock;
}