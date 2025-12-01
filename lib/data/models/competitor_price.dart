/// Competitor Price Model
/// Represents a competitor's price for a specific product
class CompetitorPrice {
  final String id;
  final String productId;
  final String businessOwnerId;
  final String competitorName;
  final double price;
  final String? source; // 'physical_store', 'online_platform', 'marketplace', 'other'
  final DateTime? lastUpdated;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompetitorPrice({
    required this.id,
    required this.productId,
    required this.businessOwnerId,
    required this.competitorName,
    required this.price,
    this.source,
    this.lastUpdated,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CompetitorPrice.fromJson(Map<String, dynamic> json) {
    return CompetitorPrice(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      businessOwnerId: json['business_owner_id'] as String,
      competitorName: json['competitor_name'] as String,
      price: (json['price'] as num).toDouble(),
      source: json['source'] as String?,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'business_owner_id': businessOwnerId,
      'competitor_name': competitorName,
      'price': price,
      'source': source,
      'last_updated': lastUpdated?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'product_id': productId,
      'business_owner_id': businessOwnerId,
      'competitor_name': competitorName,
      'price': price,
      'source': source,
      'last_updated': lastUpdated?.toIso8601String(),
      'notes': notes,
    };
  }

  CompetitorPrice copyWith({
    String? id,
    String? productId,
    String? businessOwnerId,
    String? competitorName,
    double? price,
    String? source,
    DateTime? lastUpdated,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompetitorPrice(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      businessOwnerId: businessOwnerId ?? this.businessOwnerId,
      competitorName: competitorName ?? this.competitorName,
      price: price ?? this.price,
      source: source ?? this.source,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Market Statistics Model
/// Contains calculated market statistics for a product
class MarketStatistics {
  final double averagePrice;
  final double minPrice;
  final double maxPrice;
  final int priceCount;

  MarketStatistics({
    required this.averagePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.priceCount,
  });

  factory MarketStatistics.fromJson(Map<String, dynamic> json) {
    return MarketStatistics(
      averagePrice: (json['avg_price'] as num).toDouble(),
      minPrice: (json['min_price'] as num).toDouble(),
      maxPrice: (json['max_price'] as num).toDouble(),
      priceCount: json['price_count'] as int,
    );
  }

  bool get hasData => priceCount > 0;
}

/// Market Position Enum
enum MarketPosition {
  belowMarket, // Price < 90% of average
  atMarket,    // Price between 90-110% of average
  aboveMarket, // Price > 110% of average
}

/// Market Analysis Model
/// Complete market analysis for a product
class MarketAnalysis {
  final MarketStatistics statistics;
  final double yourPrice;
  final double? costPerUnit;
  final MarketPosition position;
  final double positionPercentage; // How much above/below market
  final double? yourProfitMargin;
  final double? estimatedMarketProfitMargin;
  final double competitivenessScore; // 0-100
  final PricingRecommendation recommendation;

  MarketAnalysis({
    required this.statistics,
    required this.yourPrice,
    this.costPerUnit,
    required this.position,
    required this.positionPercentage,
    this.yourProfitMargin,
    this.estimatedMarketProfitMargin,
    required this.competitivenessScore,
    required this.recommendation,
  });
}

/// Pricing Recommendation Model
class PricingRecommendation {
  final double minPrice;      // 95% of average
  final double optimalPrice;   // Average price
  final double maxPrice;       // 105% of average
  final String? strategy;      // 'match_market', 'premium', 'budget'

  PricingRecommendation({
    required this.minPrice,
    required this.optimalPrice,
    required this.maxPrice,
    this.strategy,
  });
}

