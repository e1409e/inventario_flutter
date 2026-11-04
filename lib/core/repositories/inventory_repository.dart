import '../entities/product.dart';
import '../entities/stock_status.dart';
import '../entities/inventory_transaction.dart';
import '../entities/paginated_transactions.dart';

/// Contrato principal para la gestión de catálogo, existencias, movimientos y respaldos.
abstract class InventoryRepository {
  // --- CATÁLOGO DE PRODUCTOS ---

  /// Obtiene la lista completa de productos registrados en el catálogo.
  Future<List<Product>> getAllProducts();

  /// Registra un nuevo producto en la base de datos principal.
  Future<void> saveProduct(Product product);

  /// Actualiza los datos de un producto existente en el catálogo.
  Future<void> updateProduct(Product product);

  // --- EXISTENCIAS Y MOVIMIENTOS ---

  /// Registra una transacción de entrada o salida actualizando el stock de forma atómica.
  Future<void> registerTransaction(InventoryTransaction transaction);

  /// Consulta la existencia actual de un producto específico por su [productId].
  Future<StockStatus?> getStockByProduct(String productId);

  /// Obtiene el estado de stock actual de todos los productos.
  Future<List<StockStatus>> getAllStockStatus();

  /// Obtiene una página de movimientos filtrada directamente desde la base de datos remota.
  Future<PaginatedTransactions> getTransactionsPaginated({
    required int page,
    int pageSize = 15,
    TransactionType? type,
    String? category,
    String? searchQuery,
  });

  /// Obtiene los totales consolidados por producto para una fecha y flujo específicos.
  Future<List<DailyProductMovement>> getDailyMovementsSummary({
    required DateTime date,
    required TransactionType type,
    String? category,
  });

  // --- MANTENIMIENTO Y BÓVEDA DE RESPALDO LOCAL ---

  /// Consulta las transacciones registradas antes de [cutoffDate] para procesos de respaldo.
  Future<List<InventoryTransaction>> getTransactionsOlderThan(
    DateTime cutoffDate,
  );

  /// Archiva las transacciones antiguas en la base de datos local (SQLite) y las depura de Turso.
  Future<int> archiveLocallyAndDeleteFromCloud(
    List<InventoryTransaction> oldTransactions,
    DateTime cutoffDate,
  );
}
