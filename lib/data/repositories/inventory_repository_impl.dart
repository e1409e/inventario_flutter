import '../../core/entities/inventory_transaction.dart';
import '../../core/entities/transaction_item.dart';
import '../../core/entities/product.dart';
import '../../core/entities/stock_status.dart';
import '../../core/entities/sync_log.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/sync_repository.dart';
import '../datasources/local_database.dart';
import '../datasources/remote_datasource.dart';
import '../models/product_model.dart';
import '../models/stock_model.dart';
import '../models/transaction_model.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

class InventoryRepositoryImpl implements InventoryRepository, SyncRepository {
  final LocalDatabase localDb;
  final RemoteDataSource remoteDataSource;

  bool _isEmergencyMode = false;

  InventoryRepositoryImpl({
    required this.localDb,
    required this.remoteDataSource,
  });

  @override
  void toggleEmergencyMode(bool isEnabled) {
    _isEmergencyMode = isEnabled;
    debugPrint(
      "Cambio de modo de conexion detectado: isEmergencyMode = $isEnabled",
    );
  }

  // --- IMPLEMENTACIÓN DE SYNC REPOSITORY (AUDITORÍA) ---

  @override
  Future<void> logSyncEvent(SyncLog log) async {
    try {
      debugPrint(
        "AUDITORIA REGISTRADA: [Exito: ${log.success}] Sincronizados: ${log.recordsSynced}",
      );
      if (log.errorMessage != null) {
        debugPrint("DETALLE ERROR: ${log.errorMessage}");
      }
    } catch (e) {
      debugPrint("Error al guardar auditoria: $e");
    }
  }

  @override
  Future<SyncLog?> getLastSync() async {
    return null;
  }

  // --- IMPLEMENTACIÓN DE PRODUCTOS ---

