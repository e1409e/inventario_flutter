/// Representa un producto dentro del catálogo maestro del almacén.
class Product {
  /// Identificador único universal (UUID v4).
  final String id;

  /// Nombre descriptivo comercial del producto.
  final String name;

  /// Unidad de medida o empaque (ej. 'Unidad', 'Caja', 'Bulto', 'Kg').
  final String unit;

  /// Código interno de referencia (IPN / SKU) o código de barras.
  final String? sku;

  /// Umbral mínimo de existencias para alertas de reabastecimiento.
  final double? minStock;

  /// Indica si el producto se encuentra activo en el catálogo (borrado lógico).
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.unit,
    this.sku,
    this.minStock,
    this.isActive = true,
  });

  /// Crea una instancia vacía con valores predeterminados para formularios.
  const Product.empty()
    : id = '',
      name = '',
      unit = 'Unidad',
      sku = null,
      minStock = 5.0,
      isActive = true;

  /// Retorna una nueva instancia de [Product] con las propiedades actualizadas.
  Product copyWith({
    String? name,
    String? unit,
    String? sku,
    double? minStock,
    bool? isActive,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      sku: sku ?? this.sku,
      minStock: minStock ?? this.minStock,
      isActive: isActive ?? this.isActive,
    );
  }
}
