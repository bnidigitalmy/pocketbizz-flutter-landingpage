/// Monthly Trend Model for Reports
class MonthlyTrend {
  final String month;
  final double sales;
  final double costs;

  MonthlyTrend({
    required this.month,
    required this.sales,
    required this.costs,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: json['month'] as String,
      sales: (json['sales'] as num?)?.toDouble() ?? 0.0,
      costs: (json['costs'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'month': month,
        'sales': sales,
        'costs': costs,
      };
}

