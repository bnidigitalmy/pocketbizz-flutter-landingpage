/// Profit & Loss Report Model
class ProfitLossReport {
  final double totalSales;
  final double totalCosts;
  final double rejectionLoss;
  final double netProfit;
  final double profitMargin;
  final DateTime? startDate;
  final DateTime? endDate;

  ProfitLossReport({
    required this.totalSales,
    required this.totalCosts,
    required this.rejectionLoss,
    required this.netProfit,
    required this.profitMargin,
    this.startDate,
    this.endDate,
  });

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) {
    return ProfitLossReport(
      totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalCosts: (json['totalCosts'] as num?)?.toDouble() ?? 0.0,
      rejectionLoss: (json['rejectionLoss'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['netProfit'] as num?)?.toDouble() ?? 0.0,
      profitMargin: (json['profitMargin'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalSales': totalSales,
        'totalCosts': totalCosts,
        'rejectionLoss': rejectionLoss,
        'netProfit': netProfit,
        'profitMargin': profitMargin,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
      };
}

