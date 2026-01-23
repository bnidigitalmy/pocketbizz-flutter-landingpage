import 'package:flutter/foundation.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/supplier.dart';
import 'suppliers_repository_supabase.dart';

/// Cached version of SuppliersRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// Priority: HIGH (Used in stock management, purchase orders)
class SuppliersRepositorySupabaseCached {
  final SuppliersRepository _baseRepo = SuppliersRepository();
  
  /// Get all suppliers dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<Supplier>> getAllSuppliersCached({
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<Supplier>)? onDataUpdated,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // Build cache key dengan pagination
    final cacheKey = 'suppliers_${offset}_${limit}';
    
    return await PersistentCacheService.getOrSync<List<Supplier>>(
      cacheKey,
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('suppliers');
        var query = supabase
            .from('suppliers')
            .select()
            .eq('business_owner_id', userId)
            .order('name');
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: suppliers updated after ${lastSync.toIso8601String()}');
        } else {
          // Full fetch with pagination
          query = query.range(offset, offset + limit - 1);
        }
        
        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full suppliers list');
          // Full fetch
          final fullData = await supabase
              .from('suppliers')
              .select()
              .eq('business_owner_id', userId)
              .order('name')
              .range(offset, offset + limit - 1);
          return List<Map<String, dynamic>>.from(fullData);
        }
        
        return List<Map<String, dynamic>>.from(deltaData);
      },
      fromJson: (json) => Supplier.fromJson(json),
      toJson: (supplier) => supplier.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<Supplier>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get supplier by ID dengan cache
  Future<Supplier?> getSupplierByIdCached(String supplierId) async {
    // For single supplier, use base repo
    return await _baseRepo.getSupplierById(supplierId);
  }
  
  /// Force refresh semua suppliers dari Supabase
  Future<List<Supplier>> refreshAll({
    int limit = 100,
    int offset = 0,
  }) async {
    return await getAllSuppliersCached(
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync suppliers in background (non-blocking)
  Future<void> syncInBackground({
    int limit = 100,
    int offset = 0,
    void Function(List<Supplier>)? onDataUpdated,
  }) async {
    try {
      await getAllSuppliersCached(
        limit: limit,
        offset: offset,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: suppliers');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate suppliers cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('suppliers');
  }
}

