/// Supplier Model - Pembekal bahan/ingredients untuk production
/// 
/// Note: Different from Vendor (consignee)
/// - Supplier = Pembekal bahan untuk user buat produk (purchase relationship)
/// - Vendor = Consignee yang jual produk user (consignment relationship)
/// 
/// Uses suppliers table (separate from vendors table)
class Supplier {
  final String id;
  final String businessOwnerId;
  final String name;
  final String? phone;
  final String? email;
  final String? address; // Stored as JSONB in DB, but we'll use as string
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    required this.id,
    required this.businessOwnerId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    // Handle address - can be JSONB or string
    String? address;
    if (json['address'] != null) {
      if (json['address'] is String) {
        address = json['address'] as String;
      } else if (json['address'] is Map) {
        // If JSONB, try to extract address string
        final addrMap = json['address'] as Map<String, dynamic>;
        address = addrMap['full'] as String? ?? 
                  addrMap['address'] as String? ??
                  addrMap.toString();
      }
    }

    return Supplier(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: address,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address, // Store as TEXT
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'business_owner_id': businessOwnerId,
      'name': name,
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'email': email?.trim().isEmpty == true ? null : email?.trim(),
      'address': address?.trim().isEmpty == true ? null : address?.trim()
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{};
    if (name.isNotEmpty) json['name'] = name;
    json['phone'] = phone?.trim().isEmpty == true ? null : phone?.trim();
    json['email'] = email?.trim().isEmpty == true ? null : email?.trim();
    json['address'] = address?.trim().isEmpty == true ? null : address?.trim();
    json['updated_at'] = DateTime.now().toIso8601String();
    return json;
  }
}

