/// Delivery Model - Represents a delivery to vendor
class Delivery {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final String vendorName;
  final DateTime deliveryDate;
  final String status; // delivered, pending, claimed, rejected
  final String? paymentStatus; // pending, partial, settled
  final double totalAmount;
  final String? invoiceNumber;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DeliveryItem> items;

  Delivery({
    required this.id,
    required this.businessOwnerId,
    required this.vendorId,
    required this.vendorName,
    required this.deliveryDate,
    required this.status,
    this.paymentStatus,
    required this.totalAmount,
    this.invoiceNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    // Handle items - could be from nested query or direct array
    List<DeliveryItem> items = [];
    if (json['items'] != null) {
      if (json['items'] is List) {
        items = (json['items'] as List).map((item) {
          if (item is Map<String, dynamic>) {
            return DeliveryItem.fromJson(item);
          }
          return DeliveryItem.fromJson(item as Map<String, dynamic>);
        }).toList();
      }
    }

    return Delivery(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      vendorId: json['vendor_id'] as String,
      vendorName: json['vendor_name'] as String? ?? '',
      deliveryDate: json['delivery_date'] is String
          ? DateTime.parse(json['delivery_date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'delivered',
      paymentStatus: json['payment_status'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      invoiceNumber: json['invoice_number'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] is String
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      items: items,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'delivery_date': deliveryDate.toIso8601String().split('T')[0],
      'status': status,
      'payment_status': paymentStatus,
      'total_amount': totalAmount,
      'invoice_number': invoiceNumber,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

/// Delivery Item Model
class DeliveryItem {
  final String id;
  final String deliveryId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double? retailPrice;
  final double rejectedQty;
  final String? rejectionReason;
  final DateTime createdAt;

  DeliveryItem({
    required this.id,
    required this.deliveryId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.retailPrice,
    this.rejectedQty = 0.0,
    this.rejectionReason,
    required this.createdAt,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      id: json['id'] as String? ?? '',
      deliveryId: json['delivery_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 
          ((json['quantity'] as num?)?.toDouble() ?? 0.0) * 
          ((json['unit_price'] as num?)?.toDouble() ?? 0.0),
      retailPrice: (json['retail_price'] as num?)?.toDouble(),
      rejectedQty: (json['rejected_qty'] as num?)?.toDouble() ?? 0.0,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: json['created_at'] != null && json['created_at'] is String
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_id': deliveryId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'retail_price': retailPrice,
      'rejected_qty': rejectedQty,
      'rejection_reason': rejectionReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

