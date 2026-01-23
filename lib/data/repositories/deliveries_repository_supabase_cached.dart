import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/delivery.dart';
import 'deliveries_repository_supabase.dart';

/// Cached version of DeliveriesRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// Priority: HIGH (Complex queries with joins = high egress)
class DeliveriesRepositorySupabaseCached {
  final DeliveriesRepositorySupabase _baseRepo = DeliveriesRepositorySupabase();
  
  /// Get all deliveries dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  /// Note: Complex query with joins (vendors, products) - high egress savings
  Future<Map<String, dynamic>> getAllDeliveriesCached({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    // Build cache key dengan pagination
    final cacheKey = 'deliveries_${offset}_${limit}';
    
    // For complex queries with joins, we'll cache the result directly
    // Since the query structure is complex, we'll use a simpler approach
    try {
      // Try to get from cache first
      if (!forceRefresh) {
        final lastSync = await PersistentCacheService.getLastSync('deliveries');
        if (lastSync == null) {
          // First time - fetch and cache
          final result = await _baseRepo.getAllDeliveries(limit: limit, offset: offset);
          await _cacheDeliveries(cacheKey, result);
          await _updateLastSync('deliveries');
          return result;
        }
        
        // Check if we have cached data
        final cached = await _getCachedDeliveries(cacheKey);
        if (cached != null) {
          debugPrint('✅ Cache hit: deliveries');
          
          // Trigger background sync
          _syncInBackground(limit: limit, offset: offset, onDataUpdated: onDataUpdated);
          
          return cached;
        }
      }
      
      // Cache miss or force refresh - fetch fresh
      debugPrint('🔄 Cache miss: deliveries - fetching fresh data...');
      final result = await _baseRepo.getAllDeliveries(limit: limit, offset: offset);
      await _cacheDeliveries(cacheKey, result);
      await _updateLastSync('deliveries');
      
      return result;
    } catch (e) {
      debugPrint('❌ Error in getAllDeliveriesCached: $e');
      // Fallback to base repo
      return await _baseRepo.getAllDeliveries(limit: limit, offset: offset);
    }
  }
  
  /// Background sync (non-blocking)
  Future<void> _syncInBackground({
    int limit = 20,
    int offset = 0,
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _baseRepo.getAllDeliveries(limit: limit, offset: offset);
      final cacheKey = 'deliveries_${offset}_${limit}';
      await _cacheDeliveries(cacheKey, fresh);
      await _updateLastSync('deliveries');
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: deliveries');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Cache deliveries result
  Future<void> _cacheDeliveries(String key, Map<String, dynamic> result) async {
    try {
      if (!Hive.isBoxOpen('deliveries')) {
        await Hive.openBox('deliveries');
      }
      final box = Hive.box('deliveries');
      // Store as JSON string
      final jsonString = jsonEncode(result);
      await box.put(key, jsonString);
    } catch (e) {
      debugPrint('⚠️ Error caching deliveries: $e');
    }
  }
  
  /// Get cached deliveries
  Future<Map<String, dynamic>?> _getCachedDeliveries(String key) async {
    try {
      if (!Hive.isBoxOpen('deliveries')) {
        await Hive.openBox('deliveries');
      }
      final box = Hive.box('deliveries');
      final cached = box.get(key);
      if (cached != null && cached is String) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ Error getting cached deliveries: $e');
    }
    return null;
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
  }
  
  /// Get delivery by ID dengan cache
  Future<Delivery?> getDeliveryByIdCached(String deliveryId) async {
    // For single delivery, use base repo (complex query)
    return await _baseRepo.getDeliveryById(deliveryId);
  }
  
  /// Force refresh semua deliveries dari Supabase
  Future<Map<String, dynamic>> refreshAll({
    int limit = 20,
    int offset = 0,
  }) async {
    return await getAllDeliveriesCached(
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync deliveries in background (non-blocking)
  Future<void> syncInBackground({
    int limit = 20,
    int offset = 0,
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    await _syncInBackground(
      limit: limit,
      offset: offset,
      onDataUpdated: onDataUpdated,
    );
  }
  
  /// Invalidate deliveries cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('deliveries');
  }
}

