import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/entities/inventory_transaction.dart';
import '../../../core/entities/product.dart';
import '../../../core/entities/stock_status.dart';
import '../../../core/entities/transaction_item.dart';
import '../../../core/repositories/inventory_repository.dart';
import 'inventory_state.dart';

/// Controlador de estado principal para las operaciones de catálogo, existencias y movimientos.
class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository repository;
  final Uuid _uuid = const Uuid();

  InventoryCubit({required this.repository}) : super(InventoryLoading());

  /// Descarga en paralelo el catálogo de productos y el estado de existencias actual.
  Future<void> loadInventory() async {
    try {
      final productsFuture = repository.getAllProducts();
      final stockFuture = repository.getAllStockStatus();

      final products = await productsFuture;
      final stock = await stockFuture;

      emit(InventoryLoaded(products: products, stockList: stock));
    } catch (e) {
      emit(InventoryError("Error de conexión: ${e.toString()}"));
    }
  }

  /// Registra una transacción de entrada o salida y actualiza el stock en memoria
  /// para evitar lecturas redundantes hacia la base de datos remota.
  Future<void> registerMovement({
    required TransactionType type,
    required Map<String, double> items,
    String? category,
    String? description,
    DateTime? customDate,
  }) async {
    try {
      final currentState = state;
      if (currentState is! InventoryLoaded) return;

      final transaction = InventoryTransaction(
        id: _uuid.v4(),
        timestamp: customDate ?? DateTime.now(),
        type: type,
        category: category ?? TransactionCategories.defaultCategory,
        description: description ?? "Sin descripcion",
        items: items.entries.map((e) {
          final product = currentState.products.firstWhere(
            (p) => p.id == e.key,
            orElse: () => throw Exception("Producto no encontrado"),
          );

          return TransactionItem(
            productId: e.key,
            productName: product.name,
            quantity: e.value,
          );
        }).toList(),
      );

      await repository.registerTransaction(transaction);

      final Map<String, StockStatus> stockMap = {
        for (final s in currentState.stockList) s.productId: s,
      };

      final now = DateTime.now();
      for (final entry in items.entries) {
        final existing = stockMap[entry.key];
        final currentQty = existing?.currentQuantity ?? 0.0;
        final newQty = type == TransactionType.inbound
            ? currentQty + entry.value
            : currentQty - entry.value;

        stockMap[entry.key] = StockStatus(
          productId: entry.key,
          currentQuantity: newQty,
          lastUpdated: now,
        );
      }

      emit(
        InventoryLoaded(
          products: currentState.products,
          stockList: stockMap.values.toList(),
        ),
      );
    } catch (e) {
      emit(InventoryError("No se pudo registrar el movimiento: $e"));
    }
  }

  /// Registra un nuevo producto en el catálogo maestro.
  Future<void> addProduct({
    required String name,
    required String unit,
    String? sku,
  }) async {
    try {
      final newProduct = Product(
        id: _uuid.v4(),
        name: name,
        unit: unit,
        sku: sku,
      );

      await repository.saveProduct(newProduct);
      await loadInventory();
    } catch (e) {
      emit(InventoryError("Error al crear producto: $e"));
    }
  }

  /// Actualiza la información de un producto existente en el catálogo.
  Future<void> updateProduct(Product updatedProduct) async {
    try {
      await repository.updateProduct(updatedProduct);
      await loadInventory();
    } catch (e) {
      debugPrint("Error al actualizar producto: $e");
      emit(const InventoryError("Error al actualizar producto"));
    }
  }
}
