/// Representa una línea de detalle dentro de una transacción de inventario.
class TransactionItem {
  /// Identificador del producto afectado.
  final String productId;

  /// Nombre del producto registrado al momento de la operación.
  final String productName;

  /// Cantidad de unidades movilizadas en la operación.
  final double quantity;

  const TransactionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  /// Retorna el valor absoluto de la cantidad movilizada.
  double get absQuantity => quantity.abs();
}
