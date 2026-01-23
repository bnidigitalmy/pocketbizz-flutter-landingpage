import 'package:flutter/foundation.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/product.dart';
import 'products_repository_supabase.dart';

/// Cached version of ProductsRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
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
  final SyncService _syncService = SyncService();
  
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
    
    // Use persistent cache dengan Stale-While-Revalidate
    return await PersistentCacheService.getOrSync<List<Product>>(
      'products',
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('products');
        var query = supabase
            .from('products')
            .select()
            .eq('business_owner_id', userId)
            .eq('is_active', true)
            .order('name', ascending: true);
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: products updated after ${lastSync.toIso8601String()}');
        }
        
        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full products list');
          // Full fetch for first time or when delta is empty
          final fullData = await supabase
              .from('products')
              .select()
              .eq('business_owner_id', userId)
              .eq('is_active', true)
              .order('name', ascending: true)
              .limit(limit)
              .range(offset, offset + limit - 1);
          return List<Map<String, dynamic>>.from(fullData);
        }
        
        return List<Map<String, dynamic>>.from(deltaData);
      },
      fromJson: (json) => Product.fromJson(json),
      toJson: (product) => (product as Product).toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<Product>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get product by ID dengan cache
  Future<Product> getProductCached(String id) async {
    // For single product, use in-memory cache (CacheService) is better
    // But can also use persistent cache if needed
    return await _baseRepo.getProduct(id);
  }
  
  /// Force refresh semua products dari Supabase
  Future<List<Product>> refreshAll() async {
    return await getAllCached(forceRefresh: true);
  }
  
  /// Sync products in background (non-blocking)
  Future<void> syncInBackground({
    void Function(List<Product>)? onDataUpdated,
  }) async {
    try {
      final products = await getAllCached(
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: ${products.length} products');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
      // Don't throw - this is background operation
    }
  }
  
  /// Invalidate products cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('products');
  }
}

