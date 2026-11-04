import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../core/entities/inventory_transaction.dart';
import '../../core/entities/paginated_transactions.dart';
import '../../core/entities/product.dart';
import '../../core/entities/stock_status.dart';
import '../../core/entities/transaction_item.dart';
import '../../core/repositories/inventory_repository.dart';
import '../datasources/local_database.dart';
import '../datasources/remote_datasource.dart';
import '../models/product_model.dart';
import '../models/stock_model.dart';
import '../models/transaction_model.dart';

/// Implementación principal de [InventoryRepository].
/// Centraliza las operaciones en tiempo real sobre Turso y emplea [LocalDatabase]
/// como bóveda de archivo histórico y contingencia local.
class InventoryRepositoryImpl implements InventoryRepository {
  final LocalDatabase localDb;
  final RemoteDataSource remoteDataSource;

  InventoryRepositoryImpl({
    required this.localDb,
    required this.remoteDataSource,
  });

  // --- GESTIÓN DE PRODUCTOS ---

  @override
  Future<List<Product>> getAllProducts() async {
    try {
      final remoteJson = await remoteDataSource.fetchProducts();
      return remoteJson.map((e) => ProductModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Contingencia activada en getAllProducts (lectura local): $e");
      final localData = await localDb.select(localDb.productsTable).get();
      return localData.map((e) => ProductModel.fromDrift(e)).toList();
    }
  }

  @override
  Future<void> saveProduct(Product product) async {
    final model = ProductModel(
      id: product.id,
      name: product.name,
      unit: product.unit,
      sku: product.sku,
      isSynced: true,
    );

    await remoteDataSource.uploadProduct(model.toJson());
  }

  @override
  Future<void> updateProduct(Product product) async {
    final model = ProductModel(
      id: product.id,
      name: product.name,
      unit: product.unit,
      sku: product.sku,
      minStock: product.minStock,
      isActive: product.isActive,
      isSynced: true,
    );

    await remoteDataSource.uploadProduct(model.toJson());
  }

  // --- GESTIÓN DE EXISTENCIAS Y MOVIMIENTOS ---

  @override
  Future<void> registerTransaction(InventoryTransaction transaction) async {
    final txModel = TransactionModel(
      id: transaction.id,
      timestamp: transaction.timestamp,
      type: transaction.type,
      category: transaction.category,
      description: transaction.description,
      items: transaction.items,
      isSynced: true,
    );

    await remoteDataSource.uploadTransaction(txModel.toJson());
  }

  @override
  Future<StockStatus?> getStockByProduct(String productId) async {
    final data = await (localDb.select(
      localDb.stockTable,
    )..where((s) => s.productId.equals(productId))).getSingleOrNull();
    return data != null ? StockModel.fromDrift(data) : null;
  }

  @override
  Future<List<StockStatus>> getAllStockStatus() async {
    try {
      final remoteJson = await remoteDataSource.fetchStockStatus();
      return remoteJson.map((e) => StockModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint(
        "Contingencia activada en getAllStockStatus (lectura local): $e",
      );
      final data = await localDb.select(localDb.stockTable).get();
      return data.map((e) => StockModel.fromDrift(e)).toList();
    }
  }

  @override
  Future<PaginatedTransactions> getTransactionsPaginated({
    required int page,
    int pageSize = 15,
    TransactionType? type,
    String? category,
    String? searchQuery,
  }) async {
    final offset = (page - 1) * pageSize;
    final typeStr = type == null
        ? null
        : (type == TransactionType.inbound ? 'inbound' : 'outbound');

    final result = await remoteDataSource.fetchTransactionsPaginated(
      limit: pageSize,
      offset: offset,
      type: typeStr,
      category: category,
      searchQuery: searchQuery,
    );

    final int total = (result['total'] as num?)?.toInt() ?? 0;
    final List rawList = (result['transactions'] as List?) ?? [];

    final transactions = rawList.map((txJson) {
      final rawTime = txJson['timestamp'];
      final parsedTime = rawTime is String
          ? DateTime.tryParse(rawTime) ?? DateTime.now()
          : DateTime.now();

      final List itemsList = (txJson['items'] as List?) ?? [];

      return InventoryTransaction(
        id: txJson['id'].toString(),
        timestamp: parsedTime,
        type: txJson['type'] == 'inbound'
            ? TransactionType.inbound
            : TransactionType.outbound,
        category:
            txJson['category']?.toString() ??
            TransactionCategories.defaultCategory,
        description: txJson['description']?.toString() ?? "Sin descripcion",
        isSynced: true,
        items: itemsList
            .map(
              (item) => TransactionItem(
                productId: item['product_id'].toString(),
                productName: item['product_name'].toString(),
                quantity: (item['quantity'] as num).toDouble(),
              ),
            )
            .toList(),
      );
    }).toList();

    return PaginatedTransactions(
      items: transactions,
      totalCount: total,
      currentPage: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<List<DailyProductMovement>> getDailyMovementsSummary({
    required DateTime date,
    required TransactionType type,
    String? category,
  }) async {
    final datePrefix = DateFormat('yyyy-MM-dd').format(date);
    final typeStr = type == TransactionType.inbound ? 'inbound' : 'outbound';

    final rawList = await remoteDataSource.fetchDailyMovementsSummary(
      datePrefix: datePrefix,
      type: typeStr,
      category: category,
    );

    return rawList.map((row) {
      return DailyProductMovement(
        productId: row['product_id'].toString(),
        productName: row['product_name'].toString(),
        unit: row['unit'].toString(),
        sku: row['sku']?.toString(),
        totalQuantity: (row['total_quantity'] as num).toDouble(),
      );
    }).toList();
  }

  // --- MANTENIMIENTO Y BÓVEDA DE RESPALDO LOCAL ---

  @override
  Future<List<InventoryTransaction>> getTransactionsOlderThan(
    DateTime cutoffDate,
  ) async {
    final cutoffIso = cutoffDate.toIso8601String();
    final rawList = await remoteDataSource.fetchTransactionsOlderThan(
      cutoffIso,
    );

    return rawList.map((txJson) {
      final rawTime = txJson['timestamp'];
      final parsedTime = rawTime is String
          ? DateTime.tryParse(rawTime) ?? DateTime.now()
          : DateTime.now();

      final List itemsList = (txJson['items'] as List?) ?? [];

      return InventoryTransaction(
        id: txJson['id'].toString(),
        timestamp: parsedTime,
        type: txJson['type'] == 'inbound'
            ? TransactionType.inbound
            : TransactionType.outbound,
        category:
            txJson['category']?.toString() ??
            TransactionCategories.defaultCategory,
        description: txJson['description']?.toString() ?? "Sin descripcion",
        isSynced: true,
        items: itemsList
            .map(
              (item) => TransactionItem(
                productId: item['product_id'].toString(),
                productName: item['product_name'].toString(),
                quantity: (item['quantity'] as num).toDouble(),
              ),
            )
            .toList(),
      );
    }).toList();
  }

  @override
  Future<int> archiveLocallyAndDeleteFromCloud(
    List<InventoryTransaction> oldTransactions,
    DateTime cutoffDate,
  ) async {
    await localDb.transaction(() async {
      for (final tx in oldTransactions) {
        final txModel = TransactionModel(
          id: tx.id,
          timestamp: tx.timestamp,
          type: tx.type,
          category: tx.category,
          description: tx.description,
          items: tx.items,
          isSynced: true,
        );

        await localDb
            .into(localDb.transactionsTable)
            .insertOnConflictUpdate(txModel.toDrift());

        await (localDb.delete(
          localDb.transactionItemsTable,
        )..where((t) => t.transactionId.equals(txModel.id))).go();

        final driftItems = TransactionModel.itemsToDrift(txModel.id, tx.items);
        for (final item in driftItems) {
          await localDb.into(localDb.transactionItemsTable).insert(item);
        }
      }
    });

    final cutoffIso = cutoffDate.toIso8601String();
    return await remoteDataSource.deleteTransactionsOlderThan(cutoffIso);
  }
}
