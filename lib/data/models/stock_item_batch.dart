/// Stock Item Batch Model
/// Tracks batches of stock items dengan expiry dates untuk FIFO management
class StockItemBatch {
  final String id;
  final String businessOwnerId;
  final String stockItemId;
  
  // Batch Information
  final String? batchNumber;
  final double quantity; // Total quantity dalam batch ni
  final double remainingQty; // Quantity yang masih ada (FIFO)
  
  // Purchase Information
  final DateTime purchaseDate;
  final DateTime? expiryDate; // Tarikh luput (optional)
  final double purchasePrice; // Harga untuk batch ni
  final double packageSize; // Saiz package (snapshot)
  
  // Costing
  final double costPerUnit; // Cost per unit untuk batch ni
  
  // Metadata
  final String? supplierName;
  final String? notes;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  StockItemBatch({
    required this.id,
    required this.businessOwnerId,
    required this.stockItemId,
    this.batchNumber,
    required this.quantity,
    required this.remainingQty,
    required this.purchaseDate,
    this.expiryDate,
    required this.purchasePrice,
    required this.packageSize,
    required this.costPerUnit,
    this.supplierName,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if batch is fully used
  bool get isFullyUsed => remainingQty <= 0;

  /// Check if batch is partially used
  bool get isPartiallyUsed => remainingQty > 0 && remainingQty < quantity;

  /// Check if batch is expired
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Check if batch is expiring soon (within 7 days)
  bool get isExpiringSoon => expiryDate != null && 
      expiryDate!.isAfter(DateTime.now()) &&
      expiryDate!.difference(DateTime.now()).inDays <= 7;

  /// Get percentage used
  double get usagePercentage => quantity > 0 ? ((quantity - remainingQty) / quantity) * 100 : 0;

  factory StockItemBatch.fromJson(Map<String, dynamic> json) {
    return StockItemBatch(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      stockItemId: json['stock_item_id'] as String,
      batchNumber: json['batch_number'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      remainingQty: (json['remaining_qty'] as num).toDouble(),
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      expiryDate: json['expiry_date'] != null 
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      purchasePrice: (json['purchase_price'] as num).toDouble(),
      packageSize: (json['package_size'] as num).toDouble(),
      costPerUnit: (json['cost_per_unit'] as num).toDouble(),
      supplierName: json['supplier_name'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'stock_item_id': stockItemId,
      'batch_number': batchNumber,
      'quantity': quantity,
      'remaining_qty': remainingQty,
      'purchase_date': purchaseDate.toIso8601String().split('T')[0],
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'purchase_price': purchasePrice,
      'package_size': packageSize,
      'cost_per_unit': costPerUnit,
      'supplier_name': supplierName,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Input model for creating stock item batches
class StockItemBatchInput {
  final String stockItemId;
  final double quantity;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final double purchasePrice;
  final double packageSize;
  final String? batchNumber;
  final String? supplierName;
  final String? notes;
  final bool recordMovement; // Whether to record stock movement

  StockItemBatchInput({
    required this.stockItemId,
    required this.quantity,
    required this.purchaseDate,
    this.expiryDate,
    required this.purchasePrice,
    required this.packageSize,
    this.batchNumber,
    this.supplierName,
    this.notes,
    this.recordMovement = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'p_stock_item_id': stockItemId,
      'p_quantity': quantity,
      'p_purchase_date': purchaseDate.toIso8601String().split('T')[0],
      'p_expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'p_purchase_price': purchasePrice,
      'p_package_size': packageSize,
      'p_batch_number': batchNumber,
      'p_supplier_name': supplierName,
      'p_notes': notes,
      'p_record_movement': recordMovement,
    };
  }
}
