import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/purchase_order.dart';
import 'purchase_order_repository_supabase.dart';

/// Cached version of PurchaseOrderRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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
          final orders = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return PurchaseOrder.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${orders.length} purchase orders');
          
          // Trigger background sync
          _syncPurchaseOrdersInBackground(
            userId: userId,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return orders;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached purchase orders: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchPurchaseOrders(
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
      final jsonList = fresh.map((po) => po.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('purchase_orders');
      debugPrint('✅ Cached ${fresh.length} purchase orders');
    } catch (e) {
      debugPrint('⚠️ Error caching purchase orders: $e');
    }
    
    return fresh;
  }
  
  /// Fetch purchase orders from Supabase
  Future<List<PurchaseOrder>> _fetchPurchaseOrders({
    required String userId,
    int limit = 100,
    int offset = 0,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('purchase_orders');
    
    // Build base query
    dynamic query = supabase
        .from('purchase_orders')
        .select('*, purchase_order_items(*)')
        .eq('business_owner_id', userId);
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: purchase_orders updated after ${lastSync.toIso8601String()}');
    }
    
    // Order must be after filters
    query = query.order('created_at', ascending: false);
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.range(offset, offset + limit - 1);
    }
    
    // Execute query
    final queryResult = await query;
    final deltaData = List<Map<String, dynamic>>.from(queryResult);
    
    // If delta fetch returns empty, do full fetch
    if (deltaData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full purchase orders list');
      // Full fetch
      final fullResult = await supabase
          .from('purchase_orders')
          .select('*, purchase_order_items(*)')
          .eq('business_owner_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      return (fullResult as List).map((json) {
        return PurchaseOrder.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return PurchaseOrder.fromJson(json);
    }).toList();
  }
  
  /// Background sync for purchase orders
  Future<void> _syncPurchaseOrdersInBackground({
    required String userId,
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<PurchaseOrder>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchPurchaseOrders(
        userId: userId,
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((po) => po.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('purchase_orders');
      } catch (e) {
        debugPrint('⚠️ Error updating purchase orders cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} purchase orders');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
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
    try {
      // Clear common purchase order cache boxes
      final commonKeys = ['purchase_orders_0_100', 'purchase_orders_100_100', 'purchase_orders'];
      for (final key in commonKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            await Hive.box(key).clear();
          }
        } catch (e) {
          // Box might not exist, ignore
        }
      }
      debugPrint('✅ Purchase orders cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating purchase orders cache: $e');
    }
  }
}
