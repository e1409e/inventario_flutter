import 'package:libsql_dart/libsql_dart.dart';

/// Contrato para las operaciones de lectura y escritura en la base de datos remota (Turso).
abstract class RemoteDataSource {
  /// Obtiene todos los registros del catálogo de productos.
  Future<List<Map<String, dynamic>>> fetchProducts();

  /// Inserta o actualiza un producto en el catálogo remoto.
  Future<void> uploadProduct(Map<String, dynamic> productJson);

  /// Registra una transacción con sus ítems y actualiza el stock de forma atómica.
  Future<void> uploadTransaction(Map<String, dynamic> transactionJson);

  /// Obtiene el estado de existencias actual de todos los productos.
  Future<List<Map<String, dynamic>>> fetchStockStatus();

  /// Consulta una página de transacciones aplicando filtros de flujo, categoría y búsqueda.
  Future<Map<String, dynamic>> fetchTransactionsPaginated({
    required int limit,
    required int offset,
    String? type,
    String? category,
    String? searchQuery,
  });

  /// Calcula el total agrupado por producto para una fecha y tipo de flujo específicos.
  Future<List<Map<String, dynamic>>> fetchDailyMovementsSummary({
    required String datePrefix,
    required String type,
    String? category,
  });

  /// Obtiene todas las transacciones anteriores a [cutoffIso] para procesos de respaldo.
  Future<List<Map<String, dynamic>>> fetchTransactionsOlderThan(
    String cutoffIso,
  );

  /// Elimina de forma atómica las transacciones y sus detalles anteriores a [cutoffIso].
  Future<int> deleteTransactionsOlderThan(String cutoffIso);
}

/// Implementación de [RemoteDataSource] basada en libSQL / Turso.
class TursoDataSource implements RemoteDataSource {
  final LibsqlClient _client;
  bool _schemaChecked = false;

  TursoDataSource(this._client);

