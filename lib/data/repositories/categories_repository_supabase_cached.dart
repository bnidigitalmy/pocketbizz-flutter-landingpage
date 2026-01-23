import 'package:flutter/foundation.dart' show debugPrint;
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/category.dart' as models;
import 'categories_repository_supabase.dart';

/// Cached version of CategoriesRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// Priority: HIGHEST (35+ usages across codebase)
class CategoriesRepositorySupabaseCached {
  final CategoriesRepositorySupabase _baseRepo = CategoriesRepositorySupabase();
  
  /// Get all categories dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  /// Categories rarely change, so long TTL is safe
  Future<List<models.Category>> getAllCached({
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<models.Category>)? onDataUpdated,
  }) async {
    // Build cache key dengan pagination
    final cacheKey = 'categories_${offset}_${limit}';
    
    return await PersistentCacheService.getOrSync<List<models.Category>>(
      key: cacheKey,
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('categories');
        
        // Build base query
        dynamic query = supabase
            .from('categories')
            .select();
        
        // Apply filters
        query = query.eq('is_active', true);
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: categories updated after ${lastSync.toIso8601String()}');
        } else {
          // Full fetch with pagination
          query = query.range(offset, offset + limit - 1);
        }
        
        // Order
        query = query.order('name', ascending: true);
        
        // Execute query
        final queryResult = await query;
        
        // If delta fetch returns empty, do full fetch
        final deltaData = List<Map<String, dynamic>>.from(queryResult);
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full categories list');
          // Full fetch
          final fullData = await supabase
              .from('categories')
              .select()
              .eq('is_active', true)
              .order('name', ascending: true)
              .range(offset, offset + limit - 1);
          return List<Map<String, dynamic>>.from(fullData);
        }
        
        return deltaData;
      },
      fromJson: (json) => models.Category.fromJson(json),
      toJson: (category) => category.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<models.Category>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get category by ID dengan cache
  Future<models.Category> getByIdCached(String id) async {
    // For single category, use base repo
    return await _baseRepo.getById(id);
  }
  
  /// Force refresh semua categories dari Supabase
  Future<List<models.Category>> refreshAll({
    int limit = 100,
    int offset = 0,
  }) async {
    return await getAllCached(
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync categories in background (non-blocking)
  Future<void> syncInBackground({
    int limit = 100,
    int offset = 0,
    void Function(List<models.Category>)? onDataUpdated,
  }) async {
    try {
      await getAllCached(
        limit: limit,
        offset: offset,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: categories');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate categories cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('categories');
  }
}

