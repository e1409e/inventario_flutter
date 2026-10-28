import 'inventory_transaction.dart';

class PaginatedTransactions {
  final List<InventoryTransaction> items;
  final int totalCount;
  final int currentPage;
  final int pageSize;

  PaginatedTransactions({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
  });

  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
}

class DailyProductMovement {
  final String productId;
  final String productName;
  final String unit;
  final String? sku;
  final double totalQuantity;

  DailyProductMovement({
    required this.productId,
    required this.productName,
    required this.unit,
    this.sku,
    required this.totalQuantity,
  });
}
