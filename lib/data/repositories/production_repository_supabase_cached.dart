import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/production_batch.dart';
import 'production_repository_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cached version of ProductionRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
/// 
/// High Priority: User guna setiap hari untuk manage production batches
class ProductionRepositoryCached {
  final ProductionRepository _baseRepo;
  final SupabaseClient _supabase;
  
  ProductionRepositoryCached(SupabaseClient supabase) 
      : _baseRepo = ProductionRepository(supabase),
        _supabase = supabase;
  
  /// Get all production batches dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  /// Supports pagination and filtering
  Future<List<ProductionBatch>> getAllBatchesCached({
    String? productId,
    bool onlyWithRemaining = false,
    int limit = 100,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<ProductionBatch>)? onDataUpdated,
  }) async {
    // Build cache key dengan filters
    final cacheKey = 'production_batches_${productId ?? 'all'}_${onlyWithRemaining ? 'remaining' : 'all'}_${offset}_${limit}';
    
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
          final batches = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            // Extract product_name from joined products table if present
            final productData = jsonMap['products'];
            if (productData != null && productData is Map) {
              jsonMap['product_name'] = productData['name'];
            }
            return ProductionBatch.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey');
          
          // Trigger background sync
          _syncBatchesInBackground(
            productId: productId,
            onlyWithRemaining: onlyWithRemaining,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return batches;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached production batches: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchBatches(
      productId: productId,
      onlyWithRemaining: onlyWithRemaining,
      limit: limit,
      offset: offset,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((b) => b.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('production_batches');
    } catch (e) {
      debugPrint('⚠️ Error caching production batches: $e');
    }
    
    return fresh;
  }
  
  /// Fetch batches from Supabase
  Future<List<ProductionBatch>> _fetchBatches({
    String? productId,
    bool onlyWithRemaining = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final supabase = Supabase.instance.client;
    
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('production_batches');
    dynamic query = supabase
        .from('production_batches')
        .select('''
          *,
          products!inner(name)
        ''');
    
    if (productId != null) {
      query = query.eq('product_id', productId);
    }
    
    if (onlyWithRemaining) {
      query = query.gt('remaining_qty', 0);
    }
    
    // Delta fetch: only get updated records
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
    }
    
    query = query
        .order('batch_date', ascending: false)
        .range(offset, offset + limit - 1);
    
    final response = await query;
    
    // If delta fetch returns empty, do full fetch
    if (lastSync != null && (response as List).isEmpty) {
      debugPrint('🔄 Delta fetch empty, doing full fetch for production_batches');
      dynamic fullQuery = supabase
          .from('production_batches')
          .select('''
            *,
            products!inner(name)
          ''');
      
      if (productId != null) {
        fullQuery = fullQuery.eq('product_id', productId);
      }
      
      if (onlyWithRemaining) {
        fullQuery = fullQuery.gt('remaining_qty', 0);
      }
      
      final fullResponse = await fullQuery
          .order('batch_date', ascending: false)
          .range(offset, offset + limit - 1);
      
      return (fullResponse as List).map((json) {
        // Extract product_name from joined products table
        final productData = json['products'];
        if (productData != null && productData is Map) {
          json['product_name'] = productData['name'];
        }
        return ProductionBatch.fromJson(json);
      }).toList();
    }
    
    return (response as List).map((json) {
      // Extract product_name from joined products table
      final productData = json['products'];
      if (productData != null && productData is Map) {
        json['product_name'] = productData['name'];
      }
      return ProductionBatch.fromJson(json);
    }).toList();
  }
  
  /// Background sync for production batches
  Future<void> _syncBatchesInBackground({
    String? productId,
    bool onlyWithRemaining = false,
    int limit = 100,
    int offset = 0,
    required String cacheKey,
    void Function(List<ProductionBatch>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchBatches(
        productId: productId,
        onlyWithRemaining: onlyWithRemaining,
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((b) => b.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('production_batches');
      } catch (e) {
        debugPrint('⚠️ Error updating production batches cache: $e');
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
  
  /// Get batch by ID dengan cache
  Future<ProductionBatch?> getBatchByIdCached(
    String id, {
    bool forceRefresh = false,
    void Function(ProductionBatch?)? onDataUpdated,
  }) async {
    final cacheKey = 'production_batch_$id';
    
    // Use direct Hive caching untuk single nullable object
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final jsonMap = jsonDecode(cached) as Map<String, dynamic>;
          final batch = ProductionBatch.fromJson(jsonMap);
          debugPrint('✅ Cache hit: $cacheKey');
          
          // Trigger background sync
          _syncBatchByIdInBackground(
            id: id,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return batch;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached batch: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _baseRepo.getBatchById(id);
    
    // Cache it (if not null)
    if (fresh != null) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        await box.put('data', jsonEncode(fresh.toJson()));
        debugPrint('✅ Cached batch: $id');
      } catch (e) {
        debugPrint('⚠️ Error caching batch: $e');
      }
    }
    
    return fresh;
  }
  
  /// Background sync for single batch by ID
  Future<void> _syncBatchByIdInBackground({
    required String id,
    required String cacheKey,
    void Function(ProductionBatch?)? onDataUpdated,
  }) async {
    try {
      final fresh = await _baseRepo.getBatchById(id);
      
      if (fresh != null) {
        try {
          if (!Hive.isBoxOpen(cacheKey)) {
            await Hive.openBox(cacheKey);
          }
          final box = Hive.box(cacheKey);
          await box.put('data', jsonEncode(fresh.toJson()));
        } catch (e) {
          debugPrint('⚠️ Error updating batch cache: $e');
        }
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  // Delegate methods yang tak perlu cache (write operations atau complex queries)
  // These methods directly call base repository
  
  /// Get batch movement history (no cache - real-time data)
  Future<List<Map<String, dynamic>>> getBatchMovementHistory(String batchId) {
    return _baseRepo.getBatchMovementHistory(batchId);
  }
  
  /// Update batch notes (write operation - no cache)
  Future<ProductionBatch> updateBatchNotes(String batchId, String? notes) {
    return _baseRepo.updateBatchNotes(batchId, notes);
  }
  
  /// Delete batch with stock reversal (write operation - no cache)
  Future<void> deleteBatchWithStockReversal(String batchId) {
    return _baseRepo.deleteBatchWithStockReversal(batchId);
  }
  
  /// Expose base repository for widgets that need full ProductionRepository interface
  ProductionRepository get baseRepository => _baseRepo;
}

