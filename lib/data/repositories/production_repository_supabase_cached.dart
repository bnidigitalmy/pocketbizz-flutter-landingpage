import 'package:flutter/foundation.dart';
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
    
    return await PersistentCacheService.getOrSync<List<ProductionBatch>>(
      key: cacheKey,
      fetcher: () async {
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
          
          final batches = (fullResponse as List).map((json) {
            // Extract product_name from joined products table
            final productData = json['products'];
            if (productData != null && productData is Map) {
              json['product_name'] = productData['name'];
            }
            return ProductionBatch.fromJson(json);
          }).toList();
          
          // Convert to List<Map> for caching
          return batches.map((b) => b.toJson()).toList();
        }
        
        final batches = (response as List).map((json) {
          // Extract product_name from joined products table
          final productData = json['products'];
          if (productData != null && productData is Map) {
            json['product_name'] = productData['name'];
          }
          return ProductionBatch.fromJson(json);
        }).toList();
        
        // Convert to List<Map> for caching
        return batches.map((b) => b.toJson()).toList();
      },
      fromJson: (json) {
        // Extract product_name from joined products table if present
        final productData = json['products'];
        if (productData != null && productData is Map) {
          json['product_name'] = productData['name'];
        }
        return ProductionBatch.fromJson(json);
      },
      toJson: (batch) => batch.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get batch by ID dengan cache
  Future<ProductionBatch?> getBatchByIdCached(
    String id, {
    bool forceRefresh = false,
    void Function(ProductionBatch?)? onDataUpdated,
  }) async {
    final cacheKey = 'production_batch_$id';
    
    return await PersistentCacheService.getOrSync<ProductionBatch?>(
      key: cacheKey,
      fetcher: () async {
        final batch = await _baseRepo.getBatchById(id);
        // Convert to List<Map> or empty list for caching
        if (batch == null) return <Map<String, dynamic>>[];
        return [batch.toJson()];
      },
      fromJson: (json) => json != null ? ProductionBatch.fromJson(json) : null,
      toJson: (batch) => batch?.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data)
          : null,
      forceRefresh: forceRefresh,
    );
  }
}

