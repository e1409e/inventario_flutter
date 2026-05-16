import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/entities/inventory_transaction.dart';
import '../state/inventory_cubit.dart';
import '../state/inventory_state.dart';
import '../widgets/movement_form.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String searchQuery = "";
  TransactionType?
  selectedType; // null = Todos, inbound = Entradas, outbound = Salidas

  // Guardamos el Future para no re-consultar la BD en cada pulsación de tecla
  late Future<List<InventoryTransaction>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    _historyFuture = context
        .read<InventoryCubit>()
        .repository
        .getTransactionHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("HISTORIAL DE MOVIMIENTOS")),
      body: Column(
        children: [
          // 1. BUSCADOR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: (val) =>
                  setState(() => searchQuery = val.toLowerCase()),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: "BUSCAR POR NOTA O PRODUCTO...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // 2. FILTROS RÁPIDOS (Chips)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _buildFilterChip("TODOS", null),
                const SizedBox(width: 8),
                _buildFilterChip("ENTRADAS", TransactionType.inbound),
                const SizedBox(width: 8),
                _buildFilterChip("SALIDAS", TransactionType.outbound),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. LISTA DE MOVIMIENTOS UNIFICADA
          Expanded(
            child: BlocConsumer<InventoryCubit, InventoryState>(
              listener: (context, state) {
                // Si el Cubit emite un nuevo estado (ej. se guardó un movimiento), recargamos el historial
                if (state is InventoryLoaded) {
                  setState(() {
                    _loadHistory();
                  });
                }
              },
              builder: (context, state) {
                return FutureBuilder<List<InventoryTransaction>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error al cargar historial: ${snapshot.error}",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      );
                    }

                    final transactions = snapshot.data ?? [];

                    // Aplicamos el buscador y los filtros en memoria
                    final filteredTransactions = transactions.where((tx) {
                      final matchesType =
                          selectedType == null || tx.type == selectedType;
                      final matchesSearch =
                          searchQuery.isEmpty ||
                          tx.description.toLowerCase().contains(searchQuery) ||
                          tx.items.any(
                            (item) => item.productName.toLowerCase().contains(
                              searchQuery,
                            ),
                          );

                      return matchesType && matchesSearch;
                    }).toList();

                    if (filteredTransactions.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = filteredTransactions[index];
                        return _buildTransactionCard(tx);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(context),
    );
  }

  // --- WIDGETS DE UI ---

  Widget _buildFilterChip(String label, TransactionType? type) {
    final isSelected = selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) =>
          setState(() => selectedType = selected ? type : null),
      selectedColor: Colors.blueAccent.withValues(alpha: 0.2),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blueAccent : Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(
          color: isSelected ? Colors.blueAccent : Colors.white10,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildFloatingButtons(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: "inbound",
          onPressed: () => _showMovementSheet(context, TransactionType.inbound),
          label: const Text("ENTRADA"),
          icon: const Icon(Icons.add),
          backgroundColor: Colors.greenAccent.withValues(alpha: 0.8),
          foregroundColor: Colors.black,
        ),
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          heroTag: "outbound",
          onPressed: () =>
              _showMovementSheet(context, TransactionType.outbound),
          label: const Text("SALIDA"),
          icon: const Icon(Icons.remove),
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.8),
          foregroundColor: Colors.black,
        ),
      ],
    );
  }

  void _showMovementSheet(BuildContext context, TransactionType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MovementForm(type: type),
      ),
    );
  }

  Widget _buildTransactionCard(InventoryTransaction tx) {
    final isInbound = tx.type == TransactionType.inbound;
    final color = isInbound ? Colors.greenAccent : Colors.orangeAccent;
    final icon = isInbound
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;
    final title = isInbound ? "ENTRADA" : "SALIDA";

    final formattedDate = DateFormat(
      'dd/MM/yyyy • hh:mm a',
    ).format(tx.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            if (tx.description.isNotEmpty &&
                tx.description != "Sin descripción") ...[
              const SizedBox(height: 4),
              Text(
                tx.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tx.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        "${item.quantity} unds",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            "NO HAY MOVIMIENTOS REGISTRADOS",
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
