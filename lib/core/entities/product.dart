class Product {
  final String id;
  final String name;
  final String unit; // Ej: 'Kg', 'Bulto', 'Unidad'
  final String? sku; // Código de barras o código interno
  final double? minStock;
  final bool isActive; // Para el "Soft Delete" que mencionamos

  Product({
    required this.id,
    required this.name,
    required this.unit,
    this.sku,
    this.minStock,
    this.isActive = true,
  });

  // Constructor para crear un producto desde cero en la UI
  Product.empty()
      : id = '',
        name = '',
        unit = 'Unidad',
        sku = null,
        minStock = 5.0,
        isActive = true;

  // Para inmutabilidad: crea una copia con cambios específicos
  Product copyWith({
    String? name,
    String? unit,
    String? sku,
    double? minStock,
    bool? isActive,
  }) {
    return Product(
      id: id, // El ID nunca cambia
      name: name ?? this.name,
      unit: unit ?? this.unit,
      sku: sku ?? this.sku,
      minStock: minStock ?? this.minStock,
      isActive: isActive ?? this.isActive,
    );
  }
}