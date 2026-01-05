import 'package:flutter/foundation.dart';

@immutable
class TopProductUnits {
  final String key; // normalized key (lowercase/trimmed)
  final String displayName; // original-friendly name (best effort)
  final double units;

  const TopProductUnits({
    required this.key,
    required this.displayName,
    required this.units,
  });
}

@immutable
class DashboardMoneySummary {
  final double inflow; // Masuk (Sales)
  final double productionCost; // Kos Pengeluaran (COGS)
  final double profit; // inflow - productionCost
  final double expense; // Belanja (Expenses - untuk info sahaja)
  final int transactions; // transaksi (kept for internal use)

  const DashboardMoneySummary({
    required this.inflow,
    required this.productionCost,
    required this.profit,
    required this.expense,
    required this.transactions,
  });
}

@immutable
class DashboardCashflowWeekly {
  final double inflow;
  final double expense;
  final double net; // inflow - expense

  const DashboardCashflowWeekly({
    required this.inflow,
    required this.expense,
    required this.net,
  });
}

@immutable
class DashboardTopProducts {
  final List<TopProductUnits> todayTop3;
  final List<TopProductUnits> weekTop3;

  const DashboardTopProducts({
    required this.todayTop3,
    required this.weekTop3,
  });
}

@immutable
class DashboardProductionSuggestion {
  final bool show;
  final String title;
  final String message;

  const DashboardProductionSuggestion({
    required this.show,
    required this.title,
    required this.message,
  });
}

@immutable
class SmeDashboardV2Data {
  final DashboardMoneySummary today;
  final DashboardCashflowWeekly week;
  final DashboardTopProducts topProducts;
  final DashboardProductionSuggestion productionSuggestion;

  const SmeDashboardV2Data({
    required this.today,
    required this.week,
    required this.topProducts,
    required this.productionSuggestion,
  });
}


