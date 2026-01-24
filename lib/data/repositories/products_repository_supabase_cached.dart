import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/product.dart';
import 'products_repository_supabase.dart';

/// Cached version of ProductsRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// Usage:
/// ```dart
/// final repo = ProductsRepositorySupabaseCached();
/// final products = await repo.getAllCached(); // Instant load + background sync
/// ```
class ProductsRepositorySupabaseCached {
  final ProductsRepositorySupabase _baseRepo = ProductsRepositorySupabase();
  
  /// Get all products dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<Product>> getAllCached({
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<Product>)? onDataUpdated,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // Build cache key
    final cacheKey = 'products_active_$limit';
    
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
          final products = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return Product.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${products.length} products');
          
          // Trigger background sync
          _syncProductsInBackground(
            userId: userId,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return products;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached products: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchProducts(
      userId: userId,
      limit: limit,
      offset: offset,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((p) => p.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('products');
      debugPrint('✅ Cached ${fresh.length} products');
    } catch (e) {
      debugPrint('⚠️ Error caching products: $e');
    }
    
    return fresh;
  }
  
  /// Fetch products from Supabase
  Future<List<Product>> _fetchProducts({
    required String userId,
    int limit = 100,
    int offset = 0,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('products');
    
    // Build base query
    dynamic query = supabase
        .from('products')
        .select()
        .eq('business_owner_id', userId)
        .eq('is_active', true);
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: products updated after ${lastSync.toIso8601String()}');
    }
    
    // Order must be after filters
    query = query.order('name', ascending: true);
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.limit(limit).range(offset, offset + limit - 1);
    }
    
    // Execute query
    final queryResult = await query;
    final deltaData = List<Map<String, dynamic>>.from(queryResult);
    
    // If delta fetch returns empty, do full fetch
    if (deltaData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full products list');
      // Full fetch
      final fullResult = await supabase
          .from('products')
          .select()
          .eq('business_owner_id', userId)
          .eq('is_active', true)
          .order('name', ascending: true)
          .limit(limit)
          .range(offset, offset + limit - 1);
      
      return (fullResult as List).map((json) {
        return Product.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return Product.fromJson(json);
    }).toList();
  }
  
  /// Background sync for products
  Future<void> _syncProductsInBackground({
    required String userId,
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<Product>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchProducts(
        userId: userId,
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((p) => p.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('products');
      } catch (e) {
        debugPrint('⚠️ Error updating products cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} products');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
  }
  
  /// Get product by ID dengan cache
  Future<Product> getProductCached(String id) async {
    // For single product, use base repo
    return await _baseRepo.getProduct(id);
  }
  
  /// Force refresh semua products dari Supabase
  Future<List<Product>> refreshAll({
    int limit = 100,
    int offset = 0,
  }) async {
    return await getAllCached(
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync products in background (non-blocking)
  Future<void> syncInBackground({
    int limit = 100,
    int offset = 0,
    void Function(List<Product>)? onDataUpdated,
  }) async {
    try {
      await getAllCached(
        limit: limit,
        offset: offset,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: products');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate products cache
  Future<void> invalidateCache() async {
    try {
      // Clear all product-related cache boxes
      final boxNames = ['products_active_100', 'products_active_200', 'products'];
      for (final boxName in boxNames) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
        }
      }
      debugPrint('✅ Products cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating products cache: $e');
    }
  }
}
