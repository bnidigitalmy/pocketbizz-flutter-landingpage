/// Top Vendor Model for Reports
class TopVendor {
  final String vendorId;
  final String vendorName;
  final int totalDeliveries;
  final double totalAmount;

  TopVendor({
    required this.vendorId,
    required this.vendorName,
    required this.totalDeliveries,
    required this.totalAmount,
  });

  factory TopVendor.fromJson(Map<String, dynamic> json) {
    return TopVendor(
      vendorId: json['vendorId'] as String? ?? json['vendor_id'] as String,
      vendorName:
          json['vendorName'] as String? ?? json['vendor_name'] as String,
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ??
          (json['total_deliveries'] as num?)?.toInt() ??
          0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'vendorId': vendorId,
        'vendorName': vendorName,
        'totalDeliveries': totalDeliveries,
        'totalAmount': totalAmount,
      };
}

