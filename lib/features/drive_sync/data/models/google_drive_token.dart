class GoogleDriveToken {
  final String id;
  final String businessOwnerId;
  final String accessToken;
  final String? refreshToken;
  final DateTime tokenExpiry;
  final String? googleEmail;
  final String? googleUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  GoogleDriveToken({
    required this.id,
    required this.businessOwnerId,
    required this.accessToken,
    this.refreshToken,
    required this.tokenExpiry,
    this.googleEmail,
    this.googleUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GoogleDriveToken.fromJson(Map<String, dynamic> json) {
    return GoogleDriveToken(
      id: json['id'] as String? ?? '',
      businessOwnerId: json['business_owner_id'] as String? ?? '',
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String?,
      tokenExpiry: json['token_expiry'] != null
          ? DateTime.parse(json['token_expiry'] as String)
          : DateTime.now(),
      googleEmail: json['google_email'] as String?,
      googleUserId: json['google_user_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_owner_id': businessOwnerId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_expiry': tokenExpiry.toIso8601String(),
      'google_email': googleEmail,
      'google_user_id': googleUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isExpired {
    return DateTime.now().toUtc().isAfter(tokenExpiry);
  }

  bool get needsRefresh {
    // Refresh if token expires in less than 5 minutes
    final fiveMinutesFromNow = DateTime.now().toUtc().add(const Duration(minutes: 5));
    return fiveMinutesFromNow.isAfter(tokenExpiry);
  }
}

