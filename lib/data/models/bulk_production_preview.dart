/// Bulk Production Preview Models
/// Supports multi-product production planning with aggregated raw material requirements.

class BulkProductionSelection {
  final String productId;
  final int batchCount;

  BulkProductionSelection({
    required this.productId,
    required this.batchCount,
  });
}

class BulkProductionBlocker {
  final String stockItemId;
  final String stockItemName;
  final String stockUnit;
  final double shortageInStockUnit;

  BulkProductionBlocker({
    required this.stockItemId,
    required this.stockItemName,
    required this.stockUnit,
    required this.shortageInStockUnit,
  });
}

class BulkProductMaterialLine {
  final String stockItemId;
  final String stockItemName;
  final double quantityUsageUnit; // in usageUnit (recipe unit)
  final String usageUnit;
  final double quantityStockUnit; // converted to stockUnit
  final String stockUnit;

  BulkProductMaterialLine({
    required this.stockItemId,
    required this.stockItemName,
    required this.quantityUsageUnit,
    required this.usageUnit,
    required this.quantityStockUnit,
    required this.stockUnit,
  });
}

class BulkProductionProductPlan {
  final String productId;
  final String productName;
  final int batchCount;
  final int unitsPerBatch;
  final int totalUnits;
  final double estimatedTotalCost;
  final bool hasActiveRecipe;
  final bool canProduceNow;
  final List<BulkProductionBlocker> blockers;
  final List<BulkProductMaterialLine> materials; // per product, for preview

  BulkProductionProductPlan({
    required this.productId,
    required this.productName,
    required this.batchCount,
    required this.unitsPerBatch,
    required this.totalUnits,
    required this.estimatedTotalCost,
    required this.hasActiveRecipe,
    required this.canProduceNow,
    required this.blockers,
    required this.materials,
  });
}

class BulkMaterialSummary {
  final String stockItemId;
  final String stockItemName;
  final String stockUnit;
  final double currentStock; // in stockUnit
  final double requiredStockQty; // in stockUnit
  final double shortageStockQty; // in stockUnit
  final double packageSize;
  final int packagesNeeded;

  BulkMaterialSummary({
    required this.stockItemId,
    required this.stockItemName,
    required this.stockUnit,
    required this.currentStock,
    required this.requiredStockQty,
    required this.shortageStockQty,
    required this.packageSize,
    required this.packagesNeeded,
  });

  bool get isSufficient => shortageStockQty <= 0;

  double get suggestedBuyQty => packagesNeeded * packageSize;
}

class BulkProductionPlan {
  final List<BulkProductionProductPlan> products;
  final List<BulkMaterialSummary> materials; // aggregated across all selected products

  BulkProductionPlan({
    required this.products,
    required this.materials,
  });

  bool get allMaterialsSufficient => materials.every((m) => m.isSufficient);

  int get producibleCount => products.where((p) => p.canProduceNow).length;

  int get selectedCount => products.length;
}


