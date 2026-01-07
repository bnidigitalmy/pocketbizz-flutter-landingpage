/// Stock Item Model
/// Represents raw materials/ingredients in warehouse inventory
class StockItem {
  final String id;
  final String businessOwnerId;
  final String name;
  final String unit;
  final double packageSize;
  final double purchasePrice;
  final double currentQuantity;
  final double lowStockThreshold;
  final String? notes;
  final String? supplierId; // Optional supplier reference (suppliers table - pembekal bahan mentah)
  final int version;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  StockItem({
    required this.id,
    required this.businessOwnerId,
    required this.name,
    required this.unit,
    required this.packageSize,
    required this.purchasePrice,
    required this.currentQuantity,
    required this.lowStockThreshold,
    this.notes,
    this.supplierId,
    required this.version,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate cost per unit
  /// Example: Package of 500gram costs RM21.90 → RM0.0438 per gram
  double get costPerUnit => purchasePrice / packageSize;

  /// Check if stock is low
  bool get isLowStock => currentQuantity <= lowStockThreshold;

  /// Calculate stock level percentage
  double get stockLevelPercentage =>
      (currentQuantity / lowStockThreshold) * 100;

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      packageSize: (json['package_size'] as num?)?.toDouble() ?? 1.0,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble() ?? 0.0,
      currentQuantity: (json['current_quantity'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toDouble() ?? 5.0,
      notes: json['notes'] as String?,
      supplierId: json['supplier_id'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 0,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'name': name,
      'unit': unit,
      'package_size': packageSize,
      'purchase_price': purchasePrice,
      'current_quantity': currentQuantity,
      'low_stock_threshold': lowStockThreshold,
      'notes': notes,
      'supplier_id': supplierId,
      'version': version,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StockItem copyWith({
    String? id,
    String? businessOwnerId,
    String? name,
    String? unit,
    double? packageSize,
    double? purchasePrice,
    double? currentQuantity,
    double? lowStockThreshold,
    String? notes,
    String? supplierId,
    int? version,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockItem(
      id: id ?? this.id,
      businessOwnerId: businessOwnerId ?? this.businessOwnerId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      packageSize: packageSize ?? this.packageSize,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      notes: notes ?? this.notes,
      supplierId: supplierId ?? this.supplierId,
      version: version ?? this.version,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Input model for creating/updating stock items
class StockItemInput {
  final String name;
  final String unit;
  final double packageSize;
  final double purchasePrice;
  final double lowStockThreshold;
  final String? notes;
  final String? supplierId; // Optional supplier reference (suppliers table - pembekal bahan mentah)

  StockItemInput({
    required this.name,
    required this.unit,
    required this.packageSize,
    required this.purchasePrice,
    this.lowStockThreshold = 5.0,
    this.notes,
    this.supplierId,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'unit': unit,
      'package_size': packageSize,
      'purchase_price': purchasePrice,
      'low_stock_threshold': lowStockThreshold,
      'notes': notes,
      'supplier_id': supplierId,
    };
  }
}

