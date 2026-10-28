import '../widgets/daily_report_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/entities/inventory_transaction.dart';
import '../../../core/entities/paginated_transactions.dart';
import '../state/inventory_cubit.dart';
import '../state/inventory_state.dart';
import '../widgets/movement_form.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _searchQuery = "";
  TransactionType? _selectedType;
  int _currentPage = 1;
  static const int _pageSize = 15;
  Timer? _debounce;

  late Future<PaginatedTransactions> _historyFuture;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _loadPage() {
    _historyFuture = context
        .read<InventoryCubit>()
        .repository
        .getTransactionsPaginated(
          page: _currentPage,
          pageSize: _pageSize,
          type: _selectedType,
          searchQuery: _searchQuery,
        );
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchQuery = val.toLowerCase();
        _currentPage = 1; // Volvemos a la página 1 al filtrar
        _loadPage();
      });
    });
  }

  void _onFilterTypeChanged(TransactionType? type) {
    setState(() {
      _selectedType = type;
      _currentPage = 1;
      _loadPage();
    });
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
      _loadPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("HISTORIAL DE MOVIMIENTOS"),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.assessment_outlined,
              color: Colors.amberAccent,
              size: 22,
            ),
            tooltip: "Reportes Diarios (Entradas / Salidas)",
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFF1E1E1E),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => const DailyReportSheet(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: "Actualizar lista",
            onPressed: () => setState(() => _loadPage()),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. BUSCADOR
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: "BUSCAR POR NOTA O PRODUCTO...",
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),

          // 2. BARRA DE FILTROS + MENÚ COMPACTO DE REGISTRO
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Row(
              children: [
                // Chips de filtro con scroll horizontal por si la pantalla es muy angosta
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("TODOS", null),
                        const SizedBox(width: 6),
                        _buildFilterChip("ENTRADAS", TransactionType.inbound),
                        const SizedBox(width: 6),
                        _buildFilterChip("SALIDAS", TransactionType.outbound),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // MENÚ DESPLEGABLE COMPACTO (No estorba el historial)
                _buildCompactActionMenu(context),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 12),

          // 3. LISTA PAGINADA + BARRA DE PAGINACIÓN INFERIOR
          Expanded(
            child: BlocConsumer<InventoryCubit, InventoryState>(
              listener: (context, state) {
                if (state is InventoryLoaded) {
                  setState(() {
                    _currentPage = 1;
                    _loadPage();
                  });
                }
              },
              builder: (context, state) {
                return FutureBuilder<PaginatedTransactions>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Error al cargar historial: ${snapshot.error}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      );
                    }

                    final paginated = snapshot.data;
                    final transactions = paginated?.items ?? [];

                    if (transactions.isEmpty) {
                      return _buildEmptyState();
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              return _buildTransactionCard(transactions[index]);
                            },
                          ),
                        ),
                        // BARRA DE PAGINACIÓN CLÁSICA POR NUMERACIÓN (Adaptable Móvil/PC)
                        _buildPaginationBar(
                          currentPage: paginated!.currentPage,
                          totalPages: paginated.totalPages,
                          totalCount: paginated.totalCount,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- MENÚ COMPACTO PARA REGISTRAR MOVIMIENTO ---
  Widget _buildCompactActionMenu(BuildContext context) {
    return PopupMenuButton<TransactionType>(
      tooltip: "Registrar movimiento",
      color: const Color(0xFF262626),
      offset: const Offset(0, 38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white12),
      ),
      onSelected: (TransactionType type) => _showMovementSheet(context, type),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: TransactionType.inbound,
          child: Row(
            children: const [
              Icon(
                Icons.add_circle_outline,
                color: Colors.greenAccent,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                "NUEVA ENTRADA",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: TransactionType.outbound,
          child: Row(
            children: const [
              Icon(
                Icons.remove_circle_outline,
                color: Colors.orangeAccent,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                "NUEVA SALIDA",
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.swap_vert_rounded, size: 16, color: Colors.blueAccent),
            SizedBox(width: 6),
            Text(
              "REGISTRAR",
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  // --- PAGINADOR NUMÉRICO ADAPTABLE (MÓVIL Y ESCRITORIO) ---
  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        // En móvil mostramos máximo 5 botones numéricos; en escritorio hasta 9
        final maxVisiblePages = isWide ? 9 : 5;
        final pageNumbers = _calculatePageRange(
          currentPage,
          totalPages,
          maxVisiblePages,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            mainAxisAlignment: isWide
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              if (isWide)
                Text(
                  "TOTAL: $totalCount MOVIMIENTOS  •  PÁGINA $currentPage DE $totalPages",
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.white54,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ir al inicio
                  _buildPageIconButton(
                    icon: Icons.first_page_rounded,
                    enabled: currentPage > 1,
                    onTap: () => _goToPage(1),
                  ),
                  // Anterior
                  _buildPageIconButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: currentPage > 1,
                    onTap: () => _goToPage(currentPage - 1),
                  ),
                  const SizedBox(width: 4),

                  // Números de página
                  ...pageNumbers.map((page) {
                    final isCurrent = page == currentPage;
                    return GestureDetector(
                      onTap: isCurrent ? null : () => _goToPage(page),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.blueAccent
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCurrent
                                ? Colors.blueAccent
                                : Colors.white10,
                          ),
                        ),
                        child: Text(
                          "$page",
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrent ? Colors.white : Colors.white70,
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(width: 4),
                  // Siguiente
                  _buildPageIconButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: currentPage < totalPages,
                    onTap: () => _goToPage(currentPage + 1),
                  ),
                  // Ir al final
                  _buildPageIconButton(
                    icon: Icons.last_page_rounded,
                    enabled: currentPage < totalPages,
                    onTap: () => _goToPage(totalPages),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<int> _calculatePageRange(int current, int total, int maxVisible) {
    if (total <= maxVisible) {
      return List.generate(total, (i) => i + 1);
    }
    int half = maxVisible ~/ 2;
    int start = current - half;
    int end = current + half;

    if (start < 1) {
      start = 1;
      end = maxVisible;
    } else if (end > total) {
      end = total;
      start = total - maxVisible + 1;
    }
    return List.generate(end - start + 1, (i) => start + i);
  }

  Widget _buildPageIconButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? Colors.white70 : Colors.white24,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, TransactionType? type) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) =>
          _onFilterTypeChanged(selected ? type : null),
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            if (tx.description.isNotEmpty &&
                tx.description != "Sin descripcion" &&
                tx.description != "Sin descripción") ...[
              const SizedBox(height: 2),
              Text(
                tx.description,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
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
                  padding: const EdgeInsets.only(bottom: 6.0),
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
