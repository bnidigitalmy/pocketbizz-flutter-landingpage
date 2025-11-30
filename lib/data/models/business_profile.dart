/// Business Profile Model
/// Stores business information for invoices and statements
class BusinessProfile {
  final String id;
  final String businessOwnerId;
  final String businessName;
  final String? tagline;
  final String? registrationNumber;
  final String? address;
  final String? phone;
  final String? email;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? paymentQrCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  BusinessProfile({
    required this.id,
    required this.businessOwnerId,
    required this.businessName,
    this.tagline,
    this.registrationNumber,
    this.address,
    this.phone,
    this.email,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.paymentQrCode,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      id: json['id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      businessName: json['business_name'] as String,
      tagline: json['tagline'] as String?,
      registrationNumber: json['registration_number'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      accountName: json['account_name'] as String?,
      paymentQrCode: json['payment_qr_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'business_name': businessName,
      'tagline': tagline,
      'registration_number': registrationNumber,
      'address': address,
      'phone': phone,
      'email': email,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'payment_qr_code': paymentQrCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'business_owner_id': businessOwnerId,
      'business_name': businessName,
      'tagline': tagline,
      'registration_number': registrationNumber,
      'address': address,
      'phone': phone,
      'email': email,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
      'payment_qr_code': paymentQrCode,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{};
    if (businessName.isNotEmpty) json['business_name'] = businessName;
    if (tagline != null) json['tagline'] = tagline;
    if (registrationNumber != null) json['registration_number'] = registrationNumber;
    if (address != null) json['address'] = address;
    if (phone != null) json['phone'] = phone;
    if (email != null) json['email'] = email;
    if (bankName != null) json['bank_name'] = bankName;
    if (accountNumber != null) json['account_number'] = accountNumber;
    if (accountName != null) json['account_name'] = accountName;
    if (paymentQrCode != null) json['payment_qr_code'] = paymentQrCode;
    return json;
  }
}

