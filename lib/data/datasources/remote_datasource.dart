import 'package:libsql_dart/libsql_dart.dart';
import 'dart:isolate';

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
      // 1. Las peticiones de red NO bloquean la UI porque son I/O, las dejamos aquí.
      final txs = await _client.query('SELECT * FROM transactions');
      final items = await _client.query('SELECT * FROM transaction_items');

      // 2. Despachamos el trabajo intensivo de CPU al Isolate.
      // El hilo principal queda libre inmediatamente para seguir dibujando la interfaz.
      final resultadoFinal = await Isolate.run(() {
        // Llamamos a una función estática pasándole los datos crudos.
        return _procesarDatosEnSegundoPlano(txs.toList(), items.toList());
      });

      return resultadoFinal;
    } catch (e) {
      throw Exception("Error al obtener historial desde Turso: $e");
    }
  }

  // 3. Esta función DEBE ser estática (o estar fuera de la clase).
  // Aquí ocurre la magia pesada sin afectar la pantalla.
  static List<Map<String, dynamic>> _procesarDatosEnSegundoPlano(
    List<dynamic> txs,
    List<dynamic> items,
  ) {
    // Reutilizamos el algoritmo optimizado O(N+M)
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
