/// Recipe Item Model
/// Links a RECIPE to a stock item with quantity needed
/// ✅ NOW CORRECTLY LINKS TO RECIPES TABLE!
class RecipeItem {
  final String id;
  final String businessOwnerId;
  final String recipeId;  // ✅ Links to recipes table (not products!)
  final String stockItemId;
  final double quantityNeeded;
  final String usageUnit;
  final double costPerUnit;  // Cost per base unit of stock item (stock_items.unit)
  final double totalCost;     // (quantityNeeded converted to stock unit) * costPerUnit
  final int position;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // For joins - populated when loaded with relations
  String? stockItemName;
  String? recipeName;

  RecipeItem({
    required this.id,
    required this.businessOwnerId,
    required this.recipeId,
    required this.stockItemId,
    required this.quantityNeeded,
    required this.usageUnit,
    this.costPerUnit = 0,
    this.totalCost = 0,
    this.position = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.stockItemName,
    this.recipeName,
  });

  factory RecipeItem.fromJson(Map<String, dynamic> json) {
    return RecipeItem(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      recipeId: json['recipe_id'] as String,
      stockItemId: json['stock_item_id'] as String,
      quantityNeeded: (json['quantity_needed'] as num).toDouble(),
      usageUnit: json['usage_unit'] as String,
      costPerUnit: (json['cost_per_unit'] as num?)?.toDouble() ?? 0,
      totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
      position: json['position'] as int? ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      stockItemName: json['stock_item_name'] as String?,
      recipeName: json['recipe_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'recipe_id': recipeId,
      'stock_item_id': stockItemId,
      'quantity_needed': quantityNeeded,
      'usage_unit': usageUnit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'position': position,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'business_owner_id': businessOwnerId,
      'recipe_id': recipeId,
      'stock_item_id': stockItemId,
      'quantity_needed': quantityNeeded,
      'usage_unit': usageUnit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'position': position,
      'notes': notes,
    };
  }
}

/// Input model for creating/updating recipe items
class RecipeItemInput {
  final String recipeId;  // ✅ Changed from productId
  final String stockItemId;
  final double quantityNeeded;
  final String usageUnit;
  final double costPerUnit;
  final double totalCost;
  final int position;
  final String? notes;

  RecipeItemInput({
    required this.recipeId,
    required this.stockItemId,
    required this.quantityNeeded,
    required this.usageUnit,
    this.costPerUnit = 0,
    this.totalCost = 0,
    this.position = 0,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'recipe_id': recipeId,
      'stock_item_id': stockItemId,
      'quantity_needed': quantityNeeded,
      'usage_unit': usageUnit,
      'cost_per_unit': costPerUnit,
      'total_cost': totalCost,
      'position': position,
      'notes': notes,
    };
  }
}
