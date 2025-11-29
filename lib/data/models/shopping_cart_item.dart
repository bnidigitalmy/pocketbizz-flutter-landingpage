import 'package:flutter/material.dart';

/// Shopping Cart Item Model
/// Represents an item in the shopping cart/purchase list
class ShoppingCartItem {
  final String id;
  final String businessOwnerId;
  final String stockItemId;
  final double shortageQty;
  final String? notes;
  final String priority; // low, normal, high, urgent
  final String? preferredSupplierId;
  final String status; // pending, ordered, received, cancelled
  final DateTime? orderedAt;
  final DateTime? receivedAt;
  final String? purchaseOrderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Join data (when fetched with stock item)
  String? stockItemName;
  String? stockItemUnit;
  double? stockItemPackageSize;
  double? stockItemPurchasePrice;
  double? stockItemCurrentQuantity;
  double? stockItemLowStockThreshold;

  ShoppingCartItem({
    required this.id,
    required this.businessOwnerId,
    required this.stockItemId,
    required this.shortageQty,
    this.notes,
    this.priority = 'normal',
    this.preferredSupplierId,
    this.status = 'pending',
    this.orderedAt,
    this.receivedAt,
    this.purchaseOrderId,
    required this.createdAt,
    required this.updatedAt,
    // Join data
    this.stockItemName,
    this.stockItemUnit,
    this.stockItemPackageSize,
    this.stockItemPurchasePrice,
    this.stockItemCurrentQuantity,
    this.stockItemLowStockThreshold,
  });

  factory ShoppingCartItem.fromJson(Map<String, dynamic> json) {
    // Handle joined stock_items data
    final stockItems = json['stock_items'];
    
    return ShoppingCartItem(
      id: json['id'],
      businessOwnerId: json['business_owner_id'],
      stockItemId: json['stock_item_id'],
      shortageQty: (json['shortage_qty'] as num).toDouble(),
      notes: json['notes'],
      priority: json['priority'] ?? 'normal',
      preferredSupplierId: json['preferred_supplier_id'],
      status: json['status'] ?? 'pending',
      orderedAt: json['ordered_at'] != null 
          ? DateTime.parse(json['ordered_at']) 
          : null,
      receivedAt: json['received_at'] != null 
          ? DateTime.parse(json['received_at']) 
          : null,
      purchaseOrderId: json['purchase_order_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      // Join data
      stockItemName: stockItems != null ? stockItems['name'] : null,
      stockItemUnit: stockItems != null ? stockItems['unit'] : null,
      stockItemPackageSize: stockItems != null 
          ? (stockItems['package_size'] as num?)?.toDouble() 
          : null,
      stockItemPurchasePrice: stockItems != null 
          ? (stockItems['purchase_price'] as num?)?.toDouble() 
          : null,
      stockItemCurrentQuantity: stockItems != null 
          ? (stockItems['current_quantity'] as num?)?.toDouble() 
          : null,
      stockItemLowStockThreshold: stockItems != null 
          ? (stockItems['low_stock_threshold'] as num?)?.toDouble() 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'stock_item_id': stockItemId,
      'shortage_qty': shortageQty,
      'notes': notes,
      'priority': priority,
      'preferred_supplier_id': preferredSupplierId,
      'status': status,
      'ordered_at': orderedAt?.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
      'purchase_order_id': purchaseOrderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Calculate estimated cost for this item
  double calculateEstimatedCost() {
    if (stockItemPurchasePrice == null || stockItemPackageSize == null) {
      return 0.0;
    }

    // Calculate how many packages needed
    final packagesNeeded = (shortageQty / stockItemPackageSize!).ceil();
    return packagesNeeded * stockItemPurchasePrice!;
  }

  /// Get priority color
  static getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFEF4444); // Red
      case 'high':
        return const Color(0xFFF97316); // Orange
      case 'normal':
        return const Color(0xFF3B82F6); // Blue
      case 'low':
        return const Color(0xFF6B7280); // Grey
      default:
        return const Color(0xFF3B82F6);
    }
  }
}