  @override
  Future<List<Product>> getAllProducts() async {
    if (!_isEmergencyMode) {
      try {
        final remoteJson = await remoteDataSource.fetchProducts();
        final remoteModels = remoteJson
            .map((e) => ProductModel.fromJson(e))
            .toList();

        await localDb.transaction(() async {
          for (var model in remoteModels) {
            await localDb
                .into(localDb.productsTable)
                .insertOnConflictUpdate(model.toDrift());
          }
        });
        return remoteModels;
      } catch (e, stack) {
        debugPrint("Fallo en getAllProducts (Modo Cloud). Mensaje: $e");
      }
    }

    try {
      final localData = await localDb.select(localDb.productsTable).get();
      return localData.map((e) => ProductModel.fromDrift(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> saveProduct(Product product) async {
    final model = ProductModel(
      id: product.id,
      name: product.name,
      unit: product.unit,
      sku: product.sku,
      isSynced: false,
    );

    await localDb
        .into(localDb.productsTable)
        .insertOnConflictUpdate(model.toDrift());

    if (!_isEmergencyMode) {
      try {
        await remoteDataSource.uploadProduct(model.toJson());
        await (localDb.update(localDb.productsTable)
              ..where((t) => t.id.equals(product.id)))
            .write(ProductsTableCompanion(isSynced: const Value(true)));
      } catch (e) {
        debugPrint("Fallo de red en saveProduct. Se sincronizará luego.");
      }
    }
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
      isSynced: false,
    );

    await localDb
        .into(localDb.productsTable)
        .insertOnConflictUpdate(model.toDrift());

    if (!_isEmergencyMode) {
      try {
        await remoteDataSource.uploadProduct(model.toJson());
        await (localDb.update(localDb.productsTable)
              ..where((t) => t.id.equals(product.id)))
            .write(ProductsTableCompanion(isSynced: const Value(true)));
      } catch (e) {
        debugPrint("Fallo de red en updateProduct. Se sincronizará luego.");
      }
    }
  }

  // --- REGISTRO DE TRANSACCIONES ---

  @override
  Future<void> registerTransaction(InventoryTransaction transaction) async {
    final txModel = TransactionModel(
      id: transaction.id,
      timestamp: transaction.timestamp,
      type: transaction.type,
      description: transaction.description,
      items: transaction.items,
      isSynced: !_isEmergencyMode,
    );

    await localDb.transaction(() async {
      await localDb.into(localDb.transactionsTable).insert(txModel.toDrift());
      final driftItems = TransactionModel.itemsToDrift(
        txModel.id,
        txModel.items,
      );
      for (var item in driftItems) {
        await localDb.into(localDb.transactionItemsTable).insert(item);
      }

      for (var item in txModel.items) {
        final currentStock = await getStockByProduct(item.productId);
        final newQuantity = txModel.type == TransactionType.inbound
            ? (currentStock?.currentQuantity ?? 0) + item.quantity
            : (currentStock?.currentQuantity ?? 0) - item.quantity;

        await localDb
            .into(localDb.stockTable)
            .insertOnConflictUpdate(
              StockTableCompanion.insert(
                productId: item.productId,
                currentQuantity: newQuantity,
                lastUpdated: DateTime.now(),
              ),
            );
      }
    });

    if (!_isEmergencyMode) {
      try {
        await remoteDataSource.uploadTransaction(txModel.toJson());
      } catch (e) {
        debugPrint(
          "Fallo de red en registerTransaction. Se sincronizará luego.",
        );
      }
    }
  }

  // --- SINCRONIZACIÓN DIFERIDA ---

  @override
  Future<void> syncPendingData() async {
    int successCount = 0;
    int errorCount = 0;
    String auditDetails = "";

    // A. PRODUCTOS
    final pendingProducts = await (localDb.select(
      localDb.productsTable,
    )..where((p) => p.isSynced.equals(false))).get();

    for (var p in pendingProducts) {
      try {
        final model = ProductModel.fromDrift(p);
        await remoteDataSource.uploadProduct(model.toJson());
        await (localDb.update(localDb.productsTable)
              ..where((t) => t.id.equals(p.id)))
            .write(ProductsTableCompanion(isSynced: const Value(true)));
        successCount++;
      } catch (e) {
        errorCount++;
        auditDetails += "Prod: ${p.name} FALLO. ";
      }
    }

    // B. TRANSACCIONES
    final pendingTx = await (localDb.select(
      localDb.transactionsTable,
    )..where((t) => t.isSynced.equals(false))).get();

    for (var tx in pendingTx) {
      try {
        final items = await (localDb.select(
          localDb.transactionItemsTable,
        )..where((it) => it.transactionId.equals(tx.id))).get();

        final txModel = TransactionModel(
          id: tx.id,
          timestamp: tx.timestamp,
          type: tx.type == 'inbound'
              ? TransactionType.inbound
              : TransactionType.outbound,
          description: tx.description ?? "Sin descripcion",
          items: items
              .map(
                (it) => TransactionItem(
                  productId: it.productId,
                  productName: it.productName,
                  quantity: it.quantity,
                ),
              )
              .toList(),
          isSynced: true,
        );

        await remoteDataSource.uploadTransaction(txModel.toJson());
        await (localDb.update(localDb.transactionsTable)
              ..where((t) => t.id.equals(tx.id)))
            .write(TransactionsTableCompanion(isSynced: const Value(true)));
        successCount++;
      } catch (e) {
        errorCount++;
        auditDetails += "Tx: ${tx.id.substring(0, 5)} FALLO. ";
      }
    }

    // REGISTRAMOS LA AUDITORÍA CON TU ENTIDAD
    if (pendingProducts.isNotEmpty || pendingTx.isNotEmpty) {
      final log = SyncLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lastSyncAt: DateTime.now(),
        success: errorCount == 0,
        errorMessage: errorCount > 0 ? auditDetails.trim() : null,
        recordsSynced: successCount,
      );

      await logSyncEvent(log);
    }
  }

  // --- HISTORIAL Y STOCK ---

  @override
  Future<StockStatus?> getStockByProduct(String productId) async {
    final data = await (localDb.select(
      localDb.stockTable,
    )..where((s) => s.productId.equals(productId))).getSingleOrNull();
    return data != null ? StockModel.fromDrift(data) : null;
  }

  @override
  Future<List<StockStatus>> getAllStockStatus() async {
    if (!_isEmergencyMode) {
      try {
        final remoteJson = await remoteDataSource.fetchStockStatus();
        final remoteModels = remoteJson
            .map((e) => StockModel.fromJson(e))
            .toList();

        await localDb.transaction(() async {
          for (var model in remoteModels) {
            await localDb
                .into(localDb.stockTable)
                .insertOnConflictUpdate(model.toDrift());
          }
        });
        return remoteModels;
      } catch (e) {
        debugPrint("Error obteniendo stock de nube: $e");
      }
    }
    final data = await localDb.select(localDb.stockTable).get();
    return data.map((e) => StockModel.fromDrift(e)).toList();
  }

  @override
  Future<List<InventoryTransaction>> getTransactionHistory() async {
    // --- 1. SINCRONIZACIÓN DE BAJADA (PULL) DESDE TURSO ---
    if (!_isEmergencyMode) {
      try {
        final remoteTxs = await remoteDataSource.fetchTransactions();

        await localDb.transaction(() async {
          for (var txJson in remoteTxs) {
            // Manejo seguro de la fecha (Turso guarda Strings ISO por defecto)
            final rawTime = txJson['timestamp'];
            DateTime parsedTime = rawTime is String
                ? DateTime.tryParse(rawTime) ?? DateTime.now()
                : DateTime.now();

            final typeEnum = txJson['type'] == 'inbound'
                ? TransactionType.inbound
                : TransactionType.outbound;

            // Creamos el modelo para actualizar Drift localmente
            final txModel = TransactionModel(
              id: txJson['id'],
              timestamp: parsedTime,
              type: typeEnum,
              description: txJson['description'] ?? "Sin descripcion",
              items: [], // La cabecera no necesita los items aquí
              isSynced: true, // Ya viene de la nube
            );

            // Insertamos o actualizamos la cabecera
            await localDb
                .into(localDb.transactionsTable)
                .insertOnConflictUpdate(txModel.toDrift());

            // TRUCO CLAVE: Borramos los items locales viejos de esta transacción
            // para evitar que se dupliquen por el ID Autoincremental
            await (localDb.delete(
              localDb.transactionItemsTable,
            )..where((t) => t.transactionId.equals(txModel.id))).go();

            // Insertamos los items actualizados desde la nube
            final itemsList = txJson['items'] as List<dynamic>;
            for (var item in itemsList) {
              await localDb
                  .into(localDb.transactionItemsTable)
                  .insert(
                    TransactionItemsTableCompanion.insert(
                      transactionId: txModel.id,
                      productId: item['product_id'],
                      productName: item['product_name'],
                      quantity: (item['quantity'] as num).toDouble(),
                    ),
                  );
            }
          }
        });
      } catch (e) {
        debugPrint("Error descargando historial de nube: $e");
      }
    }

    // --- 2. LECTURA LOCAL (El código que ya tenías) ---
    final txQuery = localDb.select(localDb.transactionsTable)
      ..orderBy([
        (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc),
      ]);

    final txs = await txQuery.get();
    List<InventoryTransaction> history = [];

    for (var tx in txs) {
      final itemsData = await (localDb.select(
        localDb.transactionItemsTable,
      )..where((it) => it.transactionId.equals(tx.id))).get();

      history.add(
        InventoryTransaction(
          id: tx.id,
          timestamp: tx.timestamp,
          type: tx.type == 'inbound'
              ? TransactionType.inbound
              : TransactionType.outbound,
          description: tx.description ?? "Sin descripcion",
          items: itemsData
              .map(
                (it) => TransactionItem(
                  productId: it.productId,
                  productName: it.productName,
                  quantity: it.quantity,
                ),
              )
              .toList(),
        ),
      );
    }
    return history;
  }
}
