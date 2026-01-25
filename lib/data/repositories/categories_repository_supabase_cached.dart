import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/category.dart' as models;
import 'categories_repository_supabase.dart';

/// Cached version of CategoriesRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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
          final categories = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return models.Category.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${categories.length} categories');
          
          // Trigger background sync
          _syncCategoriesInBackground(
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return categories;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached categories: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchCategories(
      limit: limit,
      offset: offset,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((c) => c.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('categories');
      debugPrint('✅ Cached ${fresh.length} categories');
    } catch (e) {
      debugPrint('⚠️ Error caching categories: $e');
    }
    
    return fresh;
  }
  
  /// Fetch categories from Supabase
  Future<List<models.Category>> _fetchCategories({
    int limit = 100,
    int offset = 0,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('categories');
    
    // Build base query
    dynamic query = supabase
        .from('categories')
        .select();
    
    // Apply filters
    query = query.eq('is_active', true);
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: categories updated after ${lastSync.toIso8601String()}');
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
      debugPrint('🔄 Delta empty, fetching full categories list');
      // Full fetch
      final fullResult = await supabase
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true)
          .range(offset, offset + limit - 1);
      
      return (fullResult as List).map((json) {
        return models.Category.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return models.Category.fromJson(json);
    }).toList();
  }
  
  /// Background sync for categories
  Future<void> _syncCategoriesInBackground({
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<models.Category>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchCategories(
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((c) => c.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('categories');
      } catch (e) {
        debugPrint('⚠️ Error updating categories cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} categories');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
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
  /// Clear common cache keys dengan pattern: categories_{offset}_{limit}
  /// Support pagination dari 0-1000 dengan step 100
  Future<void> invalidateCache() async {
    try {
      // Generate common cache keys untuk pagination (0-1000, step 100)
      final commonKeys = <String>[];
      
      // Add common pagination keys
      for (int offset = 0; offset <= 1000; offset += 100) {
        commonKeys.add('categories_${offset}_100');
      }
      
      // Add general cache key
      commonKeys.add('categories');
      
      // Clear semua boxes
      int clearedCount = 0;
      for (final key in commonKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            await Hive.box(key).clear();
            clearedCount++;
            debugPrint('🗑️ Cleared cache: $key');
          }
        } catch (e) {
          // Box might not exist, ignore
        }
      }
      
      debugPrint('✅ Categories cache invalidated ($clearedCount keys cleared)');
    } catch (e) {
      debugPrint('⚠️ Error invalidating categories cache: $e');
    }
  }
  
  // Delegate methods untuk write operations (invalidate cache after)
  
  /// Create category (write operation - invalidate cache after)
  Future<models.Category> create(
    String name, {
    String? description,
    String? icon,
    String? color,
  }) async {
    final created = await _baseRepo.create(
      name,
      description: description,
      icon: icon,
      color: color,
    );
    // Invalidate cache after create
    await invalidateCache();
    return created;
  }
  
  /// Update category (write operation - invalidate cache after)
  Future<models.Category> update(String id, Map<String, dynamic> updates) async {
    final updated = await _baseRepo.update(id, updates);
    // Invalidate cache after update
    await invalidateCache();
    return updated;
  }
  
  /// Delete category (write operation - invalidate cache after)
  Future<void> delete(String id) async {
    await _baseRepo.delete(id);
    // Invalidate cache after delete
    await invalidateCache();
  }
  
  /// Expose base repository for widgets that need full CategoriesRepositorySupabase interface
  CategoriesRepositorySupabase get baseRepository => _baseRepo;
}
