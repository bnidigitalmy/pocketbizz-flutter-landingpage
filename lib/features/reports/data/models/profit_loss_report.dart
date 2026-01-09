/// Profit & Loss Report Model
/// Following standard accounting P&L format:
/// Revenue -> COGS -> Gross Profit -> Operating Expenses -> Operating Profit -> Other Items -> Net Profit
class ProfitLossReport {
  final double totalSales; // Revenue / Jualan
  final double costOfGoodsSold; // COGS / Kos Pengeluaran
  final double grossProfit; // Untung Kasar
  final double operatingExpenses; // Kos Operasi
  final double operatingProfit; // Untung Operasi (EBIT)
  final double otherExpenses; // Other expenses (e.g., rejection loss)
  final double netProfit; // Untung Bersih
  final double grossProfitMargin; // Gross Profit Margin %
  final double netProfitMargin; // Net Profit Margin %
  final DateTime? startDate;
  final DateTime? endDate;

  // Legacy fields for backward compatibility
  @Deprecated('Use costOfGoodsSold + operatingExpenses instead')
  double get totalCosts => costOfGoodsSold + operatingExpenses;
  
  @Deprecated('Use otherExpenses instead')
  double get rejectionLoss => otherExpenses;
  
  @Deprecated('Use netProfitMargin instead')
  double get profitMargin => netProfitMargin;

  ProfitLossReport({
    required this.totalSales,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.operatingProfit,
    required this.otherExpenses,
    required this.netProfit,
    required this.grossProfitMargin,
    required this.netProfitMargin,
    this.startDate,
    this.endDate,
  });

  // Factory constructor for legacy compatibility
  factory ProfitLossReport.fromLegacy({
    required double totalSales,
    required double totalCosts,
    required double rejectionLoss,
    required double netProfit,
    required double profitMargin,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Estimate COGS vs Operating Expenses (60% COGS, 40% OpEx if no breakdown)
    final estimatedCogs = totalCosts * 0.6;
    final estimatedOpEx = totalCosts * 0.4;
    final grossProfit = totalSales - estimatedCogs;
    final operatingProfit = grossProfit - estimatedOpEx;
    
    return ProfitLossReport(
      totalSales: totalSales,
      costOfGoodsSold: estimatedCogs,
      grossProfit: grossProfit,
      operatingExpenses: estimatedOpEx,
      operatingProfit: operatingProfit,
      otherExpenses: rejectionLoss,
      netProfit: netProfit,
      grossProfitMargin: totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0,
      netProfitMargin: profitMargin,
      startDate: startDate,
      endDate: endDate,
    );
  }

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) {
    // Support both new format (with COGS breakdown) and legacy format
    if (json.containsKey('costOfGoodsSold') && json.containsKey('grossProfit')) {
      // New format
      return ProfitLossReport(
        totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
        costOfGoodsSold: (json['costOfGoodsSold'] as num?)?.toDouble() ?? 0.0,
        grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0.0,
        operatingExpenses: (json['operatingExpenses'] as num?)?.toDouble() ?? 0.0,
        operatingProfit: (json['operatingProfit'] as num?)?.toDouble() ?? 0.0,
        otherExpenses: (json['otherExpenses'] as num?)?.toDouble() ?? 0.0,
        netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
        grossProfitMargin: (json['grossProfitMargin'] as num?)?.toDouble() ?? 0.0,
        netProfitMargin: (json['netProfitMargin'] as num?)?.toDouble() ?? 0.0,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
      );
    } else {
      // Legacy format - convert to new format
      final totalSales = (json['totalSales'] as num?)?.toDouble() ?? 0.0;
      final totalCosts = (json['totalCosts'] as num?)?.toDouble() ?? 0.0;
      final rejectionLoss = (json['rejectionLoss'] as num?)?.toDouble() ?? 0.0;
      final netProfit = (json['netProfit'] as num?)?.toDouble() ?? 0.0;
      final profitMargin = (json['profitMargin'] as num?)?.toDouble() ?? 0.0;
      
      return ProfitLossReport.fromLegacy(
        totalSales: totalSales,
        totalCosts: totalCosts,
        rejectionLoss: rejectionLoss,
        netProfit: netProfit,
        profitMargin: profitMargin,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'] as String)
            : null,
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
      );
    }
  }

  Map<String, dynamic> toJson() => {
        // New standard format fields
        'totalSales': totalSales,
        'costOfGoodsSold': costOfGoodsSold,
        'grossProfit': grossProfit,
        'operatingExpenses': operatingExpenses,
        'operatingProfit': operatingProfit,
        'otherExpenses': otherExpenses,
        'netProfit': netProfit,
        'grossProfitMargin': grossProfitMargin,
        'netProfitMargin': netProfitMargin,
        // Legacy fields for backward compatibility
        'totalCosts': totalCosts,
        'rejectionLoss': rejectionLoss,
        'profitMargin': profitMargin,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };
}

