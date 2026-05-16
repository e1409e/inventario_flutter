import 'package:libsql_dart/libsql_dart.dart';

abstract class RemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchProducts();
  Future<void> uploadTransaction(Map<String, dynamic> transactionJson);
  Future<void> uploadProduct(Map<String, dynamic> productJson);
  Future<List<Map<String, dynamic>>> fetchStockStatus();
  Future<List<Map<String, dynamic>>> fetchTransactions();
}

class TursoDataSource implements RemoteDataSource {
  final LibsqlClient _client;

  TursoDataSource(this._client);

  @override
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      // .query() devuelve List<Map<String, dynamic>> directamente
      final rs = await _client.query('SELECT * FROM products');

      // 'rs' ya es iterable, no usamos .rows
      return rs.map((row) {
        return {
          'id': row['id'],
          'name': row['name'],
          'unit': row['unit'],
          'sku': row['sku'],
          'min_stock': row['min_stock'],
          'is_active':
              row['is_active'] == 1, // En SQLite los booleanos son 0 o 1
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
        // Se usa el parámetro 'positional:' en lugar de 'args:'
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
  Future<List<Map<String, dynamic>>> fetchTransactions() async {
    try {
      // 1. Obtenemos todas las cabeceras
      final txs = await _client.query('SELECT * FROM transactions');
      // 2. Obtenemos todos los items de detalle
      final items = await _client.query('SELECT * FROM transaction_items');

      // 3. Anidamos los items dentro de su transacción correspondiente
      return txs.map((tx) {
        final txItems = items
            .where((it) => it['transaction_id'] == tx['id'])
            .toList();

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
    } catch (e) {
      throw Exception("Error al obtener historial desde Turso: $e");
    }
  }
}
