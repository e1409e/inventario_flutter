import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
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

  // null = Fecha y hora actual automática; si tiene valor = Fecha contable elegida
  DateTime? _selectedCustomDate;

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = TransactionCategories.forType(widget.type).first;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickMovementDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCustomDate ?? now,
      firstDate: DateTime(2023),
      lastDate: now, // No permite registrar tickets en el futuro
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

    if (picked != null) {
      setState(() {
        final isToday =
            picked.year == now.year &&
            picked.month == now.month &&
            picked.day == now.day;

        if (isToday) {
          // Si selecciona hoy, volvemos al modo automático con la hora actual
          _selectedCustomDate = null;
        } else {
          // Si es de un día anterior, lo fijamos al cierre de ese día (23:59:00)
          _selectedCustomDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            23,
            59,
            0,
          );
        }
      });
    }
  }

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
            child: Material(
              color: Colors.transparent,
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

  // PASO 3: Fecha Contable, Confirmación y Nota
  Step _buildStepConfirmation() {
    final bool isInbound = widget.type == TransactionType.inbound;
    final Color activeColor = isInbound
        ? Colors.greenAccent
        : Colors.orangeAccent;
    final List<String> categories = TransactionCategories.forType(widget.type);

    final bool isCustomDate = _selectedCustomDate != null;
    final String dateText = isCustomDate
        ? "FECHA: ${DateFormat('dd/MM/yyyy').format(_selectedCustomDate!)} (DIFERIDO)"
        : "FECHA: HOY (AUTOMÁTICO)";

    return Step(
      title: const Text("Finalizar", style: TextStyle(fontSize: 12)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Categoría del movimiento:",
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories.map((cat) {
              final bool isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat.toUpperCase()),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                selectedColor: activeColor.withValues(alpha: 0.2),
                backgroundColor: Colors.white.withValues(alpha: 0.04),
                labelStyle: TextStyle(
                  color: isSelected ? activeColor : Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: isSelected ? activeColor : Colors.white12,
                  ),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Text(
            "Fecha contable del ticket:",
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickMovementDate,
                  icon: Icon(
                    Icons.event_note_rounded,
                    size: 16,
                    color: isCustomDate
                        ? Colors.amberAccent
                        : Colors.blueAccent,
                  ),
                  label: Text(
                    dateText,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: isCustomDate ? Colors.amberAccent : Colors.white70,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isCustomDate
                          ? Colors.amberAccent.withValues(alpha: 0.6)
                          : Colors.white24,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (isCustomDate) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  tooltip: "Restablecer a hoy",
                  onPressed: () => setState(() => _selectedCustomDate = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "Añade una descripción para el historial:",
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "Ej: Despacho a cliente X / Ticket pendiente...",
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

    // 2. Llamamos al Cubit pasando también la fecha elegida (o null si es hoy)
    context.read<InventoryCubit>().registerMovement(
      type: widget.type,
      items: validItems,
      category: _selectedCategory,
      description: description.isNotEmpty ? description : null,
      customDate: _selectedCustomDate,
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
