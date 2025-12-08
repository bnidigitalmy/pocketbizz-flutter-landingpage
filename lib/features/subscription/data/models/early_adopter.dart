/// Early Adopter Model
/// Tracks first 100 users for special pricing
class EarlyAdopter {
  final String id;
  final String userId;
  final String userEmail;
  final DateTime registeredAt;
  final DateTime? subscriptionStartedAt;
  final bool isActive;
  final DateTime createdAt;

  EarlyAdopter({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.registeredAt,
    this.subscriptionStartedAt,
    required this.isActive,
    required this.createdAt,
  });

  factory EarlyAdopter.fromJson(Map<String, dynamic> json) {
    return EarlyAdopter(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userEmail: json['user_email'] as String,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      subscriptionStartedAt: json['subscription_started_at'] != null
          ? DateTime.parse(json['subscription_started_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_email': userEmail,
      'registered_at': registeredAt.toIso8601String(),
      'subscription_started_at': subscriptionStartedAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}


