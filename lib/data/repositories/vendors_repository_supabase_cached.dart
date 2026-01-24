import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/vendor.dart';
import 'vendors_repository_supabase.dart';

/// Cached version of VendorsRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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
          final vendors = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return Vendor.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${vendors.length} vendors');
          
          // Trigger background sync
          _syncVendorsInBackground(
            activeOnly: activeOnly,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return vendors;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached vendors: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchVendors(
      activeOnly: activeOnly,
      limit: limit,
      offset: offset,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((v) => v.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('vendors');
      debugPrint('✅ Cached ${fresh.length} vendors');
    } catch (e) {
      debugPrint('⚠️ Error caching vendors: $e');
    }
    
    return fresh;
  }
  
  /// Fetch vendors from Supabase
  Future<List<Vendor>> _fetchVendors({
    bool activeOnly = false,
    int limit = 100,
    int offset = 0,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('vendors');
    
    // Build base query
    dynamic query = supabase
        .from('vendors')
        .select();
    
    // Apply filters first (before .order())
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: vendors updated after ${lastSync.toIso8601String()}');
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
      debugPrint('🔄 Delta empty, fetching full vendors list');
      // Full fetch
      dynamic fullQuery = supabase
          .from('vendors')
          .select();
      
      if (activeOnly) {
        fullQuery = fullQuery.eq('is_active', true);
      }
      
      final fullResult = await fullQuery
          .order('name')
          .range(offset, offset + limit - 1);
      
      return (fullResult as List).map((json) {
        return Vendor.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return Vendor.fromJson(json);
    }).toList();
  }
  
  /// Background sync for vendors
  Future<void> _syncVendorsInBackground({
    bool activeOnly = false,
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<Vendor>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchVendors(
        activeOnly: activeOnly,
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((v) => v.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('vendors');
      } catch (e) {
        debugPrint('⚠️ Error updating vendors cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} vendors');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
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
    try {
      // Clear all vendor-related cache boxes
      final boxNames = ['vendors_active_0_100', 'vendors_all_0_100', 'vendors'];
      for (final boxName in boxNames) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
        }
      }
      debugPrint('✅ Vendors cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating vendors cache: $e');
    }
  }
}
