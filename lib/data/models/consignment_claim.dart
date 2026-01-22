/// Consignment Claim Model - New system based on deliveries
class ConsignmentClaim {
  final String id;
  final String businessOwnerId;
  final String vendorId;
  final String? vendorName;
  final String claimNumber;
  final DateTime claimDate;
  final ClaimStatus status;
  final double grossAmount;
  final double commissionRate;
  final double commissionAmount;
  final double netAmount;
  final double paidAmount;
  final double balanceAmount;
  final String? notes;
  final DateTime? dueDate;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? settledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ConsignmentClaimItem>? items;

  ConsignmentClaim({
    required this.id,
    required this.businessOwnerId,
    required this.vendorId,
    this.vendorName,
    required this.claimNumber,
    required this.claimDate,
    required this.status,
    required this.grossAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.balanceAmount,
    this.notes,
    this.dueDate,
    this.submittedAt,
    this.approvedAt,
    this.settledAt,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  factory ConsignmentClaim.fromJson(Map<String, dynamic> json) {
    return ConsignmentClaim(
      id: json['id'] as String,
      businessOwnerId: json['businessOwnerId'] as String? ??
          json['business_owner_id'] as String,
      vendorId: json['vendorId'] as String? ?? json['vendor_id'] as String,
      vendorName:
          json['vendorName'] as String? ?? json['vendor_name'] as String?,
      claimNumber:
          json['claimNumber'] as String? ?? json['claim_number'] as String,
      claimDate: DateTime.parse(
          json['claimDate'] as String? ?? json['claim_date'] as String),
      status: _parseStatus(json['status'] as String? ?? 'draft'),
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ??
          (json['gross_amount'] as num?)?.toDouble() ??
          0.0,
      commissionRate: (json['commissionRate'] as num?)?.toDouble() ??
          (json['commission_rate'] as num?)?.toDouble() ??
          0.0,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ??
          (json['commission_amount'] as num?)?.toDouble() ??
          0.0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ??
          (json['net_amount'] as num?)?.toDouble() ??
          0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ??
          (json['paid_amount'] as num?)?.toDouble() ??
          0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ??
          (json['balance_amount'] as num?)?.toDouble() ??
          0.0,
      notes: json['notes'] as String?,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : json['due_date'] != null
              ? DateTime.parse(json['due_date'] as String)
              : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : json['submitted_at'] != null
              ? DateTime.parse(json['submitted_at'] as String)
              : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : json['approved_at'] != null
              ? DateTime.parse(json['approved_at'] as String)
              : null,
      settledAt: json['settledAt'] != null
          ? DateTime.parse(json['settledAt'] as String)
          : json['settled_at'] != null
              ? DateTime.parse(json['settled_at'] as String)
              : null,
      createdAt: DateTime.parse(
          json['createdAt'] as String? ?? json['created_at'] as String),
      updatedAt: DateTime.parse(
          json['updatedAt'] as String? ?? json['updated_at'] as String),
      items: json['items'] != null
          ? (json['items'] as List<dynamic>)
              .map((item) =>
                  ConsignmentClaimItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'businessOwnerId': businessOwnerId,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'claimNumber': claimNumber,
      'claimDate': claimDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'grossAmount': grossAmount,
      'commissionRate': commissionRate,
      'commissionAmount': commissionAmount,
      'netAmount': netAmount,
      'paidAmount': paidAmount,
      'balanceAmount': balanceAmount,
      'notes': notes,
      'dueDate': dueDate?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'settledAt': settledAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'items': items?.map((item) => item.toJson()).toList(),
    };
  }

  static ClaimStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return ClaimStatus.draft;
      case 'submitted':
        return ClaimStatus.submitted;
      case 'approved':
        return ClaimStatus.approved;
      case 'rejected':
        return ClaimStatus.rejected;
      case 'settled':
        return ClaimStatus.settled;
      default:
        return ClaimStatus.draft;
    }
  }
}

enum ClaimStatus {
  draft,
  submitted,
  approved,
  rejected,
  settled,
}

/// Consignment Claim Item Model
class ConsignmentClaimItem {
  final String id;
  final String claimId;
  final String deliveryId;
  final String deliveryItemId;
  final double quantityDelivered;
  final double quantitySold;
  final double quantityUnsold;
  final double quantityExpired;
  final double quantityDamaged;
  final double unitPrice;
  final double grossAmount;
  final double commissionRate;
  final double commissionAmount;
  final double netAmount;
  final double paidAmount;
  final double balanceAmount;
  final String carryForwardStatus; // 'none', 'carry_forward', 'loss'
  final DateTime createdAt;
  final DateTime updatedAt;
  // Denormalized fields
  final String? productId;
  final String? productName;
  final String? deliveryNumber;
  final bool isCarryForward; // Whether this item came from carry forward

