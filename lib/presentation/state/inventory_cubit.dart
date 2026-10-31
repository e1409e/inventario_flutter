import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/repositories/inventory_repository.dart';
import 'inventory_state.dart';
import '../../../core/entities/inventory_transaction.dart';
import '../../../core/entities/transaction_item.dart';
import '../../../core/entities/product.dart';
import '../../../core/entities/stock_status.dart';
import 'package:flutter/foundation.dart';

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository repository;
  final Uuid _uuid = const Uuid();

  InventoryCubit({required this.repository}) : super(InventoryLoading());

  /// Carga inicial de datos en paralelo desde Turso
  Future<void> loadInventory() async {
    bool isEmergency = false;
    if (state is InventoryLoaded) {
      isEmergency = (state as InventoryLoaded).isEmergencyMode;
    }

    try {
      // Disparamos ambas consultas al mismo tiempo (en paralelo)
      final productsFuture = repository.getAllProducts();
      final stockFuture = repository.getAllStockStatus();

      // Esperamos los resultados ya tipados
      final products = await productsFuture;
      final stock = await stockFuture;

      emit(
        InventoryLoaded(
          products: products,
          stockList: stock,
          isEmergencyMode: isEmergency,
        ),
      );
    } catch (e) {
      emit(InventoryError("Error de conexion: ${e.toString()}"));
    }
  }

  /// Cambia entre base de datos local y remota
  void toggleEmergencyMode() async {
    if (state is InventoryLoaded) {
      final currentState = state as InventoryLoaded;
      final newMode = !currentState.isEmergencyMode;

      // Cambiamos el switch en el repositorio
      repository.toggleEmergencyMode(newMode);

      // Feedback visual inmediato
      emit(
        InventoryLoaded(
          products: currentState.products,
          stockList: currentState.stockList,
          isEmergencyMode: newMode,
        ),
      );

      // Si volvemos a la NUBE (newMode == false), disparamos sincronización total
      if (!newMode) {
        try {
          // Empuja cambios locales a la nube
          await repository.syncPendingData();
        } catch (e) {
          debugPrint("Error al sincronizar al volver a la nube: $e");
        }
      }

      // Recargamos todo para asegurar que la UI refleje la fuente de datos correcta
      await loadInventory();
    }
  }

  /// Registra movimientos (Entradas/Salidas)
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

      // Tras registrar, recargamos para actualizar el stock visible
      await loadInventory();
    } catch (e) {
      emit(InventoryError("No se pudo registrar el movimiento: $e"));
    }
  }

  /// Crea un nuevo producto en el catálogo
  Future<void> addProduct({
    required String name,
    required String unit,
    String? sku,
  }) async {
    try {
      final newProduct = Product(
        id: _uuid
            .v4(), // Cambiado a UUID compatible con la clave primaria de la nube
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

  /// Actualiza un producto existente
  Future<void> updateProduct(Product updatedProduct) async {
    try {
      await repository.updateProduct(updatedProduct);
      await loadInventory();
    } catch (e) {
      debugPrint("Error al editar producto: $e");
      emit(InventoryError("Error al actualizar producto"));
    }
  }
}
