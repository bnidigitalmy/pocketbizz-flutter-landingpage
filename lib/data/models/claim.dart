/// Claim Model - Represents vendor claim summary
class Claim {
  final String vendorId;
  final String vendorName;
  final int totalDeliveries;
  final double totalAmount;
  final double pendingAmount;
  final double settledAmount;
  final double partialAmount;
  final int daysOverdue;

  Claim({
    required this.vendorId,
    required this.vendorName,
    required this.totalDeliveries,
    required this.totalAmount,
    required this.pendingAmount,
    required this.settledAmount,
    required this.partialAmount,
    this.daysOverdue = 0,
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      vendorId: json['vendor_id'] as String? ?? json['vendorId'] as String,
      vendorName: json['vendor_name'] as String? ?? json['vendorName'] as String,
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 
                      (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 
                  (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 
                    (json['pendingAmount'] as num?)?.toDouble() ?? 0.0,
      settledAmount: (json['settled_amount'] as num?)?.toDouble() ?? 
                    (json['settledAmount'] as num?)?.toDouble() ?? 0.0,
      partialAmount: (json['partial_amount'] as num?)?.toDouble() ?? 
                     (json['partialAmount'] as num?)?.toDouble() ?? 0.0,
      daysOverdue: (json['days_overdue'] as num?)?.toInt() ?? 
                   (json['daysOverdue'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendor_id': vendorId,
      'vendor_name': vendorName,
      'total_deliveries': totalDeliveries,
      'total_amount': totalAmount,
      'pending_amount': pendingAmount,
      'settled_amount': settledAmount,
      'partial_amount': partialAmount,
      'days_overdue': daysOverdue,
    };
  }
}

/// Claim Details Model - Detailed view with deliveries
class ClaimDetails {
  final String vendorId;
  final String vendorName;
  final int totalDeliveries;
  final double totalAmount;
  final double pendingAmount;
  final double settledAmount;
  final double partialAmount;
  final List<DeliveryWithClaimData> deliveries;

  ClaimDetails({
    required this.vendorId,
    required this.vendorName,
    required this.totalDeliveries,
    required this.totalAmount,
    required this.pendingAmount,
    required this.settledAmount,
    required this.partialAmount,
    required this.deliveries,
  });

  factory ClaimDetails.fromJson(Map<String, dynamic> json) {
    return ClaimDetails(
      vendorId: json['vendor_id'] as String? ?? json['vendorId'] as String,
      vendorName: json['vendor_name'] as String? ?? json['vendorName'] as String,
      totalDeliveries: (json['total_deliveries'] as num?)?.toInt() ?? 
                      (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 
                  (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 
                    (json['pendingAmount'] as num?)?.toDouble() ?? 0.0,
      settledAmount: (json['settled_amount'] as num?)?.toDouble() ?? 
                    (json['settledAmount'] as num?)?.toDouble() ?? 0.0,
      partialAmount: (json['partial_amount'] as num?)?.toDouble() ?? 
                     (json['partialAmount'] as num?)?.toDouble() ?? 0.0,
      deliveries: (json['deliveries'] as List<dynamic>?)
              ?.map((d) => DeliveryWithClaimData.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Delivery with Claim Data - Extended delivery with commission calculations
class DeliveryWithClaimData {
  final String id;
  final String vendorId;
  final String vendorName;
  final DateTime deliveryDate;
  final String status;
  final String? paymentStatus;
  final double totalAmount;
  final String? invoiceNumber;
  final List<DeliveryItemWithClaimData> items;
  
  // Calculated claim amounts
  final double? claimableAmount;
  final double? grossAmount;
  final double? rejectedAmount;
  final double? commissionAmount;
  final double? netAmount;

  DeliveryWithClaimData({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.deliveryDate,
    required this.status,
    this.paymentStatus,
    required this.totalAmount,
    this.invoiceNumber,
    required this.items,
    this.claimableAmount,
    this.grossAmount,
    this.rejectedAmount,
    this.commissionAmount,
    this.netAmount,
  });

  factory DeliveryWithClaimData.fromJson(Map<String, dynamic> json) {
    return DeliveryWithClaimData(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String? ?? json['vendorId'] as String,
      vendorName: json['vendor_name'] as String? ?? json['vendorName'] as String,
      deliveryDate: json['delivery_date'] is String
          ? DateTime.parse(json['delivery_date'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'delivered',
      paymentStatus: json['payment_status'] as String? ?? json['paymentStatus'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 
                  (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      invoiceNumber: json['invoice_number'] as String? ?? json['invoiceNumber'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => DeliveryItemWithClaimData.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      claimableAmount: (json['claimable_amount'] as num?)?.toDouble(),
      grossAmount: (json['gross_amount'] as num?)?.toDouble(),
      rejectedAmount: (json['rejected_amount'] as num?)?.toDouble(),
      commissionAmount: (json['commission_amount'] as num?)?.toDouble(),
      netAmount: (json['net_amount'] as num?)?.toDouble(),
    );
  }
}

/// Delivery Item with Claim Data - Extended item with commission calculations
class DeliveryItemWithClaimData {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final double? retailPrice;
  final double rejectedQty;
  final String? rejectionReason;
  
  // Calculated claim amounts
  final double? itemGross;
  final double? itemRejected;
  final double? itemNet;
  final double? itemCommission;
  final double? itemClaimable;

  DeliveryItemWithClaimData({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.retailPrice,
    this.rejectedQty = 0.0,
    this.rejectionReason,
    this.itemGross,
    this.itemRejected,
    this.itemNet,
    this.itemCommission,
    this.itemClaimable,
  });

  factory DeliveryItemWithClaimData.fromJson(Map<String, dynamic> json) {
    return DeliveryItemWithClaimData(
      id: json['id'] as String? ?? '',
      productId: json['product_id'] as String? ?? json['productId'] as String? ?? '',
      productName: json['product_name'] as String? ?? json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 
                (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 
                 (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      retailPrice: (json['retail_price'] as num?)?.toDouble(),
      rejectedQty: (json['rejected_qty'] as num?)?.toDouble() ?? 
                   (json['rejectedQty'] as num?)?.toDouble() ?? 0.0,
      rejectionReason: json['rejection_reason'] as String? ?? 
                       json['rejectionReason'] as String?,
      itemGross: (json['item_gross'] as num?)?.toDouble(),
      itemRejected: (json['item_rejected'] as num?)?.toDouble(),
      itemNet: (json['item_net'] as num?)?.toDouble(),
      itemCommission: (json['item_commission'] as num?)?.toDouble(),
      itemClaimable: (json['item_claimable'] as num?)?.toDouble(),
    );
  }
}