  /// Garantiza la existencia de la columna `category` y de los índices B-Tree
  /// necesarios para evitar escaneos completos de tabla (Full Table Scans).
  Future<void> _ensureSchemaAndIndexes() async {
    if (_schemaChecked) return;
    try {
      await _client.execute(
        "ALTER TABLE transactions ADD COLUMN category TEXT DEFAULT 'Sin Definir'",
      );
    } catch (_) {}

    try {
      await _client.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_items_tx_id ON transaction_items(transaction_id)',
      );
      await _client.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_timestamp ON transactions(timestamp DESC)',
      );
      await _client.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_type_timestamp ON transactions(type, timestamp DESC)',
      );
      await _client.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category)',
      );
      await _client.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_prod_id ON stock(product_id)',
      );
    } catch (_) {}

    _schemaChecked = true;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final rs = await _client.query('SELECT * FROM products');
      return rs.map((row) {
        return {
          'id': row['id'],
          'name': row['name'],
          'unit': row['unit'],
          'sku': row['sku'],
          'min_stock': row['min_stock'],
          'is_active': row['is_active'] == 1,
        };
      }).toList();
    } catch (e) {
      throw Exception("Error al obtener productos desde Turso: $e");
    }
  }

  @override
  Future<void> uploadProduct(Map<String, dynamic> p) async {
    try {
      await _client.execute(
        '''
        INSERT INTO products (id, name, unit, sku, min_stock, is_active) 
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET 
          name = excluded.name, 
          unit = excluded.unit, 
          sku = excluded.sku, 
          min_stock = excluded.min_stock, 
          is_active = excluded.is_active
        ''',
        positional: [
          p['id'],
          p['name'],
          p['unit'],
          p['sku'],
          p['min_stock'] ?? 5.0,
          (p['is_active'] ?? true) ? 1 : 0,
        ],
      );
    } catch (e) {
      throw Exception("Error al subir producto a Turso: $e");
    }
  }

  @override
  Future<void> uploadTransaction(Map<String, dynamic> txJson) async {
    await _ensureSchemaAndIndexes();
    final tx = await _client.transaction();
    try {
      await tx.execute(
        'INSERT INTO transactions (id, timestamp, type, category, description) VALUES (?, ?, ?, ?, ?)',
        positional: [
          txJson['id'],
          txJson['timestamp'],
          txJson['type'],
          txJson['category'] ?? 'Sin Definir',
          txJson['description'],
        ],
      );

      final items = txJson['items'] as List<dynamic>;
      for (var item in items) {
        await tx.execute(
          'INSERT INTO transaction_items (transaction_id, product_id, product_name, quantity) VALUES (?, ?, ?, ?)',
          positional: [
            txJson['id'],
            item['product_id'],
            item['product_name'],
            item['quantity'],
          ],
        );

        final isInbound = txJson['type'] == 'inbound';
        final qty = (item['quantity'] as num).toDouble();

        await tx.execute(
          '''
          INSERT INTO stock (product_id, current_quantity, last_updated) 
          VALUES (?, ?, datetime('now'))
          ON CONFLICT(product_id) DO UPDATE SET 
            current_quantity = current_quantity ${isInbound ? '+' : '-'} ?, 
            last_updated = datetime('now')
          ''',
          positional: [item['product_id'], isInbound ? qty : -qty, qty],
        );
      }

      await tx.commit();
    } catch (e) {
      await tx.rollback();
      throw Exception("Error al registrar la transacción en Turso: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStockStatus() async {
    try {
      final rs = await _client.query('SELECT * FROM stock');
      return rs.map((row) {
        return {
          'product_id': row['product_id'],
          'current_quantity': row['current_quantity'],
          'last_updated': row['last_updated'],
        };
      }).toList();
    } catch (e) {
      throw Exception("Error al obtener stock desde Turso: $e");
    }
  }

  @override
  Future<Map<String, dynamic>> fetchTransactionsPaginated({
    required int limit,
    required int offset,
    String? type,
    String? category,
    String? searchQuery,
  }) async {
    await _ensureSchemaAndIndexes();
    try {
      final List<String> conditions = [];
      final List<Object?> args = [];

      if (type != null && type.isNotEmpty) {
        conditions.add('t.type = ?');
        args.add(type);
      }

      if (category != null && category.isNotEmpty) {
        conditions.add("COALESCE(t.category, 'Sin Definir') = ?");
        args.add(category);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final pattern = '%${searchQuery.trim()}%';
        conditions.add(
          '(LOWER(t.description) LIKE LOWER(?) OR '
          't.id IN ('
          'SELECT ti.transaction_id FROM transaction_items ti '
          'WHERE LOWER(ti.product_name) LIKE LOWER(?)'
          '))',
        );
        args.add(pattern);
        args.add(pattern);
      }

      final whereClause = conditions.isEmpty
          ? ''
          : 'WHERE ${conditions.join(' AND ')}';

      final countRs = await _client.query(
        'SELECT COUNT(*) as total FROM transactions t $whereClause',
        positional: args,
      );
      final int totalCount = countRs.isNotEmpty
          ? (countRs.first['total'] as num).toInt()
          : 0;

      if (totalCount == 0) {
        return {'total': 0, 'transactions': []};
      }

      final txArgs = [...args, limit, offset];
      final txsRs = await _client.query('''
        SELECT t.* FROM transactions t
        $whereClause
        ORDER BY t.timestamp DESC
        LIMIT ? OFFSET ?
        ''', positional: txArgs);

      if (txsRs.isEmpty) {
        return {'total': totalCount, 'transactions': []};
      }

      final txIds = txsRs.map((r) => r['id'].toString()).toList();
      final placeholders = List.filled(txIds.length, '?').join(',');
      final itemsRs = await _client.query(
        'SELECT * FROM transaction_items WHERE transaction_id IN ($placeholders)',
        positional: txIds,
      );

      final grouped = _groupTransactionsWithItems(
        txsRs.toList(),
        itemsRs.toList(),
      );

      return {'total': totalCount, 'transactions': grouped};
    } catch (e) {
      throw Exception("Error al obtener historial paginado desde Turso: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDailyMovementsSummary({
    required String datePrefix,
    required String type,
    String? category,
  }) async {
    await _ensureSchemaAndIndexes();
    try {
      final startOfDay = '${datePrefix}T00:00:00';
      final endOfDay = '${datePrefix}T23:59:59.999999';

      final List<Object?> args = [type, startOfDay, endOfDay];
      String categoryClause = '';

      if (category != null && category.isNotEmpty) {
        categoryClause = "AND COALESCE(t.category, 'Sin Definir') = ?";
        args.add(category);
      }

      final rs = await _client.query('''
        SELECT 
          ti.product_id,
          ti.product_name,
          COALESCE(p.unit, 'Und') as unit,
          p.sku,
          SUM(ti.quantity) as total_quantity
        FROM transactions t
        INNER JOIN transaction_items ti ON ti.transaction_id = t.id
        LEFT JOIN products p ON p.id = ti.product_id
        WHERE t.type = ? AND t.timestamp >= ? AND t.timestamp <= ? $categoryClause
        GROUP BY ti.product_id, ti.product_name
        HAVING total_quantity > 0
        ORDER BY ti.product_name ASC
        ''', positional: args);

      return rs.map((row) {
        return {
          'product_id': row['product_id'],
          'product_name': row['product_name'],
          'unit': row['unit'] ?? 'Und',
          'sku': row['sku'],
          'total_quantity': (row['total_quantity'] as num).toDouble(),
        };
      }).toList();
    } catch (e) {
      throw Exception("Error al obtener reporte diario desde Turso: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTransactionsOlderThan(
    String cutoffIso,
  ) async {
    await _ensureSchemaAndIndexes();
    try {
      final txsRs = await _client.query(
        'SELECT * FROM transactions WHERE timestamp < ? ORDER BY timestamp ASC',
        positional: [cutoffIso],
      );

      if (txsRs.isEmpty) return [];

      final itemsRs = await _client.query(
        '''
        SELECT ti.* FROM transaction_items ti
        INNER JOIN transactions t ON t.id = ti.transaction_id
        WHERE t.timestamp < ?
        ''',
        positional: [cutoffIso],
      );

      return _groupTransactionsWithItems(txsRs.toList(), itemsRs.toList());
    } catch (e) {
      throw Exception("Error al consultar movimientos antiguos en Turso: $e");
    }
  }

  @override
  Future<int> deleteTransactionsOlderThan(String cutoffIso) async {
    final tx = await _client.transaction();
    try {
      final countRs = await tx.query(
        'SELECT COUNT(*) as total FROM transactions WHERE timestamp < ?',
        positional: [cutoffIso],
      );
      final int deletedCount = countRs.isNotEmpty
          ? (countRs.first['total'] as num).toInt()
          : 0;

      if (deletedCount == 0) {
        await tx.rollback();
        return 0;
      }

      await tx.execute(
        '''
        DELETE FROM transaction_items 
        WHERE transaction_id IN (
          SELECT id FROM transactions WHERE timestamp < ?
        )
        ''',
        positional: [cutoffIso],
      );

      await tx.execute(
        'DELETE FROM transactions WHERE timestamp < ?',
        positional: [cutoffIso],
      );

      await tx.commit();
      return deletedCount;
    } catch (e) {
      await tx.rollback();
      throw Exception("Error al purgar movimientos antiguos en Turso: $e");
    }
  }

  /// Agrupa en complejidad O(N + M) las cabeceras de transacción con sus respectivos ítems.
  static List<Map<String, dynamic>> _groupTransactionsWithItems(
    List<dynamic> txs,
    List<dynamic> items,
  ) {
    final Map<String, List<Map<String, dynamic>>> itemsGroupedByTx = {};

    for (var item in items) {
      final txId = item['transaction_id'].toString();
      if (!itemsGroupedByTx.containsKey(txId)) {
        itemsGroupedByTx[txId] = [];
      }
      itemsGroupedByTx[txId]!.add(item as Map<String, dynamic>);
    }

    return txs.map((tx) {
      final txId = tx['id'].toString();
      final txItems = itemsGroupedByTx[txId] ?? [];

      return {
        'id': tx['id'],
        'timestamp': tx['timestamp'],
        'type': tx['type'],
        'category': tx['category'] ?? 'Sin Definir',
        'description': tx['description'],
        'items': txItems
            .map(
              (i) => {
                'product_id': i['product_id'],
                'product_name': i['product_name'],
                'quantity': i['quantity'],
              },
            )
            .toList(),
      };
    }).toList();
  }
}
