import '../../core/entities/stock_status.dart';
import '../datasources/local_database.dart';

class StockModel extends StockStatus {
  StockModel({
    required super.productId,
    required super.currentQuantity,
    required super.lastUpdated,
  });

  // --- MAPEO DE JSON (Supabase) ---
  factory StockModel.fromJson(Map<String, dynamic> json) {
    return StockModel(
      productId: json['product_id'],
      // Parche de seguridad: Convertimos a num primero para evitar errores de cast int->double
      currentQuantity: (json['current_quantity'] as num?)?.toDouble() ?? 0.0,
      // Usamos los nombres exactos de la tabla stock en Supabase
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
    );
  }

  // --- MAPEO DE DRIFT (SQLite Local) ---
  factory StockModel.fromDrift(StockTableData data) {
    return StockModel(
      productId: data.productId,
      currentQuantity: data.currentQuantity,
      lastUpdated: data.lastUpdated,
    );
  }

  StockTableCompanion toDrift() {
    return StockTableCompanion.insert(
      productId: productId,
      currentQuantity: currentQuantity,
      lastUpdated: lastUpdated,
    );
  }
}
