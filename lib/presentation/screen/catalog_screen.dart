import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../state/inventory_cubit.dart';
import '../state/inventory_state.dart';
import '../../../core/entities/product.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("CATÁLOGO MAESTRO")),
      body: Column(
        children: [
          // Buscador de productos
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "BUSCAR PRODUCTO O SKU...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          Expanded(
            child: BlocBuilder<InventoryCubit, InventoryState>(
              builder: (context, state) {
                if (state is InventoryLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is InventoryLoaded) {
                  final filteredProducts = state.products
                      .where(
                        (p) =>
                            p.name.toLowerCase().contains(_searchQuery) ||
                            (p.sku?.toLowerCase().contains(_searchQuery) ??
                                false),
                      )
                      .toList();

                  if (filteredProducts.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductTile(product);
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductModal(context), // Modal en modo "Crear"
        label: const Text("NUEVO PRODUCTO"),
        icon: const Icon(Icons.add_business_rounded),
        backgroundColor: Colors.purpleAccent,
      ),
    );
  }

  Widget _buildProductTile(Product product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purpleAccent.withValues(alpha: 0.1),
          child: Text(
            product.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.purpleAccent),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          "SKU: ${product.sku ?? 'N/A'} | UNIDAD: ${product.unit}",
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: Colors.white38,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.edit_outlined,
            size: 18,
            color: Colors.white24,
          ),
          onPressed: () => _showProductModal(
            context,
            product: product,
          ), // Modal en modo "Editar"
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            "NO HAY PRODUCTOS EN EL CATÁLOGO",
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  // --- MODAL REUTILIZABLE (CREAR / EDITAR) ---
  void _showProductModal(BuildContext context, {Product? product}) {
    final isEditing = product != null;

    // Inicializamos con los datos del producto si estamos editando
    final nameController = TextEditingController(text: product?.name ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');

    const List<String> unitOptions = [
      'bulto',
      'unidad',
      'millar',
      'caja',
      'saco',
      'docena',
      'otro',
    ];

    // Verificamos que la unidad exista en la lista (por si acaso viene un dato antiguo raro)
    String selectedUnit = isEditing && unitOptions.contains(product.unit)
        ? product.unit
        : 'bulto';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? "EDITAR PRODUCTO" : "REGISTRAR NUEVO PRODUCTO",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              // Nombre del Producto
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nombre del Producto",
                  hintText: "Ej: Harina PAN Maíz Blanco",
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
              ),
              const SizedBox(height: 15),

              // SKU / Código
              TextField(
                controller: skuController,
                decoration: const InputDecoration(
                  labelText: "SKU / Código Interno",
                  hintText: "Ej: HAR-001",
                  prefixIcon: Icon(Icons.qr_code_scanner),
                ),
              ),
              const SizedBox(height: 15),

              // Selector de Unidades
              DropdownButtonFormField<String>(
                initialValue: selectedUnit,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: const InputDecoration(
                  labelText: "Unidad de Medida",
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: unitOptions.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(
                      unit.toUpperCase(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setModalState(() => selectedUnit = value);
                },
              ),

              const SizedBox(height: 30),

              // Botón Guardar / Actualizar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("El nombre es obligatorio"),
                        ),
                      );
                      return;
                    }

                    final cubit = context.read<InventoryCubit>();
                    final cleanName = nameController.text.trim();
                    final cleanSku = skuController.text.trim().isEmpty
                        ? null
                        : skuController.text.trim();

                    if (isEditing) {
                      // LLAMADA A ACTUALIZAR (Asegúrate de tener este método en tu InventoryCubit)
                      cubit.updateProduct(
                        Product(
                          id: product.id,
                          name: cleanName,
                          unit: selectedUnit,
                          sku: cleanSku,
                          minStock: product.minStock,
                          isActive: product.isActive,
                        ),
                      );
                    } else {
                      // LLAMADA A CREAR
                      cubit.addProduct(
                        name: cleanName,
                        unit: selectedUnit,
                        sku: cleanSku,
                      );
                    }

                    Navigator.pop(context); // Cierra el modal

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing
                              ? "Producto actualizado"
                              : "Producto añadido al catálogo",
                        ),
                        backgroundColor: Colors.purple,
                      ),
                    );
                  },
                  child: Text(
                    isEditing ? "ACTUALIZAR PRODUCTO" : "GUARDAR EN CATÁLOGO",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
