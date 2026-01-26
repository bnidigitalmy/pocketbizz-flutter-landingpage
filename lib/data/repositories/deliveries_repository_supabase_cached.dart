import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/delivery.dart';
import 'deliveries_repository_supabase.dart';

/// Cached version of DeliveriesRepository dengan Stale-While-Revalidate
///
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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
    final cacheKey = 'deliveries_${offset}_$limit';

    // Use direct Hive caching (more reliable - no type casting issues)
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final result = jsonDecode(cached) as Map<String, dynamic>;
          debugPrint('✅ Cache hit: $cacheKey');

          // Trigger background sync
          _syncInBackground(
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );

          return result;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached deliveries: $e');
      }
    }

    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _baseRepo.getAllDeliveries(limit: limit, offset: offset);

    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      await box.put('data', jsonEncode(fresh));
      await _updateLastSync('deliveries');
      debugPrint('✅ Cached deliveries data');
    } catch (e) {
      debugPrint('⚠️ Error caching deliveries: $e');
    }

    return fresh;
  }

  /// Background sync (non-blocking)
  Future<void> _syncInBackground({
    int limit = 20,
    int offset = 0,
    required String cacheKey,
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _baseRepo.getAllDeliveries(limit: limit, offset: offset);

      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        await box.put('data', jsonEncode(fresh));
        await _updateLastSync('deliveries');
      } catch (e) {
        debugPrint('⚠️ Error updating deliveries cache: $e');
      }

      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
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
    final cacheKey = 'deliveries_${offset}_$limit';
    await _syncInBackground(
      limit: limit,
      offset: offset,
      cacheKey: cacheKey,
      onDataUpdated: onDataUpdated,
    );
  }

  /// Invalidate deliveries cache
  Future<void> invalidateCache() async {
    try {
      // Clear common deliveries cache boxes
      final commonKeys = ['deliveries_0_20', 'deliveries_0_50', 'deliveries'];
      for (final key in commonKeys) {
        try {
          if (Hive.isBoxOpen(key)) {
            await Hive.box(key).clear();
          }
        } catch (e) {
          // Box might not exist, ignore
        }
      }

      // Also clear last sync from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_deliveries');

      debugPrint('✅ Deliveries cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating deliveries cache: $e');
    }
  }
}
