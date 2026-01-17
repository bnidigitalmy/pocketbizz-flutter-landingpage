/// Pricing Tier Model
/// Represents a pricing tier for subscriptions
/// Implements 3-tier pricing: Early Adopter (RM29), Growth (RM39), Standard (RM49)
class PricingTier {
  final String id;
  final int tierOrder;
  final String tierName;
  final String tierNameDisplay;
  final double priceMonthly;
  final double? priceYearly;
  final int? maxSubscribers;
  final int currentSubscribers;
  final int? slotsRemaining;
  final bool isCurrentTier;
  final bool isSoldOut;
  final String? description;

  PricingTier({
    required this.id,
    required this.tierOrder,
    required this.tierName,
    required this.tierNameDisplay,
    required this.priceMonthly,
    this.priceYearly,
    this.maxSubscribers,
    required this.currentSubscribers,
    this.slotsRemaining,
    this.isCurrentTier = false,
    this.isSoldOut = false,
    this.description,
  });

  factory PricingTier.fromJson(Map<String, dynamic> json) {
    return PricingTier(
      id: json['tier_id'] as String? ?? json['id'] as String,
      tierOrder: json['tier_order'] as int? ?? 0,
      tierName: json['tier_name'] as String,
      tierNameDisplay: json['tier_name_display'] as String,
      priceMonthly: (json['price_monthly'] as num).toDouble(),
      priceYearly: json['price_yearly'] != null 
          ? (json['price_yearly'] as num).toDouble() 
          : null,
      maxSubscribers: json['max_subscribers'] as int?,
      currentSubscribers: json['current_subscribers'] as int? ?? 0,
      slotsRemaining: json['slots_remaining'] as int?,
      isCurrentTier: json['is_current_tier'] as bool? ?? false,
      isSoldOut: json['is_sold_out'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tier_order': tierOrder,
      'tier_name': tierName,
      'tier_name_display': tierNameDisplay,
      'price_monthly': priceMonthly,
      'price_yearly': priceYearly,
      'max_subscribers': maxSubscribers,
      'current_subscribers': currentSubscribers,
      'slots_remaining': slotsRemaining,
      'is_current_tier': isCurrentTier,
      'is_sold_out': isSoldOut,
      'description': description,
    };
  }

  /// Check if this tier has unlimited slots
  bool get isUnlimited => maxSubscribers == null;

  /// Get percentage of slots used (0-100)
  double get usagePercentage {
    if (maxSubscribers == null || maxSubscribers == 0) return 0;
    return (currentSubscribers / maxSubscribers!) * 100;
  }

  /// Get display text for slots remaining
  String get slotsRemainingText {
    if (isUnlimited) return 'Unlimited';
    if (isSoldOut) return 'Habis!';
    return '${slotsRemaining ?? 0} slot lagi';
  }

  /// Check if tier is early adopter
  bool get isEarlyAdopter => tierName == 'early_adopter';

  /// Check if tier is growth
  bool get isGrowth => tierName == 'growth';

  /// Check if tier is standard
  bool get isStandard => tierName == 'standard';
}

/// Pricing Info Response
/// Contains current tier and all tiers info
class PricingInfo {
  final PricingTier currentTier;
  final List<PricingTier> allTiers;
  final bool hasEarlyAdopterSlots;

  PricingInfo({
    required this.currentTier,
    required this.allTiers,
    required this.hasEarlyAdopterSlots,
  });

  factory PricingInfo.fromJson(Map<String, dynamic> json) {
    final currentTierJson = json['current_tier'] as Map<String, dynamic>;
    final allTiersJson = json['all_tiers'] as List<dynamic>;
    
    return PricingInfo(
      currentTier: PricingTier.fromJson(currentTierJson),
      allTiers: allTiersJson
          .map((e) => PricingTier.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasEarlyAdopterSlots: json['has_early_adopter_slots'] as bool? ?? false,
    );
  }

  /// Get tier by name
  PricingTier? getTierByName(String tierName) {
    try {
      return allTiers.firstWhere((t) => t.tierName == tierName);
    } catch (e) {
      return null;
    }
  }

  /// Get early adopter tier
  PricingTier? get earlyAdopterTier => getTierByName('early_adopter');

  /// Get growth tier
  PricingTier? get growthTier => getTierByName('growth');

  /// Get standard tier
  PricingTier? get standardTier => getTierByName('standard');

  /// Get price per month for current tier
  double get currentPrice => currentTier.priceMonthly;

  /// Get display message for pricing
  String get pricingMessage {
    if (currentTier.isEarlyAdopter) {
      return 'Harga istimewa Early Adopter! Hanya tinggal ${currentTier.slotsRemaining ?? 0} slot.';
    } else if (currentTier.isGrowth) {
      return 'Harga Growth Rate! Daftar sekarang sebelum naik ke RM49.';
    } else {
      return 'Harga Standard - Akses penuh ke semua features.';
    }
  }
}
