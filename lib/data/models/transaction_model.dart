import '../../core/entities/inventory_transaction.dart';
import '../../core/entities/transaction_item.dart';
import '../datasources/local_database.dart';
import 'package:drift/drift.dart';

class TransactionModel extends InventoryTransaction {
  TransactionModel({
    required super.id,
    required super.timestamp,
    required super.type,
    required super.description,
    required super.items,
    super.isSynced,
  });

  // --- MAPEO PARA SUPABASE (JSON) ---
  // Nota: Supabase recibirá los items como una lista anidada
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type == TransactionType.inbound ? 'inbound' : 'outbound',
      'description': description,
      'is_synced': isSynced,
      'items': items.map((item) => {
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
      }).toList(),
    };
  }

  // --- MAPEO PARA DRIFT (SQLite) ---
  
  // Para la cabecera del movimiento
  TransactionsTableCompanion toDrift() {
    return TransactionsTableCompanion.insert(
      id: id,
      timestamp: timestamp,
      type: type == TransactionType.inbound ? 'inbound' : 'outbound',
      description: Value(description),
      isSynced: Value(isSynced),
    );
  }

  // Para los items individuales (se guardan en una tabla aparte en SQLite)
  static List<TransactionItemsTableCompanion> itemsToDrift(String txId, List<TransactionItem> items) {
    return items.map((item) => TransactionItemsTableCompanion.insert(
      transactionId: txId,
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
    )).toList();
  }
}