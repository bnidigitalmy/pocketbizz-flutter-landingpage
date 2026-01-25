import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import 'sales_repository_supabase.dart';

/// Cached version of SalesRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
class SalesRepositorySupabaseCached {
  final SalesRepositorySupabase _baseRepo = SalesRepositorySupabase();
  
  /// List all sales dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<Sale>> listSalesCached({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    bool forceRefresh = false,
    void Function(List<Sale>)? onDataUpdated,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // Build cache key dengan filters
    final cacheKey = 'sales_${channel ?? 'all'}_${startDate?.toIso8601String() ?? 'all'}_${endDate?.toIso8601String() ?? 'all'}';
    
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
          final sales = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return Sale.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${sales.length} sales');
          
          // Trigger background sync
          _syncSalesInBackground(
            userId: userId,
            channel: channel,
            startDate: startDate,
            endDate: endDate,
            limit: limit,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return sales;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached sales: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchSales(
      userId: userId,
      channel: channel,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((s) => _saleToJson(s)).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('sales');
      debugPrint('✅ Cached ${fresh.length} sales');
    } catch (e) {
      debugPrint('⚠️ Error caching sales: $e');
    }
    
    return fresh;
  }
  
  /// Fetch sales from Supabase
  Future<List<Sale>> _fetchSales({
    required String userId,
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('sales');
    
    // Build base query
    dynamic query = supabase
        .from('sales')
        .select('*, sale_items(*)');
    
    // Apply filters first (before .order())
    if (channel != null && channel.isNotEmpty) {
      query = query.eq('channel', channel);
    }
    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('created_at', endDate.toIso8601String());
    }
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: sales updated after ${lastSync.toIso8601String()}');
    }
    
    // Order must be after filters
    query = query.order('created_at', ascending: false);
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.limit(limit);
    }
    
    // Execute query
    final queryResult = await query;
    final deltaData = List<Map<String, dynamic>>.from(queryResult);
    
    // If delta fetch returns empty, do full fetch
    if (deltaData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full sales list');
      // Full fetch
      dynamic fullQuery = supabase
          .from('sales')
          .select('*, sale_items(*)');
      
      if (channel != null && channel.isNotEmpty) {
        fullQuery = fullQuery.eq('channel', channel);
      }
      if (startDate != null) {
        fullQuery = fullQuery.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        fullQuery = fullQuery.lte('created_at', endDate.toIso8601String());
      }
      
      final fullResult = await fullQuery
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (fullResult as List).map((json) {
        return Sale.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return Sale.fromJson(json);
    }).toList();
  }
  
  /// Convert Sale to JSON for caching
  Map<String, dynamic> _saleToJson(Sale sale) {
    return {
      'id': sale.id,
      'customer_name': sale.customerName,
      'channel': sale.channel,
      'total_amount': sale.totalAmount,
      'discount_amount': sale.discountAmount,
      'final_amount': sale.finalAmount,
      'cogs': sale.cogs,
      'profit': sale.profit,
      'notes': sale.notes,
      'delivery_address': sale.deliveryAddress,
      'created_at': sale.createdAt.toIso8601String(),
      'sale_items': sale.items?.map((item) => {
        'id': item.id,
        'sale_id': item.saleId,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'subtotal': item.subtotal,
        'cost_of_goods': item.costOfGoods,
      }).toList(),
    };
  }
  
  /// Background sync for sales
  Future<void> _syncSalesInBackground({
    required String userId,
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    required String cacheKey,
    void Function(List<Sale>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchSales(
        userId: userId,
        channel: channel,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((s) => _saleToJson(s)).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('sales');
      } catch (e) {
        debugPrint('⚠️ Error updating sales cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} sales');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
  }
  
  /// Get sale by ID dengan cache
  Future<Sale> getSaleCached(String saleId) async {
    // For single sale, use base repo
    return await _baseRepo.getSale(saleId);
  }
  
  /// Force refresh semua sales dari Supabase
  Future<List<Sale>> refreshAll({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    return await listSalesCached(
      channel: channel,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      forceRefresh: true,
    );
  }
  
  /// Sync sales in background (non-blocking)
  Future<void> syncInBackground({
    String? channel,
    DateTime? startDate,
    DateTime? endDate,
    void Function(List<Sale>)? onDataUpdated,
  }) async {
    try {
      await listSalesCached(
        channel: channel,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: sales');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate sales cache
  Future<void> invalidateCache() async {
    try {
      // Clear common sales cache boxes
      final commonKeys = ['sales_all_all_all', 'sales'];
      for (final key in commonKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            await Hive.box(key).clear();
          }
        } catch (e) {
          // Box might not exist, ignore
        }
      }
      debugPrint('✅ Sales cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating sales cache: $e');
    }
  }
}
