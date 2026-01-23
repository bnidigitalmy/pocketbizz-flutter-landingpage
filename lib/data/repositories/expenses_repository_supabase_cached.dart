import 'package:flutter/foundation.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/expense.dart';
import 'expenses_repository_supabase.dart';

/// Cached version of ExpensesRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
class ExpensesRepositorySupabaseCached {
  final ExpensesRepositorySupabase _baseRepo = ExpensesRepositorySupabase();
  
  /// Get expenses dengan persistent cache + Stale-While-Revalidate
  /// 
  /// Returns cached data immediately, syncs in background
  Future<List<Expense>> getExpensesCached({
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
    void Function(List<Expense>)? onDataUpdated,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    
    // Build cache key dengan pagination
    final cacheKey = 'expenses_${offset}_${limit}';
    
    return await PersistentCacheService.getOrSync<List<Expense>>(
      cacheKey,
      fetcher: () async {
        // Build query dengan delta fetch support
        final lastSync = await PersistentCacheService.getLastSync('expenses');
        var query = supabase
            .from('expenses')
            .select()
            .eq('business_owner_id', userId)
            .order('expense_date', ascending: false)
            .order('created_at', ascending: false);
        
        // Delta fetch: hanya ambil updated records
        if (!forceRefresh && lastSync != null) {
          query = query.gt('updated_at', lastSync.toIso8601String());
          debugPrint('🔄 Delta fetch: expenses updated after ${lastSync.toIso8601String()}');
        } else {
          // Full fetch with pagination
          query = query.range(offset, offset + limit - 1);
        }
        
        // If delta fetch returns empty, do full fetch
        final deltaData = await query;
        if (deltaData.isEmpty && lastSync != null && !forceRefresh) {
          debugPrint('🔄 Delta empty, fetching full expenses list');
          // Full fetch
          final fullData = await supabase
              .from('expenses')
              .select()
              .eq('business_owner_id', userId)
              .order('expense_date', ascending: false)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
          return List<Map<String, dynamic>>.from(fullData);
        }
        
        return List<Map<String, dynamic>>.from(deltaData);
      },
      fromJson: (json) => Expense.fromJson(json),
      toJson: (expense) => expense.toJson(),
      onDataUpdated: onDataUpdated != null 
          ? (data) => onDataUpdated(data as List<Expense>)
          : null,
      forceRefresh: forceRefresh,
    );
  }
  
  /// Get expense by ID dengan cache
  Future<Expense?> getExpenseByIdCached(String id) async {
    // For single expense, use base repo
    return await _baseRepo.getExpenseById(id);
  }
  
  /// Force refresh semua expenses dari Supabase
  Future<List<Expense>> refreshAll({
    int limit = 50,
    int offset = 0,
  }) async {
    return await getExpensesCached(
      limit: limit,
      offset: offset,
      forceRefresh: true,
    );
  }
  
  /// Sync expenses in background (non-blocking)
  Future<void> syncInBackground({
    int limit = 50,
    int offset = 0,
    void Function(List<Expense>)? onDataUpdated,
  }) async {
    try {
      await getExpensesCached(
        limit: limit,
        offset: offset,
        forceRefresh: false,
        onDataUpdated: onDataUpdated,
      );
      debugPrint('✅ Background sync completed: expenses');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate expenses cache
  Future<void> invalidateCache() async {
    await PersistentCacheService.invalidate('expenses');
  }
}

