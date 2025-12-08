/// Plan Limits Model
/// Tracks usage limits for subscription plan
class PlanLimits {
  final LimitInfo products;
  final LimitInfo stockItems;
  final LimitInfo transactions;

  PlanLimits({
    required this.products,
    required this.stockItems,
    required this.transactions,
  });

  factory PlanLimits.fromJson(Map<String, dynamic> json) {
    return PlanLimits(
      products: LimitInfo.fromJson(json['products'] as Map<String, dynamic>),
      stockItems: LimitInfo.fromJson(json['stock_items'] as Map<String, dynamic>),
      transactions: LimitInfo.fromJson(json['transactions'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'products': products.toJson(),
      'stock_items': stockItems.toJson(),
      'transactions': transactions.toJson(),
    };
  }
}

class LimitInfo {
  final int current;
  final int max; // Use -1 or 999999 for unlimited

  LimitInfo({
    required this.current,
    required this.max,
  });

  factory LimitInfo.fromJson(Map<String, dynamic> json) {
    return LimitInfo(
      current: json['current'] as int? ?? 0,
      max: json['max'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'max': max,
    };
  }

  bool get isUnlimited => max >= 999999 || max == -1;
  
  double get usagePercentage {
    if (isUnlimited) return 0.0;
    if (max == 0) return 0.0;
    return (current / max * 100).clamp(0.0, 100.0);
  }

  String get displayMax => isUnlimited ? '∞' : max.toString();
}


