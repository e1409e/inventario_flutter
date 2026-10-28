import 'package:libsql_dart/libsql_dart.dart';
import 'dart:isolate';

abstract class RemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchProducts();
  Future<void> uploadTransaction(Map<String, dynamic> transactionJson);
  Future<void> uploadProduct(Map<String, dynamic> productJson);
  Future<List<Map<String, dynamic>>> fetchStockStatus();
  Future<List<Map<String, dynamic>>> fetchTransactions();

  // --- NUEVOS MÉTODOS OPTIMIZADOS (TURSO DIRECTO) ---
  Future<Map<String, dynamic>> fetchTransactionsPaginated({
    required int limit,
    required int offset,
    String? type,
    String? searchQuery,
  });

  Future<List<Map<String, dynamic>>> fetchDailyMovementsSummary({
    required String datePrefix, // Formato 'YYYY-MM-DD'
    required String type, // 'inbound' o 'outbound'
  });
}

class TursoDataSource implements RemoteDataSource {
  final LibsqlClient _client;

  TursoDataSource(this._client);

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
    final tx = await _client.transaction();
    try {
      await tx.execute(
        'INSERT INTO transactions (id, timestamp, type, description) VALUES (?, ?, ?, ?)',
        positional: [
          txJson['id'],
          txJson['timestamp'],
          txJson['type'],
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

        final isEq = txJson['type'] == 'inbound';
        final qty = (item['quantity'] as num).toDouble();

        await tx.execute(
          '''
          INSERT INTO stock (product_id, current_quantity, last_updated) 
          VALUES (?, ?, datetime('now'))
          ON CONFLICT(product_id) DO UPDATE SET 
            current_quantity = current_quantity ${isEq ? '+' : '-'} ?, 
            last_updated = datetime('now')
          ''',
          positional: [item['product_id'], isEq ? qty : -qty, qty],
        );
      }

      await tx.commit();
    } catch (e) {
      await tx.rollback();
      throw Exception("Error en la transacción en Turso: $e");
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
    String? searchQuery,
  }) async {
    try {
      final List<String> conditions = [];
      final List<Object?> args = [];

      if (type != null && type.isNotEmpty) {
        conditions.add('t.type = ?');
        args.add(type);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final pattern = '%${searchQuery.trim()}%';
        conditions.add(
          '(LOWER(t.description) LIKE LOWER(?) OR EXISTS ('
          'SELECT 1 FROM transaction_items ti '
          'WHERE ti.transaction_id = t.id AND LOWER(ti.product_name) LIKE LOWER(?)'
          '))',
        );
        args.add(pattern);
        args.add(pattern);
      }

      final whereClause = conditions.isEmpty
          ? ''
          : 'WHERE ${conditions.join(' AND ')}';

      // 1. Contamos el total de registros que coinciden para armar la numeración de páginas
      final countRs = await _client.query(
        'SELECT COUNT(*) as total FROM transactions t $whereClause',
        positional: args,
      );
      final int totalCount = countRs.isNotEmpty
          ? (countRs.first['total'] as num).toInt()
          : 0;

      if (totalCount == 0) {
        return {'total': 0, 'transactions': <Map<String, dynamic>>[]};
      }

      // 2. Traemos únicamente las cabeceras de la página solicitada
      final txArgs = [...args, limit, offset];
      final txsRs = await _client.query('''
        SELECT t.* FROM transactions t
        $whereClause
        ORDER BY t.timestamp DESC
        LIMIT ? OFFSET ?
        ''', positional: txArgs);

      if (txsRs.isEmpty) {
        return {'total': totalCount, 'transactions': <Map<String, dynamic>>[]};
      }

      // 3. Traemos solo los items que pertenecen a los IDs de esta página
      final txIds = txsRs.map((r) => r['id'].toString()).toList();
      final placeholders = List.filled(txIds.length, '?').join(',');
      final itemsRs = await _client.query(
        'SELECT * FROM transaction_items WHERE transaction_id IN ($placeholders)',
        positional: txIds,
      );

      final grouped = _procesarDatosEnSegundoPlano(
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
  }) async {
    try {
      // Filtra por el día exacto (YYYY-MM-DD%) y agrupa sumando las cantidades por producto
      final rs = await _client.query(
        '''
        SELECT 
          ti.product_id,
          ti.product_name,
          COALESCE(p.unit, 'Und') as unit,
          p.sku,
          SUM(ti.quantity) as total_quantity
        FROM transaction_items ti
        INNER JOIN transactions t ON t.id = ti.transaction_id
        LEFT JOIN products p ON p.id = ti.product_id
        WHERE t.type = ? AND t.timestamp LIKE ?
        GROUP BY ti.product_id, ti.product_name
        HAVING total_quantity > 0
        ORDER BY ti.product_name ASC
        ''',
        positional: [type, '$datePrefix%'],
      );

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
  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    try {
      final txs = await _client.query('SELECT * FROM transactions');
      final items = await _client.query('SELECT * FROM transaction_items');

      final resultadoFinal = await Isolate.run(() {
        return _procesarDatosEnSegundoPlano(txs.toList(), items.toList());
      });

      return resultadoFinal;
    } catch (e) {
      throw Exception("Error al obtener historial desde Turso: $e");
    }
  }

  static List<Map<String, dynamic>> _procesarDatosEnSegundoPlano(
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
