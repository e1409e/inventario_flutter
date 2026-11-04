import 'package:equatable/equatable.dart';
import '../../../core/entities/product.dart';
import '../../../core/entities/stock_status.dart';

/// Estado base para la gestión del inventario y catálogo maestro.
abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => [];
}

/// Estado emitido durante la carga inicial o sincronización de datos.
class InventoryLoading extends InventoryState {}

/// Estado emitido cuando el catálogo y las existencias están disponibles en memoria.
class InventoryLoaded extends InventoryState {
  final List<Product> products;
  final List<StockStatus> stockList;
  final String? errorMessage;

  const InventoryLoaded({
    required this.products,
    required this.stockList,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [products, stockList, errorMessage];
}

/// Estado emitido cuando ocurre una excepción crítica en la capa de datos.
class InventoryError extends InventoryState {
  final String message;

  const InventoryError(this.message);

  @override
  List<Object?> get props => [message];
}
