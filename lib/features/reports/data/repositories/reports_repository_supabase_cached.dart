import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profit_loss_report.dart';
import '../models/top_product.dart';
import '../models/top_vendor.dart';
import '../models/monthly_trend.dart';
import '../models/sales_by_channel.dart';
import 'reports_repository_supabase.dart';

/// Cached version of ReportsRepository dengan Stale-While-Revalidate
///
/// Features:
/// - Load dari cache instantly (Hive)
/// - Background sync dengan Supabase
/// - Date-range aware caching
/// - Offline-first approach for reports
///
/// Priority: HIGH (Reports are complex aggregations - cache improves UX significantly)
class ReportsRepositorySupabaseCached {
  final ReportsRepositorySupabase _baseRepo = ReportsRepositorySupabase();

  static const String _boxName = 'reports_cache';
  static const String _lastSyncPrefix = 'reports_last_sync_';
  static bool _initialized = false;

  /// Initialize Hive box for reports cache
  static Future<void> initialize() async {
    if (_initialized) return;

    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    _initialized = true;
    debugPrint('✅ ReportsRepositorySupabaseCached initialized');
  }

  /// Generate cache key based on date range
  String _getCacheKey(String reportType, DateTime? startDate, DateTime? endDate) {
    final startStr = startDate?.toIso8601String().split('T')[0] ?? 'all';
    final endStr = endDate?.toIso8601String().split('T')[0] ?? 'all';
    return '${reportType}_${startStr}_$endStr';
  }

  /// Get Profit Loss Report dengan cache + SWR
  Future<ProfitLossReport?> getProfitLossReportCached({
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    void Function(ProfitLossReport)? onDataUpdated,
  }) async {
    await initialize();

    final box = Hive.box(_boxName);
    final cacheKey = _getCacheKey('profit_loss', startDate, endDate);

    // 1. STALE: Return cached data immediately
    if (!forceRefresh && box.containsKey(cacheKey)) {
      try {
        final cachedJson = box.get(cacheKey) as String;
        final cached = ProfitLossReport.fromJson(jsonDecode(cachedJson));
        debugPrint('✅ Cache hit (stale): $cacheKey');

        // 2. REVALIDATE: Background sync
        _syncProfitLossInBackground(
          startDate: startDate,
          endDate: endDate,
          cacheKey: cacheKey,
          onDataUpdated: onDataUpdated,
        );

        return cached;
      } catch (e) {
        debugPrint('⚠️ Error loading P&L cache: $e');
      }
    }

    // 3. CACHE MISS: Fetch fresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh P&L...');
    try {
      final report = await _baseRepo.getProfitLossReport(
        startDate: startDate,
        endDate: endDate,
      );

      // Store in cache
      await box.put(cacheKey, jsonEncode(report.toJson()));
      await _updateLastSync(cacheKey);

      debugPrint('✅ Fresh P&L cached: $cacheKey');
      return report;
    } catch (e) {
      debugPrint('❌ Error fetching P&L: $e');
      rethrow;
    }
  }

