import 'package:flutter/material.dart';

import '../../../data/api/api.dart';
import '../domain/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository({
    required ProductsApi productsApi,
    required InventoryApi inventoryApi,
    required SalesApi salesApi,
  })  : _productsApi = productsApi,
        _inventoryApi = inventoryApi,
        _salesApi = salesApi;

  final ProductsApi _productsApi;
  final InventoryApi _inventoryApi;
  final SalesApi _salesApi;

  Future<DashboardMetrics> fetchMetrics() async {
    final salesFuture = _salesApi.listSales();
    final lowStockFuture = _inventoryApi.getLowStock();
    final dailySummaryFuture = _salesApi.getDailySummary();

    final sales = await salesFuture;
    final lowStock = await lowStockFuture;
    final dailySummary = await dailySummaryFuture;

    final todayEntry = dailySummary.isNotEmpty ? dailySummary.first : null;
    final todayProfit = todayEntry?.profit ?? 0;
    final todaySales = todayEntry?.total ?? 0;

    return DashboardMetrics(
      todayProfit: todayProfit,
      salesToday: todaySales,
      lowStockItems: lowStock,
      recentSales: sales.take(5).toList(),
      quickActions: _quickActions,
    );
  }

  List<QuickAction> get _quickActions => [
        QuickAction(
          label: 'New Sale',
          route: '/sales/create',
          icon: ActionIcon(Icons.point_of_sale_rounded.codePoint),
        ),
        QuickAction(
          label: 'Add Product',
          route: '/products/add',
          icon: ActionIcon(Icons.add_box_rounded.codePoint),
        ),
        QuickAction(
          label: 'Add Expense',
          route: '/expenses/add',
          icon: ActionIcon(Icons.receipt_long_rounded.codePoint),
        ),
        QuickAction(
          label: 'Add Stock',
          route: '/inventory/add',
          icon: ActionIcon(Icons.inventory_2_rounded.codePoint),
        ),
      ];
}

