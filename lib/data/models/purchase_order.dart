import 'package:flutter/material.dart';

/// Purchase Order Item Model
class PurchaseOrderItem {
  final String id;
  final String poId;
  final String? stockItemId;
  final String itemName;
  final double quantity;
  final String unit;
  final double? estimatedPrice;
  final double? actualPrice;
  final double? packageSize; // Package size in base unit (for calculating packages needed)
  final String? notes;

  PurchaseOrderItem({
    required this.id,
    required this.poId,
    this.stockItemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    this.estimatedPrice,
    this.actualPrice,
    this.packageSize,
    this.notes,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as String,
      poId: json['po_id'] as String,
      stockItemId: json['stock_item_id'] as String?,
      itemName: json['item_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      estimatedPrice: (json['estimated_price'] as num?)?.toDouble(),
      actualPrice: (json['actual_price'] as num?)?.toDouble(),
      packageSize: (json['package_size'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'po_id': poId,
      'stock_item_id': stockItemId,
      'item_name': itemName,
      'quantity': quantity,
      'unit': unit,
      'estimated_price': estimatedPrice,
      'actual_price': actualPrice,
      'package_size': packageSize,
      'notes': notes,
    };
  }
  
  /// Calculate item total correctly using package size
  /// Returns: packages_needed * price
  double calculateTotal() {
    if (estimatedPrice == null || estimatedPrice == 0) return 0.0;
    
    final price = actualPrice ?? estimatedPrice ?? 0.0;
    if (price == 0) return 0.0;
    
    // If packageSize is available, calculate packages needed
    if (packageSize != null && packageSize! > 0) {
      final packagesNeeded = (quantity / packageSize!).ceil();
      return packagesNeeded * price;
    }
    
    // Fallback: assume quantity is already in packages (for backward compatibility)
    return quantity * price;
  }
  
  /// Get packages needed (rounded up)
  int getPackagesNeeded() {
    if (packageSize != null && packageSize! > 0) {
      return (quantity / packageSize!).ceil();
    }
    return 1; // Default to 1 if no package size
  }
  
  /// Format quantity with package count for display
  /// Returns: "1410.0 gram (3 pek/pcs)" or just "1410.0 gram" if no package size
  String formatQuantityWithPackages() {
    final baseQuantity = '${quantity.toStringAsFixed(1)} $unit';
    
    if (packageSize != null && packageSize! > 0) {
      final packagesNeeded = getPackagesNeeded();
      return '$baseQuantity ($packagesNeeded pek/pcs)';
    }
    
    return baseQuantity;
  }
}

/// Purchase Order Model
class PurchaseOrder {
  final String id;
  final String businessOwnerId;
  final String poNumber;
  final String? supplierId;
  final String supplierName;
  final String? supplierPhone;
  final String? supplierEmail;
  final String? supplierAddress;
  final String? deliveryAddress;
  final double totalAmount;
  final String status; // draft, sent, received, cancelled
  final String? notes;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? receivedAt;
  final String? expenseId;
  final List<PurchaseOrderItem> items;
  
  // Additional fields (optional)
  final String? expectedDeliveryDate;
  final String? paymentTerms;
  final String? paymentMethod;
  final String? requestedBy;
  final double? discount;
  final double? tax;
  final double? shippingCharges;

  PurchaseOrder({
    required this.id,
    required this.businessOwnerId,
    required this.poNumber,
    this.supplierId,
    required this.supplierName,
    this.supplierPhone,
    this.supplierEmail,
    this.supplierAddress,
    this.deliveryAddress,
    required this.totalAmount,
    required this.status,
    this.notes,
    required this.createdAt,
    this.sentAt,
    this.receivedAt,
    this.expenseId,
    required this.items,
    this.expectedDeliveryDate,
    this.paymentTerms,
    this.paymentMethod,
    this.requestedBy,
    this.discount,
    this.tax,
    this.shippingCharges,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    // Handle items - can be array or nested
    List<PurchaseOrderItem> itemsList = [];
    if (json['items'] != null) {
      if (json['items'] is List) {
        itemsList = (json['items'] as List)
            .map((item) => PurchaseOrderItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    return PurchaseOrder(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      poNumber: json['po_number'] as String,
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String,
      supplierPhone: json['supplier_phone'] as String?,
      supplierEmail: json['supplier_email'] as String?,
      supplierAddress: json['supplier_address'] as String?,
      deliveryAddress: json['delivery_address'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      sentAt: json['sent_at'] != null 
          ? DateTime.parse(json['sent_at'] as String) 
          : null,
      receivedAt: json['received_at'] != null 
          ? DateTime.parse(json['received_at'] as String) 
          : null,
      expenseId: json['expense_id'] as String?,
      items: itemsList,
      expectedDeliveryDate: json['expected_delivery_date'] as String?,
      paymentTerms: json['payment_terms'] as String?,
      paymentMethod: json['payment_method'] as String?,
      requestedBy: json['requested_by'] as String?,
      discount: (json['discount'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      shippingCharges: (json['shipping_charges'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'po_number': poNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'supplier_phone': supplierPhone,
      'supplier_email': supplierEmail,
      'supplier_address': supplierAddress,
      'delivery_address': deliveryAddress,
      'total_amount': totalAmount,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'received_at': receivedAt?.toIso8601String(),
      'expense_id': expenseId,
      'items': items.map((item) => item.toJson()).toList(),
      'expected_delivery_date': expectedDeliveryDate,
      'payment_terms': paymentTerms,
      'payment_method': paymentMethod,
      'requested_by': requestedBy,
      'discount': discount,
      'tax': tax,
      'shipping_charges': shippingCharges,
    };
  }

  /// Get status badge color
  static Color getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.amber;
      case 'sent':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon
  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'draft':
        return Icons.access_time;
      case 'sent':
        return Icons.send;
      case 'received':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}



