import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/finished_product.dart';
import 'finished_products_repository_supabase.dart';

/// Cached version of FinishedProductsRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// High Priority: User guna setiap hari untuk check finished products
class FinishedProductsRepositoryCached {
  final FinishedProductsRepository _baseRepo;
  
  FinishedProductsRepositoryCached() 
      : _baseRepo = FinishedProductsRepository();
  
  /// Get finished products summary dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  /// High egress savings - complex aggregation query
  Future<List<FinishedProductSummary>> getFinishedProductsSummaryCached({
    bool forceRefresh = false,
    void Function(List<FinishedProductSummary>)? onDataUpdated,
  }) async {
    const cacheKey = 'finished_products_summary';
    
    // Use direct Hive caching untuk List types (more reliable)
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final jsonList = jsonDecode(cached) as List<dynamic>;
          final summaries = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return FinishedProductSummary.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey');
          
          // Trigger background sync
          _syncSummaryInBackground(
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return summaries;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached finished products summary: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchSummary();
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((s) => s.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('finished_products_summary');
    } catch (e) {
      debugPrint('⚠️ Error caching finished products summary: $e');
    }
    
    return fresh;
  }
  
  /// Fetch summary from Supabase
  Future<List<FinishedProductSummary>> _fetchSummary() async {
    return await _baseRepo.getFinishedProductsSummary();
  }
  
  /// Background sync for finished products summary
  Future<void> _syncSummaryInBackground({
    required String cacheKey,
    void Function(List<FinishedProductSummary>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchSummary();
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((s) => s.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('finished_products_summary');
      } catch (e) {
        debugPrint('⚠️ Error updating finished products summary cache: $e');
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
  
  /// Get product batches dengan persistent cache
  /// 
  /// Note: This is per-product, so cache key includes productId
  /// Uses ProductionBatch from finished_product.dart model
  Future<List<ProductionBatch>> getProductBatchesCached(
    String productId, {
    bool includeCompleted = false,
    bool forceRefresh = false,
    void Function(List<ProductionBatch>)? onDataUpdated,
  }) async {
    final cacheKey = 'finished_products_batches_${productId}_${includeCompleted ? 'all' : 'active'}';
    
    return await PersistentCacheService.getOrSync<List<ProductionBatch>>(
      key: cacheKey,
      fetcher: () async {
        final batches = await _baseRepo.getProductBatches(
          productId,
          includeCompleted: includeCompleted,
        );
        // Convert to List<Map> for caching
        return batches.map((b) => b.toJson()).toList();
      },
      fromJson: (json) => ProductionBatch.fromJson(json),
      toJson: (batch) => batch.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data)
          : null,
      forceRefresh: forceRefresh,
    );
  }
}

