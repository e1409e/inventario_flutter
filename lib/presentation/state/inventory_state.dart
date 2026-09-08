import 'package:equatable/equatable.dart';
import '../../../core/entities/product.dart';
import '../../../core/entities/stock_status.dart';

abstract class InventoryState extends Equatable {
  const InventoryState();
  
  @override
  List<Object?> get props => [];
}

// 1. Estado inicial o de carga
class InventoryLoading extends InventoryState {}

// 2. Estado cuando los datos están listos
class InventoryLoaded extends InventoryState {
  final List<Product> products;
  final List<StockStatus> stockList;
  final bool isEmergencyMode;
  final String? errorMessage;

  const InventoryLoaded({
    required this.products,
    required this.stockList,
    required this.isEmergencyMode,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [products, stockList, isEmergencyMode, errorMessage];
}

// 3. Estado de error crítico
class InventoryError extends InventoryState {
  final String message;
  const InventoryError(this.message);

  @override
  List<Object?> get props => [message];
}