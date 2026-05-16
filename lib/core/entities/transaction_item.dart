class TransactionItem {
  final String productId;
  final String productName; 
  final double quantity;

  TransactionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  // Profesor: Agregamos este método para cálculos de peso/volumen si fuera necesario
  double get absQuantity => quantity.abs(); 
}