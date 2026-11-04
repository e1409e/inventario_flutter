import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_database.g.dart';

/// Tabla local para el respaldo del catálogo de productos.
class ProductsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get unit => text()();
  TextColumn get sku => text().nullable()();
  RealColumn get minStock => real().withDefault(const Constant(5.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla local para el respaldo del estado de existencias.
class StockTable extends Table {
  TextColumn get productId => text().references(ProductsTable, #id)();
  RealColumn get currentQuantity => real()();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}

/// Tabla local para el archivo histórico de cabeceras de transacciones.
class TransactionsTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get type => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla local para el archivo histórico de líneas de detalle por transacción.
class TransactionItemsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId => text().references(TransactionsTable, #id)();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
}

/// Motor de base de datos SQLite local administrado por Drift.
/// Actúa como bóveda de almacenamiento histórico para registros depurados de la nube
/// y como caché de contingencia de solo lectura.
@DriftDatabase(
  tables: [ProductsTable, StockTable, TransactionsTable, TransactionItemsTable],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'inventario_db.sqlite'));
    return NativeDatabase(file);
  });
}
