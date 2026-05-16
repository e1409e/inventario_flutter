import '../entities/product.dart';
import '../entities/stock_status.dart';
import '../entities/inventory_transaction.dart';

abstract class InventoryRepository {
  // --- GESTIÓN DE PRODUCTOS ---

  /// Obtiene todos los productos (activos e inactivos)
  Future<List<Product>> getAllProducts();

  /// Guarda la información básica de un producto nuevo
  Future<void> saveProduct(Product product);

  /// Actualiza la información de un producto existente
  Future<void> updateProduct(Product product);

  // --- GESTIÓN DE STOCK Y MOVIMIENTOS ---

  /// Registra una entrada o Salida.
  /// Debe ser una operación ATÓMICA (afecta movimientos y stock al mismo tiempo).
  Future<void> registerTransaction(InventoryTransaction transaction);

  /// Obtiene el estado de stock actual de un producto específico
  Future<StockStatus?> getStockByProduct(String productId);

  /// Obtiene todos los estados de stock (para la lista principal)
  Future<List<StockStatus>> getAllStockStatus();

  /// Obtiene el historial completo de movimientos (cabeceras y detalles)
  Future<List<InventoryTransaction>> getTransactionHistory();

  // --- MODO EMERGENCIA Y SINCRONIZACIÓN ---

  /// Sincroniza los datos locales pendientes con la nube (Supabase)
  Future<void> syncPendingData();

  /// Cambia entre base de datos local (SQLite) y nube
  void toggleEmergencyMode(bool isEnabled);
}