  /// Background sync for P&L
  Future<void> _syncProfitLossInBackground({
    DateTime? startDate,
    DateTime? endDate,
    required String cacheKey,
    void Function(ProfitLossReport)? onDataUpdated,
  }) async {
    try {
      final report = await _baseRepo.getProfitLossReport(
        startDate: startDate,
        endDate: endDate,
      );

      final box = Hive.box(_boxName);
      await box.put(cacheKey, jsonEncode(report.toJson()));
      await _updateLastSync(cacheKey);

      debugPrint('🔄 Background sync completed: $cacheKey');

      if (onDataUpdated != null) {
        onDataUpdated(report);
      }
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }

  /// Get Top Products dengan cache + SWR
  Future<List<TopProduct>> getTopProductsCached({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    void Function(List<TopProduct>)? onDataUpdated,
  }) async {
    await initialize();

    final box = Hive.box(_boxName);
    final cacheKey = _getCacheKey('top_products', startDate, endDate);

    // 1. STALE: Return cached data immediately
    if (!forceRefresh && box.containsKey(cacheKey)) {
      try {
        final cachedJson = box.get(cacheKey) as String;
        final cachedList = (jsonDecode(cachedJson) as List)
            .map((json) => TopProduct.fromJson(json))
            .toList();
        debugPrint('✅ Cache hit (stale): $cacheKey - ${cachedList.length} products');

        // 2. REVALIDATE: Background sync
        _syncTopProductsInBackground(
          limit: limit,
          startDate: startDate,
          endDate: endDate,
          cacheKey: cacheKey,
          onDataUpdated: onDataUpdated,
        );

        return cachedList;
      } catch (e) {
        debugPrint('⚠️ Error loading top products cache: $e');
      }
    }

    // 3. CACHE MISS: Fetch fresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh top products...');
    try {
      final products = await _baseRepo.getTopProducts(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      // Store in cache
      await box.put(cacheKey, jsonEncode(products.map((p) => p.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('✅ Fresh top products cached: $cacheKey - ${products.length} products');
      return products;
    } catch (e) {
      debugPrint('❌ Error fetching top products: $e');
      rethrow;
    }
  }

  /// Background sync for Top Products
  Future<void> _syncTopProductsInBackground({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
    required String cacheKey,
    void Function(List<TopProduct>)? onDataUpdated,
  }) async {
    try {
      final products = await _baseRepo.getTopProducts(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      final box = Hive.box(_boxName);
      await box.put(cacheKey, jsonEncode(products.map((p) => p.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('🔄 Background sync completed: $cacheKey');

      if (onDataUpdated != null) {
        onDataUpdated(products);
      }
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }

  /// Get Top Vendors dengan cache + SWR
  Future<List<TopVendor>> getTopVendorsCached({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    void Function(List<TopVendor>)? onDataUpdated,
  }) async {
    await initialize();

    final box = Hive.box(_boxName);
    final cacheKey = _getCacheKey('top_vendors', startDate, endDate);

    // 1. STALE: Return cached data immediately
    if (!forceRefresh && box.containsKey(cacheKey)) {
      try {
        final cachedJson = box.get(cacheKey) as String;
        final cachedList = (jsonDecode(cachedJson) as List)
            .map((json) => TopVendor.fromJson(json))
            .toList();
        debugPrint('✅ Cache hit (stale): $cacheKey - ${cachedList.length} vendors');

        // 2. REVALIDATE: Background sync
        _syncTopVendorsInBackground(
          limit: limit,
          startDate: startDate,
          endDate: endDate,
          cacheKey: cacheKey,
          onDataUpdated: onDataUpdated,
        );

        return cachedList;
      } catch (e) {
        debugPrint('⚠️ Error loading top vendors cache: $e');
      }
    }

    // 3. CACHE MISS: Fetch fresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh top vendors...');
    try {
      final vendors = await _baseRepo.getTopVendors(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      // Store in cache
      await box.put(cacheKey, jsonEncode(vendors.map((v) => v.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('✅ Fresh top vendors cached: $cacheKey - ${vendors.length} vendors');
      return vendors;
    } catch (e) {
      debugPrint('❌ Error fetching top vendors: $e');
      rethrow;
    }
  }

  /// Background sync for Top Vendors
  Future<void> _syncTopVendorsInBackground({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
    required String cacheKey,
    void Function(List<TopVendor>)? onDataUpdated,
  }) async {
    try {
      final vendors = await _baseRepo.getTopVendors(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      final box = Hive.box(_boxName);
      await box.put(cacheKey, jsonEncode(vendors.map((v) => v.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('🔄 Background sync completed: $cacheKey');

      if (onDataUpdated != null) {
        onDataUpdated(vendors);
      }
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }

  /// Get Monthly Trends dengan cache + SWR
  Future<List<MonthlyTrend>> getMonthlyTrendsCached({
    int months = 12,
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    void Function(List<MonthlyTrend>)? onDataUpdated,
  }) async {
    await initialize();

    final box = Hive.box(_boxName);
    final cacheKey = _getCacheKey('monthly_trends', startDate, endDate);

    // 1. STALE: Return cached data immediately
    if (!forceRefresh && box.containsKey(cacheKey)) {
      try {
        final cachedJson = box.get(cacheKey) as String;
        final cachedList = (jsonDecode(cachedJson) as List)
            .map((json) => MonthlyTrend.fromJson(json))
            .toList();
        debugPrint('✅ Cache hit (stale): $cacheKey - ${cachedList.length} trends');

        // 2. REVALIDATE: Background sync
        _syncMonthlyTrendsInBackground(
          months: months,
          startDate: startDate,
          endDate: endDate,
          cacheKey: cacheKey,
          onDataUpdated: onDataUpdated,
        );

        return cachedList;
      } catch (e) {
        debugPrint('⚠️ Error loading monthly trends cache: $e');
      }
    }

    // 3. CACHE MISS: Fetch fresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh monthly trends...');
    try {
      final trends = await _baseRepo.getMonthlyTrends(
        months: months,
        startDate: startDate,
        endDate: endDate,
      );

      // Store in cache
      await box.put(cacheKey, jsonEncode(trends.map((t) => t.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('✅ Fresh monthly trends cached: $cacheKey - ${trends.length} trends');
      return trends;
    } catch (e) {
      debugPrint('❌ Error fetching monthly trends: $e');
      rethrow;
    }
  }

  /// Background sync for Monthly Trends
  Future<void> _syncMonthlyTrendsInBackground({
    int months = 12,
    DateTime? startDate,
    DateTime? endDate,
    required String cacheKey,
    void Function(List<MonthlyTrend>)? onDataUpdated,
  }) async {
    try {
      final trends = await _baseRepo.getMonthlyTrends(
        months: months,
        startDate: startDate,
        endDate: endDate,
      );

      final box = Hive.box(_boxName);
      await box.put(cacheKey, jsonEncode(trends.map((t) => t.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('🔄 Background sync completed: $cacheKey');

      if (onDataUpdated != null) {
        onDataUpdated(trends);
      }
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }

  /// Get Sales By Channel dengan cache + SWR
  Future<List<SalesByChannel>> getSalesByChannelCached({
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
    void Function(List<SalesByChannel>)? onDataUpdated,
  }) async {
    await initialize();

    final box = Hive.box(_boxName);
    final cacheKey = _getCacheKey('sales_by_channel', startDate, endDate);

    // 1. STALE: Return cached data immediately
    if (!forceRefresh && box.containsKey(cacheKey)) {
      try {
        final cachedJson = box.get(cacheKey) as String;
        final cachedList = (jsonDecode(cachedJson) as List)
            .map((json) => SalesByChannel.fromJson(json))
            .toList();
        debugPrint('✅ Cache hit (stale): $cacheKey - ${cachedList.length} channels');

        // 2. REVALIDATE: Background sync
        _syncSalesByChannelInBackground(
          startDate: startDate,
          endDate: endDate,
          cacheKey: cacheKey,
          onDataUpdated: onDataUpdated,
        );

        return cachedList;
      } catch (e) {
        debugPrint('⚠️ Error loading sales by channel cache: $e');
      }
    }

    // 3. CACHE MISS: Fetch fresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh sales by channel...');
    try {
      final channels = await _baseRepo.getSalesByChannel(
        startDate: startDate,
        endDate: endDate,
      );

      // Store in cache
      await box.put(cacheKey, jsonEncode(channels.map((c) => c.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('✅ Fresh sales by channel cached: $cacheKey - ${channels.length} channels');
      return channels;
    } catch (e) {
      debugPrint('❌ Error fetching sales by channel: $e');
      rethrow;
    }
  }

  /// Background sync for Sales By Channel
  Future<void> _syncSalesByChannelInBackground({
    DateTime? startDate,
    DateTime? endDate,
    required String cacheKey,
    void Function(List<SalesByChannel>)? onDataUpdated,
  }) async {
    try {
      final channels = await _baseRepo.getSalesByChannel(
        startDate: startDate,
        endDate: endDate,
      );

      final box = Hive.box(_boxName);
      await box.put(cacheKey, jsonEncode(channels.map((c) => c.toJson()).toList()));
      await _updateLastSync(cacheKey);

      debugPrint('🔄 Background sync completed: $cacheKey');

      if (onDataUpdated != null) {
        onDataUpdated(channels);
      }
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
    }
  }

  /// Update last sync timestamp
  Future<void> _updateLastSync(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_lastSyncPrefix$cacheKey', DateTime.now().toIso8601String());
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSync(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('$_lastSyncPrefix$cacheKey');
    if (lastSyncStr == null) return null;
    return DateTime.tryParse(lastSyncStr);
  }

  /// Invalidate all reports cache
  Future<void> invalidateCache() async {
    await initialize();
    final box = Hive.box(_boxName);
    await box.clear();
    debugPrint('🗑️ Reports cache invalidated');
  }

  /// Invalidate cache for specific date range
  Future<void> invalidateCacheForDateRange(DateTime? startDate, DateTime? endDate) async {
    await initialize();
    final box = Hive.box(_boxName);

    final keysToDelete = [
      _getCacheKey('profit_loss', startDate, endDate),
      _getCacheKey('top_products', startDate, endDate),
      _getCacheKey('top_vendors', startDate, endDate),
      _getCacheKey('monthly_trends', startDate, endDate),
      _getCacheKey('sales_by_channel', startDate, endDate),
    ];

    for (final key in keysToDelete) {
      await box.delete(key);
    }

    debugPrint('🗑️ Reports cache invalidated for date range: $startDate - $endDate');
  }
}
