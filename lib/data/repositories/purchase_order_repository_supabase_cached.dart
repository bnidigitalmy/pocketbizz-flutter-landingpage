import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/purchase_order.dart';
import 'purchase_order_repository_supabase.dart';

/// Cached version of PurchaseOrderRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// Priority: HIGH (Used in procurement workflow, dashboard)
class PurchaseOrderRepositorySupabaseCached {
  final PurchaseOrderRepository _baseRepo;
  
  PurchaseOrderRepositorySupabaseCached(SupabaseClient supabase) 
      : _baseRepo = PurchaseOrderRepository(supabase);
  
  /// Get all purchase orders dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<PurchaseOrder>> getAllPurchaseOrdersCached({
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<PurchaseOrder>)? onDataUpdated,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // Build cache key dengan pagination
    final cacheKey = 'purchase_orders_${offset}_${limit}';
    
    return await PersistentCacheService.getOrSync<List<PurchaseOrder>>(
      cacheKey,
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('purchase_orders');
        var query = supabase
            .from('purchase_orders')
            .select('*, purchase_order_items(*)')
            .eq('business_owner_id', userId)
            .order('created_at', ascending: false);
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: purchase_orders updated after ${lastSync.toIso8601String()}');
        } else {
          // Full fetch with pagination
          query = query.range(offset, offset + limit - 1);
        }
        
        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full purchase orders list');
          // Full fetch
          final fullData = await supabase
              .from('purchase_orders')
              .select('*, purchase_order_items(*)')
              .eq('business_owner_id', userId)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
          return List<Map<String, dynamic>>.from(fullData);
        }
        
        return List<Map<String, dynamic>>.from(deltaData);
      },
      fromJson: (json) => PurchaseOrder.fromJson(json),
      toJson: (po) => po.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<PurchaseOrder>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get purchase order by ID dengan cache
  Future<PurchaseOrder?> getPurchaseOrderByIdCached(String poId) async {
    // For single PO, use base repo
    return await _baseRepo.getPurchaseOrderById(poId);
  }
  
  /// Force refresh semua purchase orders dari Supabase
  Future<List<PurchaseOrder>> refreshAll({
    int limit = 100,
    int offset = 0,
  }) async {
    return await getAllPurchaseOrdersCached(
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync purchase orders in background (non-blocking)
  Future<void> syncInBackground({
    int limit = 100,
    int offset = 0,
    void Function(List<PurchaseOrder>)? onDataUpdated,
  }) async {
    try {
      await getAllPurchaseOrdersCached(
        limit: limit,
        offset: offset,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: purchase_orders');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate purchase orders cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('purchase_orders');
  }
}

