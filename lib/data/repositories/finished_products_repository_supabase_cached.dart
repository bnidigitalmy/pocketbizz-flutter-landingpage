import 'package:flutter/foundation.dart';
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
    return await PersistentCacheService.getOrSync<List<FinishedProductSummary>>(
      key: 'finished_products_summary',
      fetcher: () async {
        final summaries = await _baseRepo.getFinishedProductsSummary();
        // Convert to List<Map> for caching
        return summaries.map((s) => s.toJson()).toList();
      },
      fromJson: (json) => FinishedProductSummary.fromJson(json),
      toJson: (summary) => summary.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data)
          : null,
      forceRefresh: forceRefresh,
    );
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

