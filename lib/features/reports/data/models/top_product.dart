/// Top Product Model for Reports
class TopProduct {
  final String productId;
  final String productName;
  final double totalSold;
  final double totalRevenue;
  final double totalProfit;
  final double profitMargin;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.totalSold,
    required this.totalRevenue,
    required this.totalProfit,
    required this.profitMargin,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: json['productId'] as String? ?? json['product_id'] as String,
      productName:
          json['productName'] as String? ?? json['product_name'] as String,
      totalSold: (json['totalSold'] as num?)?.toDouble() ??
          (json['total_sold'] as num?)?.toDouble() ??
          0.0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ??
          (json['total_revenue'] as num?)?.toDouble() ??
          0.0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ??
          (json['total_profit'] as num?)?.toDouble() ??
          0.0,
      profitMargin: (json['profitMargin'] as num?)?.toDouble() ??
          (json['profit_margin'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'totalSold': totalSold,
        'totalRevenue': totalRevenue,
        'totalProfit': totalProfit,
        'profitMargin': profitMargin,
      };
}

