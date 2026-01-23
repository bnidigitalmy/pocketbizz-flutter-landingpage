import 'package:flutter/foundation.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/stock_item.dart';
import 'stock_repository_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cached version of StockRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
class StockRepositorySupabaseCached {
  final StockRepository _baseRepo;
  
  StockRepositorySupabaseCached(SupabaseClient supabase) 
      : _baseRepo = StockRepository(supabase);
  
  /// Get all stock items dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<StockItem>> getAllStockItemsCached({
    bool includeArchived = false,
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<StockItem>)? onDataUpdated,
  }) async {
    // Build cache key dengan filters
    final cacheKey = 'stock_items_${includeArchived ? 'all' : 'active'}_${offset}_${limit}';
    
    return await PersistentCacheService.getOrSync<List<StockItem>>(
      cacheKey,
      fetcher: () async {
        final supabase = Supabase.instance.client;
        
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('stock_items');
        var query = supabase
            .from('stock_items')
            .select();
        
        if (!includeArchived) {
          query = query.eq('is_archived', false);
        }
        
        query = query.order('name', ascending: true);
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: stock_items updated after ${lastSync.toIso8601String()}');
        } else {
          // Full fetch with pagination
          query = query.range(offset, offset + limit - 1);
        }
        
        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full stock items list');
          // Full fetch
          var fullQuery = supabase
              .from('stock_items')
              .select()
              .order('name', ascending: true)
              .range(offset, offset + limit - 1);
          
          if (!includeArchived) {
            fullQuery = fullQuery.eq('is_archived', false);
          }
          
          return List<Map<String, dynamic>>.from(await fullQuery);
        }
        
        return List<Map<String, dynamic>>.from(deltaData);
      },
      fromJson: (json) => StockItem.fromJson(json),
      toJson: (item) => item.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<StockItem>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get low stock items dengan cache
  Future<List<StockItem>> getLowStockItemsCached({
    bool forceRefresh = false,
    void Function(List<StockItem>)? onDataUpdated,
  }) async {
    // Use base repo for low stock (complex query)
    return await _baseRepo.getLowStockItems();
  }
  
  /// Get stock item by ID dengan cache
  Future<StockItem?> getStockItemByIdCached(String id) async {
    // For single item, use base repo
    return await _baseRepo.getStockItemById(id);
  }
  
  /// Force refresh semua stock items dari Supabase
  Future<List<StockItem>> refreshAll({
    bool includeArchived = false,
    int limit = 100,
    int offset = 0,
  }) async {
    return await getAllStockItemsCached(
      includeArchived: includeArchived,
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync stock items in background (non-blocking)
  Future<void> syncInBackground({
    bool includeArchived = false,
    void Function(List<StockItem>)? onDataUpdated,
  }) async {
    try {
      await getAllStockItemsCached(
        includeArchived: includeArchived,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: stock_items');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate stock items cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('stock_items');
  }
}

