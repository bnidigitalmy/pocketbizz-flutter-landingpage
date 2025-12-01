/// Finished Product Summary Model
/// Aggregated view of finished products with total remaining and batch info
class FinishedProductSummary {
  final String productId;
  final String productName;
  final double totalRemaining;
  final DateTime? nearestExpiry;
  final int batchCount;

  FinishedProductSummary({
    required this.productId,
    required this.productName,
    required this.totalRemaining,
    this.nearestExpiry,
    required this.batchCount,
  });

  factory FinishedProductSummary.fromJson(Map<String, dynamic> json) {
    return FinishedProductSummary(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      totalRemaining: (json['total_remaining'] as num).toDouble(),
      nearestExpiry: json['nearest_expiry'] != null
          ? DateTime.parse(json['nearest_expiry'] as String)
          : null,
      batchCount: (json['batch_count'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'total_remaining': totalRemaining,
      'nearest_expiry': nearestExpiry?.toIso8601String(),
      'batch_count': batchCount,
    };
  }
}

/// Production Batch Model
/// Individual batch of finished product
class ProductionBatch {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final double remainingQty;
  final DateTime batchDate;
  final DateTime? expiryDate;
  final double totalCost;
  final String? notes;
  final DateTime createdAt;

  ProductionBatch({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.remainingQty,
    required this.batchDate,
    this.expiryDate,
    required this.totalCost,
    this.notes,
    required this.createdAt,
  });

  factory ProductionBatch.fromJson(Map<String, dynamic> json) {
    return ProductionBatch(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? json['products']?['name'] as String? ?? '',
      quantity: (json['quantity'] as num).toInt(),
      remainingQty: (json['remaining_qty'] as num).toDouble(),
      batchDate: json['batch_date'] is String
          ? DateTime.parse(json['batch_date'] as String)
          : DateTime.now(),
      expiryDate: json['expiry_date'] != null
          ? (json['expiry_date'] is String
              ? DateTime.parse(json['expiry_date'] as String)
              : null)
          : null,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'remaining_qty': remainingQty,
      'batch_date': batchDate.toIso8601String().split('T')[0],
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'total_cost': totalCost,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get percentage of remaining quantity
  double get remainingPercentage => quantity > 0 ? (remainingQty / quantity) * 100 : 0.0;
}

