import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/supplier.dart';
import 'suppliers_repository_supabase.dart';

/// Cached version of SuppliersRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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
          final suppliers = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return Supplier.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${suppliers.length} suppliers');
          
          // Trigger background sync
          _syncSuppliersInBackground(
            userId: userId,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return suppliers;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached suppliers: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchSuppliers(
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
      final jsonList = fresh.map((s) => s.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('suppliers');
      debugPrint('✅ Cached ${fresh.length} suppliers');
    } catch (e) {
      debugPrint('⚠️ Error caching suppliers: $e');
    }
    
    return fresh;
  }
  
  /// Fetch suppliers from Supabase
  Future<List<Supplier>> _fetchSuppliers({
    required String userId,
    int limit = 100,
    int offset = 0,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('suppliers');
    
    // Build base query
    dynamic query = supabase
        .from('suppliers')
        .select();
    
    // Apply filters first (before .order())
    query = query.eq('business_owner_id', userId);
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: suppliers updated after ${lastSync.toIso8601String()}');
    }
    
    // Order must be after filters
    query = query.order('name');
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.range(offset, offset + limit - 1);
    }
    
    // Execute query
    final queryResult = await query;
    final deltaData = List<Map<String, dynamic>>.from(queryResult);
    
    // If delta fetch returns empty, do full fetch
    if (deltaData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full suppliers list');
      // Full fetch
      final fullResult = await supabase
          .from('suppliers')
          .select()
          .eq('business_owner_id', userId)
          .order('name')
          .range(offset, offset + limit - 1);
      
      return (fullResult as List).map((json) {
        return Supplier.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return Supplier.fromJson(json);
    }).toList();
  }
  
  /// Background sync for suppliers
  Future<void> _syncSuppliersInBackground({
    required String userId,
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<Supplier>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchSuppliers(
        userId: userId,
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((s) => s.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('suppliers');
      } catch (e) {
        debugPrint('⚠️ Error updating suppliers cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} suppliers');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
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
    try {
      // Clear common supplier cache boxes
      final commonKeys = ['suppliers_0_100', 'suppliers_100_100', 'suppliers'];
      for (final key in commonKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            await Hive.box(key).clear();
          }
        } catch (e) {
          // Box might not exist, ignore
        }
      }
      debugPrint('✅ Suppliers cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating suppliers cache: $e');
    }
  }
  
  // Delegate methods untuk write operations (invalidate cache after)
  
  /// Create supplier (write operation - invalidate cache after)
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final created = await _baseRepo.createSupplier(
      name: name,
      phone: phone,
      email: email,
      address: address,
    );
    // Invalidate cache after create
    await invalidateCache();
    return created;
  }
  
  /// Update supplier (write operation - invalidate cache after)
  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final updated = await _baseRepo.updateSupplier(
      id: id,
      name: name,
      phone: phone,
      email: email,
      address: address,
    );
    // Invalidate cache after update
    await invalidateCache();
    return updated;
  }
  
  /// Delete supplier (write operation - invalidate cache after)
  Future<void> deleteSupplier(String id) async {
    await _baseRepo.deleteSupplier(id);
    // Invalidate cache after delete
    await invalidateCache();
  }
  
  /// Expose base repository for widgets that need full SuppliersRepository interface
  SuppliersRepository get baseRepository => _baseRepo;
}
