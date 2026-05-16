import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// Este archivo se generará automáticamente después
part 'local_database.g.dart';

// 1. Tabla de Productos
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

// 2. Tabla de Stock (Estado actual)
class StockTable extends Table {
  TextColumn get productId => text().references(ProductsTable, #id)();
  RealColumn get currentQuantity => real()();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {productId};
}

// 3. Tabla de Transacciones (Cabecera)
class TransactionsTable extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get type => text()(); // 'inbound' o 'outbound'
  TextColumn get description => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. Tabla de Detalles de Transacción (Líneas de la factura)
class TransactionItemsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId => text().references(TransactionsTable, #id)();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
}

// --- EL CEREBRO DE LA BASE DE DATOS ---

@DriftDatabase(
  tables: [ProductsTable, StockTable, TransactionsTable, TransactionItemsTable],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1; // Aquí manejaremos las migraciones en el futuro
}

// Función para ubicar el archivo .db en el disco (SSD o Almacenamiento Móvil)
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'inventario_db.sqlite'));
    return NativeDatabase(file);
  });
}
