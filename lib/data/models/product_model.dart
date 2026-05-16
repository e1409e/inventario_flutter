import '../../core/entities/product.dart';
import '../datasources/local_database.dart';
import 'package:drift/drift.dart';

class ProductModel extends Product {
  final bool isSynced; // Añadimos la propiedad al modelo

  ProductModel({
    required super.id,
    required super.name,
    required super.unit,
    super.sku,
    super.minStock,
    super.isActive,
    this.isSynced = false, // Por defecto falso
  });

  // --- MAPEO DE JSON (Supabase) ---
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      name: json['name'],
      unit: json['unit'],
      sku: json['sku'],
      minStock: (json['min_stock'] as num?)?.toDouble(),
      isActive: json['is_active'] ?? true,
      isSynced: true, // Si viene de la nube, asumimos que está sincronizado
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'sku': sku,
      'min_stock': minStock,
      'is_active': isActive,
      // Nota: Normalmente no enviamos 'is_synced' a Supabase porque
      // es una bandera de control local.
    };
  }

  // --- MAPEO DE DRIFT (SQLite Local) ---

  factory ProductModel.fromDrift(ProductsTableData data) {
    return ProductModel(
      id: data.id,
      name: data.name,
      unit: data.unit,
      sku: data.sku,
      minStock: data.minStock,
      isActive: data.isActive,
      isSynced: data.isSynced, // Mapeamos la nueva columna
    );
  }

  ProductsTableCompanion toDrift() {
    return ProductsTableCompanion.insert(
      id: id,
      name: name,
      unit: unit,
      sku: Value(sku),
      minStock: Value(minStock ?? 5.0),
      isActive: Value(isActive),
      isSynced: Value(isSynced), // Pasamos el valor a Drift
    );
  }
}
