import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../state/inventory_cubit.dart';
import '../state/inventory_state.dart';
import '../widgets/product_inventory_card.dart';
import '../../../core/entities/stock_status.dart';
import '../../../core/entities/product.dart';
import '../../../core/utils/pdf_report_generator.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final Set<String> _selectedProductIds = {};
  bool _isSelectionMode = false;
  String _searchQuery = "";

  // Controles de Filtro Avanzado
  bool _showFilters = false;
  final TextEditingController _minStockController = TextEditingController();
  final TextEditingController _maxStockController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _minStockController.dispose();
    _maxStockController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE ESTADO LOCAL ---

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedProductIds.clear();
      }
    });
  }

  void _toggleProductSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        if (_selectedProductIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _enableSelectionModeWithProduct(String productId) {
    setState(() {
      _isSelectionMode = true;
      _selectedProductIds.add(productId);
    });
  }

  double _getQuantityForProduct(String productId, List<StockStatus> stockList) {
    final matches = stockList.where((s) => s.productId == productId);
    if (matches.isNotEmpty) {
      return matches.first.currentQuantity;
    }
    return 0.0;
  }

  DateTime? _getLastUpdateForProduct(
    String productId,
    List<StockStatus> stockList,
  ) {
    final matches = stockList.where((s) => s.productId == productId);
    if (matches.isNotEmpty) {
      return matches.first.lastUpdated;
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _minStockController.clear();
      _maxStockController.clear();
      _selectedDate = null;
    });
  }

  // --- GENERACIÓN DE REPORTE ---
  Future<void> _generatePdf(
    List<Product> products,
    List<StockStatus> stockList,
  ) async {
    try {
      final pdfBytes = await PdfReportGenerator.generateStockReport(
        products: products,
        stockList: stockList,
        selectedIds: _selectedProductIds,
      );

      if (mounted) {
        // Muestra la vista previa del PDF usando el paquete printing
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Reporte_Inventario_TripleAAA.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // --- CONSTRUCCIÓN DE LA UI ---

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: _buildAppBar(state),
          body: Column(
            children: [
              _buildSearchBar(),
              if (_showFilters) _buildAdvancedFilters(),
              Expanded(child: _buildBodyContent(state)),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(InventoryState state) {
    return AppBar(
      title: _isSelectionMode
          ? Text("${_selectedProductIds.length} SELECCIONADOS")
          : const Text("INVENTARIO DISPONIBLE"),
      actions: [
        IconButton(
          icon: Icon(
            _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
            color: _showFilters ? Colors.blueAccent : Colors.white,
          ),
          onPressed: () => setState(() => _showFilters = !_showFilters),
        ),
        if (_isSelectionMode || state is InventoryLoaded)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            onPressed: () {
              if (state is InventoryLoaded) {
                _generatePdf(state.products, state.stockList);
              }
            },
          ),
        IconButton(
          icon: Icon(_isSelectionMode ? Icons.close : Icons.select_all),
          onPressed: _toggleSelectionMode,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        decoration: InputDecoration(
          hintText: "BUSCAR POR NOMBRE O SKU...",
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minStockController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Stock Mínimo",
                    isDense: true,
                    prefixIcon: Icon(Icons.remove, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxStockController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: "Stock Máximo",
                    isDense: true,
                    prefixIcon: Icon(Icons.add, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(context),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _selectedDate != null
                        ? "Actualizado el: ${DateFormat('dd/MM/yy').format(_selectedDate!)}"
                        : "Filtrar por Fecha",
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (_minStockController.text.isNotEmpty ||
                  _maxStockController.text.isNotEmpty ||
                  _selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                  onPressed: _clearFilters,
                  tooltip: "Limpiar filtros",
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(InventoryState state) {
    if (state is InventoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is InventoryLoaded) {
      return _buildInventoryList(state.products, state.stockList);
    }

    if (state is InventoryError) {
      return Center(
        child: Text(
          "ERROR: ${state.message}",
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    return const Center(child: Text("ESTADO DESCONOCIDO"));
  }

  Widget _buildInventoryList(
    List<Product> products,
    List<StockStatus> stockList,
  ) {
    // Obtenemos valores de filtro numérico
    final double? minStock = double.tryParse(_minStockController.text);
    final double? maxStock = double.tryParse(_maxStockController.text);

    // Filtrado en memoria (combinando búsqueda, cantidades y fechas)
    final filteredProducts = products.where((p) {
      // 1. Filtro de texto (Buscador)
      final matchName = p.name.toLowerCase().contains(_searchQuery);
      final matchSku = p.sku?.toLowerCase().contains(_searchQuery) ?? false;
      if (!matchName && !matchSku) return false;

      final currentStock = _getQuantityForProduct(p.id, stockList);

      // 2. Filtros Numéricos
      if (minStock != null && currentStock < minStock) return false;
      if (maxStock != null && currentStock > maxStock) return false;

      // 3. Filtro de Fecha (Compara día, mes y año)
      if (_selectedDate != null) {
        final lastUpdate = _getLastUpdateForProduct(p.id, stockList);
        if (lastUpdate == null)
          return false; // Si no tiene actualización, no cumple

        if (lastUpdate.year != _selectedDate!.year ||
            lastUpdate.month != _selectedDate!.month ||
            lastUpdate.day != _selectedDate!.day) {
          return false;
        }
      }

      return true;
    }).toList();

    // Manejo de estado vacío
    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 16),
            const Text(
              "NO SE ENCONTRARON RESULTADOS",
              style: TextStyle(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final currentStock = _getQuantityForProduct(product.id, stockList);

        return ProductInventoryCard(
          product: product,
          currentStock: currentStock,
          isSelected: _selectedProductIds.contains(product.id),
          onTap: () {
            if (_isSelectionMode) {
              _toggleProductSelection(product.id);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _enableSelectionModeWithProduct(product.id);
            }
          },
        );
      },
    );
  }
}
