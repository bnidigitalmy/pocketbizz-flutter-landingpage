import 'package:intl/intl.dart';

/// Subscription Model
/// Represents user's subscription status
class Subscription {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final int durationMonths;
  
  // Pricing
  final double pricePerMonth;
  final double totalAmount;
  final double discountApplied;
  final bool isEarlyAdopter;
  
  // Status
  final SubscriptionStatus status;
  
  // Dates
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final DateTime? startedAt;
  final DateTime expiresAt;
  final DateTime? cancelledAt;
  
  // Payment
  final String? paymentGateway;
  final String? paymentReference;
  final PaymentStatus? paymentStatus;
  final DateTime? paymentCompletedAt;
  
  // Metadata
  final bool autoRenew;
  final String? notes;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.durationMonths,
    required this.pricePerMonth,
    required this.totalAmount,
    required this.discountApplied,
    required this.isEarlyAdopter,
    required this.status,
    this.trialStartedAt,
    this.trialEndsAt,
    this.startedAt,
    required this.expiresAt,
    this.cancelledAt,
    this.paymentGateway,
    this.paymentReference,
    this.paymentStatus,
    this.paymentCompletedAt,
    required this.autoRenew,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      planName: json['plan_name'] as String? ?? 'PocketBizz Pro',
      durationMonths: json['duration_months'] as int? ?? 1,
      pricePerMonth: (json['price_per_month'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      discountApplied: (json['discount_applied'] as num?)?.toDouble() ?? 0.0,
      isEarlyAdopter: json['is_early_adopter'] as bool? ?? false,
      status: _parseStatus(json['status'] as String),
      trialStartedAt: json['trial_started_at'] != null 
          ? DateTime.parse(json['trial_started_at'] as String)
          : null,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      paymentGateway: json['payment_gateway'] as String?,
      paymentReference: json['payment_reference'] as String?,
      paymentStatus: json['payment_status'] != null
          ? _parsePaymentStatus(json['payment_status'] as String)
          : null,
      paymentCompletedAt: json['payment_completed_at'] != null
          ? DateTime.parse(json['payment_completed_at'] as String)
          : null,
      autoRenew: json['auto_renew'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'plan_name': planName,
      'duration_months': durationMonths,
      'price_per_month': pricePerMonth,
      'total_amount': totalAmount,
      'discount_applied': discountApplied,
      'is_early_adopter': isEarlyAdopter,
      'status': status.toString().split('.').last,
      'trial_started_at': trialStartedAt?.toIso8601String(),
      'trial_ends_at': trialEndsAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'payment_gateway': paymentGateway,
      'payment_reference': paymentReference,
      'payment_status': paymentStatus?.toString().split('.').last,
      'payment_completed_at': paymentCompletedAt?.toIso8601String(),
      'auto_renew': autoRenew,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static SubscriptionStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'trial':
        return SubscriptionStatus.trial;
      case 'active':
        return SubscriptionStatus.active;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'pending_payment':
        return SubscriptionStatus.pendingPayment;
      default:
        return SubscriptionStatus.expired;
    }
  }

  static PaymentStatus? _parsePaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'completed':
        return PaymentStatus.completed;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return null;
    }
  }

  /// Check if subscription is active (trial or paid)
  bool get isActive => status == SubscriptionStatus.trial || status == SubscriptionStatus.active;

  /// Check if on trial
  bool get isOnTrial => status == SubscriptionStatus.trial;

  /// Get days remaining
  int get daysRemaining {
    final now = DateTime.now();
    final endDate = isOnTrial ? trialEndsAt : expiresAt;
    if (endDate == null) return 0;
    final diff = endDate.difference(now).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Check if expiring soon (7 days or less)
  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;

  /// Get formatted start date
  String get formattedStartDate {
    final date = startedAt ?? trialStartedAt ?? createdAt;
    return DateFormat('dd MMM yyyy', 'ms').format(date);
  }

  /// Get formatted end date
  String get formattedEndDate {
    final date = isOnTrial ? trialEndsAt : expiresAt;
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy', 'ms').format(date);
  }
}

enum SubscriptionStatus {
  trial,
  active,
  expired,
  cancelled,
  pendingPayment,
}

enum PaymentStatus {
  pending,
  completed,
  failed,
  refunded,
}


