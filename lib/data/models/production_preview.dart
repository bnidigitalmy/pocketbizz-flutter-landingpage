import 'package:flutter/material.dart';

/// Material Preview - Shows what materials are needed and stock status
class MaterialPreview {
  final String stockItemId;
  final String stockItemName;
  final double quantityNeeded;
  final String usageUnit;
  final double currentStock;
  final String stockUnit;
  final bool isSufficient;
  final double shortage;
  final double convertedQuantity; // Quantity converted to stock unit
  final double packageSize; // Package size for purchase suggestion
  final int packagesNeeded; // Number of pek/pcs needed (rounded up)

  MaterialPreview({
    required this.stockItemId,
    required this.stockItemName,
    required this.quantityNeeded,
    required this.usageUnit,
    required this.currentStock,
    required this.stockUnit,
    required this.isSufficient,
    required this.shortage,
    required this.convertedQuantity,
    required this.packageSize,
    required this.packagesNeeded,
  });

  factory MaterialPreview.fromJson(Map<String, dynamic> json) {
    final packageSize = (json['packageSize'] as num?)?.toDouble() ?? 1.0;
    final shortage = (json['shortage'] as num).toDouble();
    final packagesNeeded = packageSize > 0 ? (shortage / packageSize).ceil() : 0;
    
    return MaterialPreview(
      stockItemId: json['stockItemId'],
      stockItemName: json['stockItemName'],
      quantityNeeded: (json['quantityNeeded'] as num).toDouble(),
      usageUnit: json['usageUnit'],
      currentStock: (json['currentStock'] as num).toDouble(),
      stockUnit: json['stockUnit'],
      isSufficient: json['isSufficient'] ?? false,
      shortage: shortage,
      convertedQuantity: (json['convertedQuantity'] as num).toDouble(),
      packageSize: packageSize,
      packagesNeeded: packagesNeeded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockItemId': stockItemId,
      'stockItemName': stockItemName,
      'quantityNeeded': quantityNeeded,
      'usageUnit': usageUnit,
      'currentStock': currentStock,
      'stockUnit': stockUnit,
      'isSufficient': isSufficient,
      'shortage': shortage,
      'convertedQuantity': convertedQuantity,
      'packageSize': packageSize,
      'packagesNeeded': packagesNeeded,
    };
  }
}

/// Production Plan - Complete plan with materials needed
class ProductionPlan {
  final ProductInfo product;
  final int quantity; // Number of batches
  final int totalUnits; // Total units produced
  final List<MaterialPreview> materialsNeeded;
  final bool allStockSufficient;
  final double totalProductionCost;

  ProductionPlan({
    required this.product,
    required this.quantity,
    required this.totalUnits,
    required this.materialsNeeded,
    required this.allStockSufficient,
    required this.totalProductionCost,
  });

  factory ProductionPlan.fromJson(Map<String, dynamic> json) {
    return ProductionPlan(
      product: ProductInfo.fromJson(json['product']),
      quantity: json['quantity'] ?? 1,
      totalUnits: json['totalUnits'] ?? 0,
      materialsNeeded: (json['materialsNeeded'] as List)
          .map((m) => MaterialPreview.fromJson(m))
          .toList(),
      allStockSufficient: json['allStockSufficient'] ?? false,
      totalProductionCost: (json['totalProductionCost'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'totalUnits': totalUnits,
      'materialsNeeded': materialsNeeded.map((m) => m.toJson()).toList(),
      'allStockSufficient': allStockSufficient,
      'totalProductionCost': totalProductionCost,
    };
  }
}

/// Product Info for production plan
class ProductInfo {
  final String id;
  final String name;
  final int unitsPerBatch;
  final String totalCostPerBatch;

  ProductInfo({
    required this.id,
    required this.name,
    required this.unitsPerBatch,
    required this.totalCostPerBatch,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    return ProductInfo(
      id: json['id'],
      name: json['name'],
      unitsPerBatch: json['unitsPerBatch'] ?? 1,
      totalCostPerBatch: json['totalCostPerBatch'] ?? '0.00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unitsPerBatch': unitsPerBatch,
      'totalCostPerBatch': totalCostPerBatch,
    };
  }
}

