/// Production Batch Model
/// Records production of finished goods with FIFO tracking
class ProductionBatch {
  final String id;
  final String businessOwnerId;
  final String productId;
  final String? batchNumber;
  final String productName;
  final int quantity;
  final double remainingQty;
  final DateTime batchDate;
  final DateTime? expiryDate;
  final double totalCost;
  final double costPerUnit;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductionBatch({
    required this.id,
    required this.businessOwnerId,
    required this.productId,
    this.batchNumber,
    required this.productName,
    required this.quantity,
    required this.remainingQty,
    required this.batchDate,
    this.expiryDate,
    required this.totalCost,
    required this.costPerUnit,
    this.notes,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if batch is fully used (no remaining units)
  bool get isFullyUsed => remainingQty <= 0;

  /// Check if batch is partially used
  bool get isPartiallyUsed => remainingQty > 0 && remainingQty < quantity;

  /// Check if batch is expired
  bool get isExpired => 
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Get percentage used
  double get usagePercentage => 
      quantity > 0 ? ((quantity - remainingQty) / quantity) * 100 : 0;

  /// Check if batch can be edited/deleted (within 24 hours or admin)
  bool canBeEdited({required bool isAdmin}) {
    final now = DateTime.now();
    final hoursSinceCreation = now.difference(createdAt).inHours;
    return isAdmin || hoursSinceCreation < 24;
  }

  /// Check if batch has been used in sales (remaining < quantity)
  bool get hasBeenUsed => remainingQty < quantity;

  factory ProductionBatch.fromJson(Map<String, dynamic> json) {
    return ProductionBatch(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      productId: json['product_id'] as String,
      batchNumber: json['batch_number'] as String?,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      remainingQty: (json['remaining_qty'] as num).toDouble(),
      batchDate: DateTime.parse(json['batch_date'] as String),
      expiryDate: json['expiry_date'] != null 
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      totalCost: (json['total_cost'] as num).toDouble(),
      costPerUnit: (json['cost_per_unit'] as num).toDouble(),
      notes: json['notes'] as String?,
      isCompleted: json['is_completed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'product_id': productId,
      'batch_number': batchNumber,
      'product_name': productName,
      'quantity': quantity,
      'remaining_qty': remainingQty,
      'batch_date': batchDate.toIso8601String().split('T')[0],
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'total_cost': totalCost,
      'cost_per_unit': costPerUnit,
      'notes': notes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Input model for creating production batches
class ProductionBatchInput {
  final String productId;
  final int quantity;
  final DateTime batchDate;
  final DateTime? expiryDate;
  final String? notes;
  final String? batchNumber;

  ProductionBatchInput({
    required this.productId,
    required this.quantity,
    required this.batchDate,
    this.expiryDate,
    this.notes,
    this.batchNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'p_product_id': productId,
      'p_quantity': quantity,
      'p_batch_date': batchDate.toIso8601String().split('T')[0],
      'p_expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'p_notes': notes,
      'p_batch_number': batchNumber,
    };
  }
}

