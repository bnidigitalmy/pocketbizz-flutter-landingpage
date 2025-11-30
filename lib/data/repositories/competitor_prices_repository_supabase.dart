import '../../core/supabase/supabase_client.dart';
import '../models/competitor_price.dart';

/// Repository for managing competitor prices
class CompetitorPricesRepositorySupabase {
  /// Get all competitor prices for a product
  Future<List<CompetitorPrice>> getCompetitorPrices(String productId) async {
    final data = await supabase
        .from('competitor_prices')
        .select()
        .eq('product_id', productId)
        .order('last_updated', ascending: false)
        .order('created_at', ascending: false);

    return (data as List)
        .map((json) => CompetitorPrice.fromJson(json))
        .toList();
  }

  /// Get market statistics for a product
  Future<MarketStatistics> getMarketStatistics(String productId) async {
    final data = await supabase.rpc('get_market_stats', params: {
      'p_product_id': productId,
    });

    if (data == null || (data as List).isEmpty) {
      return MarketStatistics(
        averagePrice: 0.0,
        minPrice: 0.0,
        maxPrice: 0.0,
        priceCount: 0,
      );
    }

    return MarketStatistics.fromJson(data[0] as Map<String, dynamic>);
  }

  /// Add a new competitor price
  Future<CompetitorPrice> addCompetitorPrice({
    required String productId,
    required String competitorName,
    required double price,
    String? source,
    DateTime? lastUpdated,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final data = await supabase
        .from('competitor_prices')
        .insert({
          'product_id': productId,
          'business_owner_id': userId,
          'competitor_name': competitorName,
          'price': price,
          'source': source,
          'last_updated': lastUpdated?.toIso8601String(),
          'notes': notes,
        })
        .select()
        .single();

    return CompetitorPrice.fromJson(data);
  }

  /// Update a competitor price
  Future<CompetitorPrice> updateCompetitorPrice(CompetitorPrice price) async {
    final data = await supabase
        .from('competitor_prices')
        .update({
          'competitor_name': price.competitorName,
          'price': price.price,
          'source': price.source,
          'last_updated': price.lastUpdated?.toIso8601String(),
          'notes': price.notes,
        })
        .eq('id', price.id)
        .select()
        .single();

    return CompetitorPrice.fromJson(data);
  }

  /// Delete a competitor price
  Future<void> deleteCompetitorPrice(String priceId) async {
    await supabase.from('competitor_prices').delete().eq('id', priceId);
  }

  /// Delete all competitor prices for a product
  Future<void> deleteAllCompetitorPrices(String productId) async {
    await supabase
        .from('competitor_prices')
        .delete()
        .eq('product_id', productId);
  }
}

