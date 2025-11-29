/// Product Model with Recipe & Costing
class Product {
  final String id;
  final String businessOwnerId;
  
  // Product Info
  final String sku;
  final String name;
  final String? categoryId;
  final String? category; // For display
  final String unit;
  final double salePrice;
  final double costPrice;
  final String? description;
  final String? imageUrl;
  
  // Production Costing
  final int unitsPerBatch; // How many units produced per recipe
  final double labourCost; // Labour cost per batch
  final double otherCosts; // Gas, electric, etc per batch
  final double packagingCost; // Packaging cost PER UNIT
  
  // Calculated costs
  final double? materialsCost; // From recipe items
  final double? totalCostPerBatch; // materials + labour + other + (packaging * units)
  final double? costPerUnit; // totalCostPerBatch / unitsPerBatch
  
  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.businessOwnerId,
    required this.sku,
    required this.name,
    this.categoryId,
    this.category,
    required this.unit,
    required this.salePrice,
    required this.costPrice,
    this.description,
    this.imageUrl,
    this.unitsPerBatch = 1,
    this.labourCost = 0.0,
    this.otherCosts = 0.0,
    this.packagingCost = 0.0,
    this.materialsCost,
    this.totalCostPerBatch,
    this.costPerUnit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      category: json['category'] as String?,
      unit: json['unit'] as String,
      salePrice: (json['sale_price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      unitsPerBatch: (json['units_per_batch'] as num?)?.toInt() ?? 1,
      labourCost: (json['labour_cost'] as num?)?.toDouble() ?? 0.0,
      otherCosts: (json['other_costs'] as num?)?.toDouble() ?? 0.0,
      packagingCost: (json['packaging_cost'] as num?)?.toDouble() ?? 0.0,
      materialsCost: (json['materials_cost'] as num?)?.toDouble(),
      totalCostPerBatch: (json['total_cost_per_batch'] as num?)?.toDouble(),
      costPerUnit: (json['cost_per_unit'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'sku': sku,
      'name': name,
      'category_id': categoryId,
      'unit': unit,
      'sale_price': salePrice,
      'cost_price': costPrice,
      'description': description,
      'image_url': imageUrl,
      'units_per_batch': unitsPerBatch,
      'labour_cost': labourCost,
      'other_costs': otherCosts,
      'packaging_cost': packagingCost,
      'materials_cost': materialsCost,
      'total_cost_per_batch': totalCostPerBatch,
      'cost_per_unit': costPerUnit,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

