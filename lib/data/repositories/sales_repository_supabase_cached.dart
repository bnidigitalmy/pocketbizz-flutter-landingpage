import 'package:flutter/foundation.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import 'sales_repository_supabase.dart';

/// Cached version of SalesRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
class SalesRepositorySupabaseCached {
  final SalesRepositorySupabase _baseRepo = SalesRepositorySupabase();
  
  /// List all sales dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<Sale>> listSalesCached({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    bool forceRefresh = false,
    void Function(List<Sale>)? onDataUpdated,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // Build cache key dengan filters
    final cacheKey = 'sales_${channel ?? 'all'}_${startDate?.toIso8601String() ?? 'all'}_${endDate?.toIso8601String() ?? 'all'}';
    
    return await PersistentCacheService.getOrSync<List<Sale>>(
      cacheKey,
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('sales');
        var query = supabase
            .from('sales')
            .select('*, sale_items(*)')
            .order('created_at', ascending: false);
        
        // Apply filters
        if (channel != null && channel.isNotEmpty) {
          query = query.eq('channel', channel);
        }
        if (startDate != null) {
          query = query.gte('created_at', startDate.toIso8601String());
        }
        if (endDate != null) {
          query = query.lte('created_at', endDate.toIso8601String());
        }
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: sales updated after ${lastSync.toIso8601String()}');
        }
        
        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full sales list');
          // Full fetch
          var fullQuery = supabase
              .from('sales')
              .select('*, sale_items(*)')
              .order('created_at', ascending: false)
              .limit(limit);
          
          if (channel != null && channel.isNotEmpty) {
            fullQuery = fullQuery.eq('channel', channel);
          }
          if (startDate != null) {
            fullQuery = fullQuery.gte('created_at', startDate.toIso8601String());
          }
          if (endDate != null) {
            fullQuery = fullQuery.lte('created_at', endDate.toIso8601String());
          }
          
          return List<Map<String, dynamic>>.from(await fullQuery);
        }
        
        return List<Map<String, dynamic>>.from(deltaData);
      },
      fromJson: (json) => Sale.fromJson(json),
      toJson: (sale) => {
        'id': sale.id,
        'customer_name': sale.customerName,
        'channel': sale.channel,
        'total_amount': sale.totalAmount,
        'discount_amount': sale.discountAmount,
        'final_amount': sale.finalAmount,
        'cogs': sale.cogs,
        'profit': sale.profit,
        'notes': sale.notes,
        'delivery_address': sale.deliveryAddress,
        'created_at': sale.createdAt.toIso8601String(),
        'sale_items': sale.items?.map((item) => {
          'id': item.id,
          'sale_id': item.saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'subtotal': item.subtotal,
          'cost_of_goods': item.costOfGoods,
        }).toList(),
      },
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<Sale>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get sale by ID dengan cache
  Future<Sale> getSaleCached(String saleId) async {
    // For single sale, use base repo (less caching benefit)
    return await _baseRepo.getSale(saleId);
  }
  
  /// Force refresh semua sales dari Supabase
  Future<List<Sale>> refreshAll({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    return await listSalesCached(
      channel: channel,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      forceRefresh: true,
    );
  }
  
  /// Sync sales in background (non-blocking)
  Future<void> syncInBackground({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    void Function(List<Sale>)? onDataUpdated,
  }) async {
    try {
      await listSalesCached(
        channel: channel,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: sales');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate sales cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('sales');
  }
}

