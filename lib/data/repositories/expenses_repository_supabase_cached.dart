import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/persistent_cache_service.dart';
import '../../core/supabase/supabase_client.dart';
import '../models/expense.dart';
import 'expenses_repository_supabase.dart';

/// Cached version of ExpensesRepository dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dari cache instantly (Hive) - Direct implementation (no type casting issues)
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
          final expenses = jsonList.map((json) {
            final jsonMap = json as Map<String, dynamic>;
            return Expense.fromJson(jsonMap);
          }).toList();
          debugPrint('✅ Cache hit: $cacheKey - ${expenses.length} expenses');
          
          // Trigger background sync
          _syncExpensesInBackground(
            userId: userId,
            limit: limit,
            offset: offset,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return expenses;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached expenses: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _fetchExpenses(
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
      final jsonList = fresh.map((e) => e.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('expenses');
      debugPrint('✅ Cached ${fresh.length} expenses');
    } catch (e) {
      debugPrint('⚠️ Error caching expenses: $e');
    }
    
    return fresh;
  }
  
  /// Fetch expenses from Supabase
  Future<List<Expense>> _fetchExpenses({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    // Build query dengan delta fetch support
    final lastSync = await PersistentCacheService.getLastSync('expenses');
    
    // Build base query
    dynamic query = supabase
        .from('expenses')
        .select()
        .eq('business_owner_id', userId);
    
    // Delta fetch: hanya ambil updated records (MUST be before .order())
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      debugPrint('🔄 Delta fetch: expenses updated after ${lastSync.toIso8601String()}');
    }
    
    // Order must be after filters
    query = query
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);
    
    // If delta fetch, don't limit (get all updates)
    if (lastSync == null) {
      query = query.range(offset, offset + limit - 1);
    }
    
    // Execute query
    final queryResult = await query;
    final deltaData = List<Map<String, dynamic>>.from(queryResult);
    
    // If delta fetch returns empty, do full fetch
    if (deltaData.isEmpty && lastSync != null) {
      debugPrint('🔄 Delta empty, fetching full expenses list');
      // Full fetch
      final fullResult = await supabase
          .from('expenses')
          .select()
          .eq('business_owner_id', userId)
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      return (fullResult as List).map((json) {
        return Expense.fromJson(json as Map<String, dynamic>);
      }).toList();
    }
    
    return deltaData.map((json) {
      return Expense.fromJson(json);
    }).toList();
  }
  
  /// Background sync for expenses
  Future<void> _syncExpensesInBackground({
    required String userId,
    int limit = 50,
    int offset = 0,
    required String cacheKey,
    void Function(List<Expense>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _fetchExpenses(
        userId: userId,
        limit: limit,
        offset: offset,
      );
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((e) => e.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('expenses');
      } catch (e) {
        debugPrint('⚠️ Error updating expenses cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey - ${fresh.length} expenses');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
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
    try {
      // Clear all expense-related cache boxes
      final boxNames = ['expenses_0_50', 'expenses_50_50', 'expenses'];
      for (final boxName in boxNames) {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).clear();
        }
      }
      debugPrint('✅ Expenses cache invalidated');
    } catch (e) {
      debugPrint('⚠️ Error invalidating expenses cache: $e');
    }
  }
}
