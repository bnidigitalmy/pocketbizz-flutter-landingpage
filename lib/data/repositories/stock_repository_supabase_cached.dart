import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/stock_item.dart';
import 'stock_repository_supabase.dart';

/// Cached version of StockRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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
    
    // Use direct Hive caching untuk List types (more reliable - no type casting issues)
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final jsonList = jsonDecode(cached) as List<dynamic>;
          final items = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return StockItem.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${items.length} stock items');
          
          // Trigger background sync
          _syncStockItemsInBackground(
            includeArchived: includeArchived,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return items;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached stock items: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchStockItems(
      includeArchived: includeArchived,
      limit: limit,
      offset: offset,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((item) => item.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('stock_items');
      debugPrint('✅ Cached ${fresh.length} stock items');
    } catch (e) {
      debugPrint('⚠️ Error caching stock items: $e');
    }
    
    return fresh;
  }
  
  /// Fetch stock items from Supabase
  Future<List<StockItem>> _fetchStockItems({
    bool includeArchived = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final supabase = Supabase.instance.client;
    
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('stock_items');
    
    // Build base query
    dynamic query = supabase
        .from('stock_items')
        .select();
    
    // Apply filters first
    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: stock_items updated after ${lastSync.toIso8601String()}');
    }
    
    // Order must be after filters
    query = query.order('name', ascending: true);
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.range(offset, offset + limit - 1);
    }
    
    // Execute query
    final queryResult = await query;
    final deltaData = List<Map<String, dynamic>>.from(queryResult);
    
    // If delta fetch returns empty, do full fetch
    if (deltaData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full stock items list');
      // Full fetch
      dynamic fullQuery = supabase
          .from('stock_items')
          .select();
      
      if (!includeArchived) {
        fullQuery = fullQuery.eq('is_archived', false);
      }
      
      final fullResult = await fullQuery
          .order('name', ascending: true)
          .range(offset, offset + limit - 1);
      
      return (fullResult as List).map((json) {
        return StockItem.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return StockItem.fromJson(json);
    }).toList();
  }
  
  /// Background sync for stock items
  Future<void> _syncStockItemsInBackground({
    bool includeArchived = false,
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<StockItem>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchStockItems(
        includeArchived: includeArchived,
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((item) => item.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('stock_items');
      } catch (e) {
        debugPrint('⚠️ Error updating stock items cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} stock items');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
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
    try {
      // Clear common stock cache boxes
      final commonKeys = ['stock_items_active_0_100', 'stock_items_all_0_100', 'stock_items'];
      for (final key in commonKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            await Hive.box(key).clear();
          }
        } catch (e) {
          // Box might not exist, ignore
        }
      }
      debugPrint('✅ Stock items cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating stock items cache: $e');
    }
  }
}