  ConsignmentClaimItem({
    required this.id,
    required this.claimId,
    required this.deliveryId,
    required this.deliveryItemId,
    required this.quantityDelivered,
    required this.quantitySold,
    required this.quantityUnsold,
    required this.quantityExpired,
    required this.quantityDamaged,
    required this.unitPrice,
    required this.grossAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.carryForwardStatus,
    required this.createdAt,
    required this.updatedAt,
    this.productId,
    this.productName,
    this.deliveryNumber,
    this.isCarryForward = false,
  });

  factory ConsignmentClaimItem.fromJson(Map<String, dynamic> json) {
    return ConsignmentClaimItem(
      id: json['id'] as String,
      claimId: json['claimId'] as String? ?? json['claim_id'] as String,
      deliveryId:
          json['deliveryId'] as String? ?? json['delivery_id'] as String,
      deliveryItemId: json['deliveryItemId'] as String? ??
          json['delivery_item_id'] as String,
      quantityDelivered: (json['quantityDelivered'] as num?)?.toDouble() ??
          (json['quantity_delivered'] as num?)?.toDouble() ??
          0.0,
      quantitySold: (json['quantitySold'] as num?)?.toDouble() ??
          (json['quantity_sold'] as num?)?.toDouble() ??
          0.0,
      quantityUnsold: (json['quantityUnsold'] as num?)?.toDouble() ??
          (json['quantity_unsold'] as num?)?.toDouble() ??
          0.0,
      quantityExpired: (json['quantityExpired'] as num?)?.toDouble() ??
          (json['quantity_expired'] as num?)?.toDouble() ??
          0.0,
      quantityDamaged: (json['quantityDamaged'] as num?)?.toDouble() ??
          (json['quantity_damaged'] as num?)?.toDouble() ??
          0.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ??
          (json['unit_price'] as num?)?.toDouble() ??
          0.0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ??
          (json['gross_amount'] as num?)?.toDouble() ??
          0.0,
      commissionRate: (json['commissionRate'] as num?)?.toDouble() ??
          (json['commission_rate'] as num?)?.toDouble() ??
          0.0,
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ??
          (json['commission_amount'] as num?)?.toDouble() ??
          0.0,
      netAmount: (json['netAmount'] as num?)?.toDouble() ??
          (json['net_amount'] as num?)?.toDouble() ??
          0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ??
          (json['paid_amount'] as num?)?.toDouble() ??
          0.0,
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ??
          (json['balance_amount'] as num?)?.toDouble() ??
          0.0,
      carryForwardStatus: (json['carryForwardStatus'] as String?) ??
          (json['carry_forward_status'] as String?) ??
          'none',
      createdAt: DateTime.parse(
          json['createdAt'] as String? ?? json['created_at'] as String),
      updatedAt: DateTime.parse(
          json['updatedAt'] as String? ?? json['updated_at'] as String),
      productId: json['productId'] as String? ?? json['product_id'] as String?,
      productName:
          json['productName'] as String? ?? json['product_name'] as String?,
      deliveryNumber: json['deliveryNumber'] as String? ??
          json['delivery_number'] as String?,
      isCarryForward: (json['isCarryForward'] as bool?) ??
          (json['is_carry_forward'] as bool?) ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'claimId': claimId,
      'deliveryId': deliveryId,
      'deliveryItemId': deliveryItemId,
      'quantityDelivered': quantityDelivered,
      'quantitySold': quantitySold,
      'quantityUnsold': quantityUnsold,
      'quantityExpired': quantityExpired,
      'quantityDamaged': quantityDamaged,
      'unitPrice': unitPrice,
      'grossAmount': grossAmount,
      'commissionRate': commissionRate,
      'commissionAmount': commissionAmount,
      'netAmount': netAmount,
      'paidAmount': paidAmount,
      'balanceAmount': balanceAmount,
      'carryForwardStatus': carryForwardStatus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'productId': productId,
      'productName': productName,
      'deliveryNumber': deliveryNumber,
      'isCarryForward': isCarryForward,
    };
  }
}
