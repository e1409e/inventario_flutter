import 'package:drift/drift.dart';
import '../../core/entities/inventory_transaction.dart';
import '../../core/entities/transaction_item.dart';
import '../datasources/local_database.dart';

/// Modelo de datos para serializar y persistir instancias de [InventoryTransaction].
class TransactionModel extends InventoryTransaction {
  const TransactionModel({
    required super.id,
    required super.timestamp,
    required super.type,
    super.category = TransactionCategories.defaultCategory,
    required super.description,
    required super.items,
    super.isSynced = true,
  });

  /// Convierte la transacción a un mapa JSON estructurado para su envío a Turso.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type == TransactionType.inbound ? 'inbound' : 'outbound',
      'category': category,
      'description': description,
      'is_synced': isSynced,
      'items': items
          .map(
            (item) => {
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
            },
          )
          .toList(),
    };
  }

  /// Convierte la cabecera de la transacción en una entidad compatible con Drift (SQLite local).
  TransactionsTableCompanion toDrift() {
    return TransactionsTableCompanion.insert(
      id: id,
      timestamp: timestamp,
      type: type == TransactionType.inbound ? 'inbound' : 'outbound',
      description: Value(description),
      isSynced: Value(isSynced),
    );
  }

  /// Convierte la lista de ítems de la transacción en entidades compatibles con Drift.
  static List<TransactionItemsTableCompanion> itemsToDrift(
    String txId,
    List<TransactionItem> items,
  ) {
    return items
        .map(
          (item) => TransactionItemsTableCompanion.insert(
            transactionId: txId,
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
          ),
        )
        .toList();
  }
}
