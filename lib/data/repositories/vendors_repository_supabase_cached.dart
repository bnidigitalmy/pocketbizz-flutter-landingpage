import 'package:flutter/foundation.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/vendor.dart';
import 'vendors_repository_supabase.dart';

/// Cached version of VendorsRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
class VendorsRepositorySupabaseCached {
  final VendorsRepositorySupabase _baseRepo = VendorsRepositorySupabase();
  
  /// Get all vendors dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<Vendor>> getAllVendorsCached({
    bool activeOnly = false,
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<Vendor>)? onDataUpdated,
  }) async {
    // Build cache key dengan filters
    final cacheKey = 'vendors_${activeOnly ? 'active' : 'all'}_${offset}_${limit}';
    
    return await PersistentCacheService.getOrSync<List<Vendor>>(
      cacheKey,
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('vendors');
        var query = supabase
            .from('vendors')
            .select();
        
        if (activeOnly) {
          query = query.eq('is_active', true);
        }
        
        query = query.order('name');
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: vendors updated after ${lastSync.toIso8601String()}');
        } else {
          // Full fetch with pagination
          query = query.range(offset, offset + limit - 1);
        }
        
        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full vendors list');
          // Full fetch
          var fullQuery = supabase
              .from('vendors')
              .select()
              .order('name')
              .range(offset, offset + limit - 1);
          
          if (activeOnly) {
            fullQuery = fullQuery.eq('is_active', true);
          }
          
          return List<Map<String, dynamic>>.from(await fullQuery);
        }
        
        return List<Map<String, dynamic>>.from(deltaData);
      },
      fromJson: (json) => Vendor.fromJson(json),
      toJson: (vendor) => vendor.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<Vendor>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get vendor by ID dengan cache
  Future<Vendor?> getVendorByIdCached(String vendorId) async {
    // For single vendor, use base repo
    return await _baseRepo.getVendorById(vendorId);
  }
  
  /// Force refresh semua vendors dari Supabase
  Future<List<Vendor>> refreshAll({
    bool activeOnly = false,
    int limit = 100,
    int offset = 0,
  }) async {
    return await getAllVendorsCached(
      activeOnly: activeOnly,
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync vendors in background (non-blocking)
  Future<void> syncInBackground({
    bool activeOnly = false,
    void Function(List<Vendor>)? onDataUpdated,
  }) async {
    try {
      await getAllVendorsCached(
        activeOnly: activeOnly,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: vendors');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate vendors cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('vendors');
  }
}

