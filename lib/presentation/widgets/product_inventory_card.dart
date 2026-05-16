import 'package:flutter/material.dart';
import '../../../core/entities/product.dart';

class ProductInventoryCard extends StatelessWidget {
  final Product product;
  final double currentStock;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const ProductInventoryCard({
    super.key,
    required this.product,
    required this.currentStock,
    this.isSelected = false,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Lógica de color de stock
    final bool isLowStock = currentStock <= (product.minStock ?? 0);
    final Color statusColor = isLowStock
        ? Colors.redAccent
        : Colors.greenAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      // Si está seleccionado, resaltamos el borde
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blueAccent : Colors.white10,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Indicador visual de stock
              Container(
                width: 5,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "SKU: ${product.sku ?? 'N/A'}",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Cantidad
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$currentStock",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      color: statusColor,
                    ),
                  ),
                  Text(
                    product.unit.toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: Colors.white38),
                  ),
                ],
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 10), // <--- CAMBIO AQUÍ
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
