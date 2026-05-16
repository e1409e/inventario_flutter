import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/entities/inventory_transaction.dart';
import '../../../core/entities/product.dart';
import '../state/inventory_cubit.dart';
import '../state/inventory_state.dart';

class MovementForm extends StatefulWidget {
  final TransactionType type;
  const MovementForm({super.key, required this.type});

  @override
  State<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<MovementForm> {
  int _currentStep = 0;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Mapa para guardar ID del producto y la cantidad a mover
  final Map<String, double> _selectedQuantities = {};
  String _filter = "";

  @override
  Widget build(BuildContext context) {
    final bool isInbound = widget.type == TransactionType.inbound;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: BlocBuilder<InventoryCubit, InventoryState>(
        builder: (context, state) {
          if (state is! InventoryLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              const SizedBox(height: 16),
              _buildHeader(isInbound),
              const Divider(color: Colors.white10),
              Expanded(
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_currentStep < 2) {
                      if (_currentStep == 0 && _selectedQuantities.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Selecciona al menos un producto"),
                          ),
                        );
                        return;
                      }
                      setState(() => _currentStep++);
                    } else {
                      _submitForm();
                    }
                  },
                  onStepCancel: () {
                    // CORRECCIÓN APLICADA AQUÍ
                    if (_currentStep > 0) {
                      setState(() => _currentStep--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  steps: [
                    _buildStepSelection(state.products),
                    _buildStepQuantities(state.products),
                    _buildStepConfirmation(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // PASO 1: Selección de productos
  Step _buildStepSelection(List<Product> products) {
    final filtered = products
        .where(
          (p) =>
              p.name.toLowerCase().contains(_filter) ||
              (p.sku?.toLowerCase().contains(_filter) ?? false),
        )
        .toList();

    return Step(
      title: const Text(
        "Seleccionar Productos",
        style: TextStyle(fontSize: 12),
      ),
      content: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _filter = v.toLowerCase()),
            decoration: const InputDecoration(
              hintText: "Filtrar catálogo...",
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final p = filtered[index];
                final isSelected = _selectedQuantities.containsKey(p.id);
                return CheckboxListTile(
                  title: Text(p.name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    p.sku ?? "SIN SKU",
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                  value: isSelected,
                  activeColor: widget.type == TransactionType.inbound
                      ? Colors.greenAccent
                      : Colors.orangeAccent,
                  onChanged: (val) {
                    // CORRECCIÓN APLICADA AQUÍ
                    setState(() {
                      if (val == true) {
                        _selectedQuantities[p.id] = 0;
                      } else {
                        _selectedQuantities.remove(p.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      isActive: _currentStep >= 0,
    );
  }

  // PASO 2: Ingreso de cantidades
  Step _buildStepQuantities(List<Product> products) {
    final selectedOnes = products
        .where((p) => _selectedQuantities.containsKey(p.id))
        .toList();

    return Step(
      title: const Text("Definir Cantidades", style: TextStyle(fontSize: 12)),
      content: Column(
        children: selectedOnes.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(p.name, style: const TextStyle(fontSize: 12)),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      suffixText: p.unit,
                      isDense: true,
                    ),
                    onChanged: (val) =>
                        _selectedQuantities[p.id] = double.tryParse(val) ?? 0,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
      isActive: _currentStep >= 1,
    );
  }

  // PASO 3: Confirmación y Nota
  Step _buildStepConfirmation() {
    return Step(
      title: const Text("Finalizar", style: TextStyle(fontSize: 12)),
      content: Column(
        children: [
          const Text(
            "Añade una descripción para el historial:",
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Ej: Despacho a cliente X...",
            ),
          ),
        ],
      ),
      isActive: _currentStep >= 2,
    );
  }

  Widget _buildHeader(bool isInbound) {
    return Text(
      isInbound ? "REGISTRAR ENTRADA" : "REGISTRAR SALIDA",
      style: TextStyle(
        color: isInbound ? Colors.greenAccent : Colors.orangeAccent,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        fontSize: 12,
      ),
    );
  }

  void _submitForm() {
    // 1. Limpiamos las cantidades en cero por si el usuario marcó un check pero no puso número
    final validItems = Map<String, double>.fromEntries(
      _selectedQuantities.entries.where((e) => e.value > 0),
    );

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debes ingresar cantidades mayores a 0")),
      );
      return;
    }

    final description = _descriptionController.text.trim();

    // 2. Llamamos al Cubit usando el context
    context.read<InventoryCubit>().registerMovement(
      type: widget.type,
      items: validItems,
      description: description.isNotEmpty ? description : null,
    );

    // 3. Cerramos el modal
    Navigator.pop(context);

    // 4. Mostramos feedback visual al usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.type == TransactionType.inbound
              ? "Entrada registrada con éxito"
              : "Salida registrada con éxito",
        ),
        backgroundColor: widget.type == TransactionType.inbound
            ? Colors.green
            : Colors.orange,
      ),
    );
  }
}
