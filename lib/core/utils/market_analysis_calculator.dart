import '../../data/models/competitor_price.dart';

/// Market Analysis Calculator
/// Calculates market statistics, position, and recommendations
class MarketAnalysisCalculator {
  /// Calculate market statistics from competitor prices
  static MarketStatistics calculateStatistics(List<CompetitorPrice> prices) {
    if (prices.isEmpty) {
      return MarketStatistics(
        averagePrice: 0.0,
        minPrice: 0.0,
        maxPrice: 0.0,
        priceCount: 0,
      );
    }

    final priceValues = prices.map((p) => p.price).toList();
    final average = priceValues.reduce((a, b) => a + b) / priceValues.length;
    final min = priceValues.reduce((a, b) => a < b ? a : b);
    final max = priceValues.reduce((a, b) => a > b ? a : b);

    return MarketStatistics(
      averagePrice: average,
      minPrice: min,
      maxPrice: max,
      priceCount: prices.length,
    );
  }

  /// Determine market position based on your price vs average
  static MarketPosition determinePosition(double yourPrice, double averagePrice) {
    if (averagePrice == 0) return MarketPosition.atMarket;

    final percentage = (yourPrice / averagePrice) * 100;

    if (percentage < 90) {
      return MarketPosition.belowMarket;
    } else if (percentage > 110) {
      return MarketPosition.aboveMarket;
    } else {
      return MarketPosition.atMarket;
    }
  }

  /// Calculate position percentage (how much above/below market)
  static double calculatePositionPercentage(double yourPrice, double averagePrice) {
    if (averagePrice == 0) return 0.0;
    return ((yourPrice - averagePrice) / averagePrice) * 100;
  }

  /// Calculate profit margin percentage
  static double? calculateProfitMargin(double salePrice, double? costPerUnit) {
    if (costPerUnit == null || costPerUnit == 0) return null;
    if (salePrice == 0) return null;
    return ((salePrice - costPerUnit) / salePrice) * 100;
  }

  /// Calculate competitiveness score (0-100)
  /// 100 = exactly at market average
  /// Lower score = further from market
  static double calculateCompetitivenessScore(double yourPrice, double averagePrice) {
    if (averagePrice == 0) return 0.0;

    final difference = (yourPrice - averagePrice).abs();
    final percentageDifference = (difference / averagePrice) * 100;

    // Score decreases as you move away from market average
    final score = 100 - percentageDifference;
    return score.clamp(0.0, 100.0);
  }

  /// Generate pricing recommendations
  static PricingRecommendation generateRecommendations(double averagePrice) {
    if (averagePrice == 0) {
      return PricingRecommendation(
        minPrice: 0.0,
        optimalPrice: 0.0,
        maxPrice: 0.0,
      );
    }

    final minPrice = averagePrice * 0.95; // 5% below market
    final optimalPrice = averagePrice; // At market
    final maxPrice = averagePrice * 1.05; // 5% above market

    return PricingRecommendation(
      minPrice: minPrice,
      optimalPrice: optimalPrice,
      maxPrice: maxPrice,
    );
  }

  /// Generate complete market analysis
  static MarketAnalysis analyze({
    required List<CompetitorPrice> competitorPrices,
    required double yourPrice,
    double? costPerUnit,
  }) {
    final statistics = calculateStatistics(competitorPrices);

    if (!statistics.hasData) {
      return MarketAnalysis(
        statistics: statistics,
        yourPrice: yourPrice,
        costPerUnit: costPerUnit,
        position: MarketPosition.atMarket,
        positionPercentage: 0.0,
        yourProfitMargin: calculateProfitMargin(yourPrice, costPerUnit),
        competitivenessScore: 0.0,
        recommendation: PricingRecommendation(
          minPrice: 0.0,
          optimalPrice: 0.0,
          maxPrice: 0.0,
        ),
      );
    }

    final position = determinePosition(yourPrice, statistics.averagePrice);
    final positionPercentage = calculatePositionPercentage(yourPrice, statistics.averagePrice);
    final competitivenessScore = calculateCompetitivenessScore(yourPrice, statistics.averagePrice);
    final recommendation = generateRecommendations(statistics.averagePrice);

    // Estimate market profit margin (assuming market cost is 60% of average price)
    // This is a rough estimate - can be improved with actual market cost data
    final estimatedMarketCost = statistics.averagePrice * 0.6;
    final estimatedMarketProfitMargin = calculateProfitMargin(
      statistics.averagePrice,
      estimatedMarketCost,
    );

    return MarketAnalysis(
      statistics: statistics,
      yourPrice: yourPrice,
      costPerUnit: costPerUnit,
      position: position,
      positionPercentage: positionPercentage,
      yourProfitMargin: calculateProfitMargin(yourPrice, costPerUnit),
      estimatedMarketProfitMargin: estimatedMarketProfitMargin,
      competitivenessScore: competitivenessScore,
      recommendation: recommendation,
    );
  }

  /// Get strategy suggestion based on analysis
  static String? getStrategySuggestion(MarketAnalysis analysis) {
    if (!analysis.statistics.hasData) return null;

    final yourMargin = analysis.yourProfitMargin ?? 0;
    final marketMargin = analysis.estimatedMarketProfitMargin ?? 0;

    if (yourMargin > marketMargin + 5) {
      return 'premium'; // Can afford to price higher
    } else if (yourMargin < marketMargin - 5) {
      return 'budget'; // Need to be more competitive
    } else {
      return 'match_market'; // Competitive position
    }
  }
}

