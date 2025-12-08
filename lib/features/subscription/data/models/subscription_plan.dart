/// Subscription Plan Model
/// Represents available subscription packages (1, 3, 6, 12 months)
class SubscriptionPlan {
  final String id;
  final String name; // e.g., "1 Bulan", "3 Bulan"
  final int durationMonths;
  final double pricePerMonth;
  final double totalPrice;
  final double discountPercentage;
  final bool isActive;
  final int displayOrder;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.durationMonths,
    required this.pricePerMonth,
    required this.totalPrice,
    required this.discountPercentage,
    required this.isActive,
    required this.displayOrder,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMonths: json['duration_months'] as int,
      pricePerMonth: (json['price_per_month'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      discountPercentage: (json['discount_percentage'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'duration_months': durationMonths,
      'price_per_month': pricePerMonth,
      'total_price': totalPrice,
      'discount_percentage': discountPercentage,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }

  /// Calculate price for early adopter (RM 29/month instead of RM 39/month)
  double getPriceForEarlyAdopter() {
    final basePrice = 29.0; // Early adopter price per month
    final total = basePrice * durationMonths;
    
    // Apply same discount percentage
    if (discountPercentage > 0) {
      return total * (1 - discountPercentage / 100);
    }
    return total;
  }

  /// Get savings text for display
  String? getSavingsText() {
    if (durationMonths == 6) return 'Jimat 8%';
    if (durationMonths == 12) return 'Jimat 15%';
    return null;
  }

  /// Get price per month text
  String getPricePerMonthText(bool isEarlyAdopter) {
    final price = isEarlyAdopter ? getPriceForEarlyAdopter() : totalPrice;
    final perMonth = price / durationMonths;
    return 'RM${perMonth.toStringAsFixed(0)}/bulan';
  }
}


