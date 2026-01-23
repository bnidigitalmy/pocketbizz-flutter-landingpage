import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/persistent_cache_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/repositories/expenses_repository_supabase.dart';
import '../../../data/repositories/purchase_order_repository_supabase.dart';
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../reports/data/repositories/reports_repository_supabase.dart';
import '../../reports/data/models/sales_by_channel.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/data/models/subscription.dart';
import '../domain/sme_dashboard_v2_models.dart';
import 'sme_dashboard_v2_service.dart';

/// Cached Dashboard Service dengan Stale-While-Revalidate
/// 
/// Features:
/// - Load dashboard data dari cache instantly
/// - Background sync dengan Supabase
/// - Delta fetch untuk jimat egress
/// - Offline-first approach
class DashboardCacheService {
  final BookingsRepositorySupabase _bookingsRepo = BookingsRepositorySupabase();
  final PurchaseOrderRepository _poRepo = PurchaseOrderRepository(supabase);
  final StockRepository _stockRepo = StockRepository(supabase);
  final ReportsRepositorySupabase _reportsRepo = ReportsRepositorySupabase();
  final SmeDashboardV2Service _v2Service = SmeDashboardV2Service();
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  /// Get booking statistics dengan cache
  Future<Map<String, dynamic>> getStatisticsCached({
    bool forceRefresh = false,
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    // For Map types, we'll use direct Hive caching
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen('dashboard_stats')) {
          await Hive.openBox('dashboard_stats');
        }
        final box = Hive.box('dashboard_stats');
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final stats = jsonDecode(cached) as Map<String, dynamic>;
          debugPrint('✅ Cache hit: dashboard_stats');
          
          // Trigger background sync
          _syncStatisticsInBackground(onDataUpdated: onDataUpdated);
          
          return stats;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached stats: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: dashboard_stats - fetching fresh data...');
    final fresh = await _bookingsRepo.getStatistics();
    
    // Cache it
    try {
      if (!Hive.isBoxOpen('dashboard_stats')) {
        await Hive.openBox('dashboard_stats');
      }
      final box = Hive.box('dashboard_stats');
      await box.put('data', jsonEncode(fresh));
      await _updateLastSync('dashboard_stats');
    } catch (e) {
      debugPrint('⚠️ Error caching stats: $e');
    }
    
    return fresh;
  }
  
  /// Background sync for statistics
  Future<void> _syncStatisticsInBackground({
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    try {
      final fresh = await _bookingsRepo.getStatistics();
      
      try {
        if (!Hive.isBoxOpen('dashboard_stats')) {
          await Hive.openBox('dashboard_stats');
        }
        final box = Hive.box('dashboard_stats');
        await box.put('data', jsonEncode(fresh));
        await _updateLastSync('dashboard_stats');
      } catch (e) {
        debugPrint('⚠️ Error updating stats cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: dashboard_stats');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Get dashboard V2 data dengan cache
  /// Complex aggregation - high egress savings
  /// Note: SmeDashboardV2Data is immutable, so we cache as JSON
  Future<SmeDashboardV2Data> getDashboardV2Cached({
    bool forceRefresh = false,
    void Function(SmeDashboardV2Data)? onDataUpdated,
  }) async {
    if (!forceRefresh) {
      // Try to get from cache first
      try {
        if (!Hive.isBoxOpen('dashboard_v2')) {
          await Hive.openBox('dashboard_v2');
        }
        final box = Hive.box('dashboard_v2');
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final json = jsonDecode(cached) as Map<String, dynamic>;
          final data = _v2DataFromJson(json);
          debugPrint('✅ Cache hit: dashboard_v2');
          
          // Trigger background sync
          _syncV2InBackground(onDataUpdated: onDataUpdated);
          
          return data;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached dashboard_v2: $e');
      }
    }
    
    // Cache miss or force refresh - fetch fresh
    debugPrint('🔄 Cache miss: dashboard_v2 - fetching fresh data...');
    final fresh = await _v2Service.load();
    
    // Cache it
    try {
      if (!Hive.isBoxOpen('dashboard_v2')) {
        await Hive.openBox('dashboard_v2');
      }
      final box = Hive.box('dashboard_v2');
      final json = _v2DataToJson(fresh);
      await box.put('data', jsonEncode(json));
      await _updateLastSync('dashboard_v2');
    } catch (e) {
      debugPrint('⚠️ Error caching dashboard_v2: $e');
    }
    
    return fresh;
  }
  
  /// Background sync for V2 data
  Future<void> _syncV2InBackground({
    void Function(SmeDashboardV2Data)? onDataUpdated,
  }) async {
    try {
      final fresh = await _v2Service.load();
      
      // Check if changed
      if (!Hive.isBoxOpen('dashboard_v2')) {
        await Hive.openBox('dashboard_v2');
      }
      final box = Hive.box('dashboard_v2');
      final json = _v2DataToJson(fresh);
      await box.put('data', jsonEncode(json));
      await _updateLastSync('dashboard_v2');
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: dashboard_v2');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Convert SmeDashboardV2Data to JSON
  Map<String, dynamic> _v2DataToJson(SmeDashboardV2Data data) {
    return {
      'today': {
        'inflow': data.today.inflow,
        'productionCost': data.today.productionCost,
        'profit': data.today.profit,
        'expense': data.today.expense,
        'transactions': data.today.transactions,
      },
      'week': {
        'inflow': data.week.inflow,
        'expense': data.week.expense,
        'net': data.week.net,
      },
      'topProducts': {
        'todayTop3': data.topProducts.todayTop3.map((p) => {
          'key': p.key,
          'displayName': p.displayName,
          'units': p.units,
        }).toList(),
        'weekTop3': data.topProducts.weekTop3.map((p) => {
          'key': p.key,
          'displayName': p.displayName,
          'units': p.units,
        }).toList(),
      },
      'productionSuggestion': {
        'show': data.productionSuggestion.show,
        'title': data.productionSuggestion.title,
        'message': data.productionSuggestion.message,
      },
    };
  }
  
  /// Convert JSON to SmeDashboardV2Data
  SmeDashboardV2Data _v2DataFromJson(Map<String, dynamic> json) {
    return SmeDashboardV2Data(
      today: DashboardMoneySummary(
        inflow: (json['today']['inflow'] as num).toDouble(),
        productionCost: (json['today']['productionCost'] as num).toDouble(),
        profit: (json['today']['profit'] as num).toDouble(),
        expense: (json['today']['expense'] as num).toDouble(),
        transactions: json['today']['transactions'] as int,
      ),
      week: DashboardCashflowWeekly(
        inflow: (json['week']['inflow'] as num).toDouble(),
        expense: (json['week']['expense'] as num).toDouble(),
        net: (json['week']['net'] as num).toDouble(),
      ),
      topProducts: DashboardTopProducts(
        todayTop3: (json['topProducts']['todayTop3'] as List).map((p) => TopProductUnits(
          key: p['key'] as String,
          displayName: p['displayName'] as String,
          units: (p['units'] as num).toDouble(),
        )).toList(),
        weekTop3: (json['topProducts']['weekTop3'] as List).map((p) => TopProductUnits(
          key: p['key'] as String,
          displayName: p['displayName'] as String,
          units: (p['units'] as num).toDouble(),
        )).toList(),
      ),
      productionSuggestion: DashboardProductionSuggestion(
        show: json['productionSuggestion']['show'] as bool,
        title: json['productionSuggestion']['title'] as String,
        message: json['productionSuggestion']['message'] as String,
      ),
    );
  }
  
  /// Update last sync timestamp
  Future<void> _updateLastSync(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_$key', DateTime.now().toIso8601String());
  }
  
  /// Get subscription dengan cache
  Future<Subscription?> getSubscriptionCached({
    bool forceRefresh = false,
    void Function(Subscription?)? onDataUpdated,
  }) async {
    // Subscription changes rarely, so we can cache it longer
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen('dashboard_subscription')) {
          await Hive.openBox('dashboard_subscription');
        }
        final box = Hive.box('dashboard_subscription');
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final json = jsonDecode(cached) as Map<String, dynamic>?;
          if (json != null && json['has_subscription'] == true) {
            final subscription = Subscription.fromJson(json['subscription'] as Map<String, dynamic>);
            debugPrint('✅ Cache hit: dashboard_subscription');
            
            // Trigger background sync (non-blocking)
            _syncSubscriptionInBackground(onDataUpdated: onDataUpdated);
            
            return subscription;
          } else if (json != null && json['has_subscription'] == false) {
            debugPrint('✅ Cache hit: dashboard_subscription (no subscription)');
            return null;
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached subscription: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: dashboard_subscription - fetching fresh data...');
    final fresh = await _subscriptionService.getCurrentSubscription();
    
    // Cache it
    try {
      if (!Hive.isBoxOpen('dashboard_subscription')) {
        await Hive.openBox('dashboard_subscription');
      }
      final box = Hive.box('dashboard_subscription');
      if (fresh != null) {
        await box.put('data', jsonEncode({
          'has_subscription': true,
          'subscription': fresh.toJson(),
        }));
      } else {
        await box.put('data', jsonEncode({'has_subscription': false}));
      }
      await _updateLastSync('dashboard_subscription');
    } catch (e) {
      debugPrint('⚠️ Error caching subscription: $e');
    }
    
    return fresh;
  }
  
  /// Background sync for subscription
  Future<void> _syncSubscriptionInBackground({
    void Function(Subscription?)? onDataUpdated,
  }) async {
    try {
      final fresh = await _subscriptionService.getCurrentSubscription();
      
      // Update cache
      try {
        if (!Hive.isBoxOpen('dashboard_subscription')) {
          await Hive.openBox('dashboard_subscription');
        }
        final box = Hive.box('dashboard_subscription');
        if (fresh != null) {
          await box.put('data', jsonEncode({
            'has_subscription': true,
            'subscription': fresh.toJson(),
          }));
        } else {
          await box.put('data', jsonEncode({'has_subscription': false}));
        }
        await _updateLastSync('dashboard_subscription');
      } catch (e) {
        debugPrint('⚠️ Error updating subscription cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: dashboard_subscription');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Get pending tasks dengan cache
  Future<Map<String, dynamic>> getPendingTasksCached({
    bool forceRefresh = false,
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    // For Map types, we'll use direct Hive caching
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen('dashboard_pending_tasks')) {
          await Hive.openBox('dashboard_pending_tasks');
        }
        final box = Hive.box('dashboard_pending_tasks');
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final tasks = jsonDecode(cached) as Map<String, dynamic>;
          debugPrint('✅ Cache hit: dashboard_pending_tasks');
          
          // Trigger background sync
          _syncPendingTasksInBackground(onDataUpdated: onDataUpdated);
          
          return tasks;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached pending tasks: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: dashboard_pending_tasks - fetching fresh data...');
    
    // Load pending tasks in parallel
    final results = await Future.wait([
      _poRepo.getAllPurchaseOrders(limit: 1000).then((pos) {
        return pos.where((po) => po.status == 'sent' || po.status == 'draft').length;
      }).catchError((e) {
        debugPrint('Error loading pending POs: $e');
        return 0;
      }),
      _stockRepo.getLowStockItems().then((items) => items.length).catchError((e) {
        debugPrint('Error loading low stock: $e');
        return 0;
      }),
    ]);
    
    final fresh = {
      'pendingPOs': results[0],
      'lowStockCount': results[1],
    };
    
    // Cache it
    try {
      if (!Hive.isBoxOpen('dashboard_pending_tasks')) {
        await Hive.openBox('dashboard_pending_tasks');
      }
      final box = Hive.box('dashboard_pending_tasks');
      await box.put('data', jsonEncode(fresh));
      await _updateLastSync('dashboard_pending_tasks');
    } catch (e) {
      debugPrint('⚠️ Error caching pending tasks: $e');
    }
    
    return fresh;
  }
  
  /// Background sync for pending tasks
  Future<void> _syncPendingTasksInBackground({
    void Function(Map<String, dynamic>)? onDataUpdated,
  }) async {
    try {
      final results = await Future.wait([
        _poRepo.getAllPurchaseOrders(limit: 1000).then((pos) {
          return pos.where((po) => po.status == 'sent' || po.status == 'draft').length;
        }).catchError((e) {
          debugPrint('Error loading pending POs: $e');
          return 0;
        }),
        _stockRepo.getLowStockItems().then((items) => items.length).catchError((e) {
          debugPrint('Error loading low stock: $e');
          return 0;
        }),
      ]);
      
      final fresh = {
        'pendingPOs': results[0],
        'lowStockCount': results[1],
      };
      
      try {
        if (!Hive.isBoxOpen('dashboard_pending_tasks')) {
          await Hive.openBox('dashboard_pending_tasks');
        }
        final box = Hive.box('dashboard_pending_tasks');
        await box.put('data', jsonEncode(fresh));
        await _updateLastSync('dashboard_pending_tasks');
      } catch (e) {
        debugPrint('⚠️ Error updating pending tasks cache: $e');
      }
      
      if (onDataUpdated != null) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: dashboard_pending_tasks');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Get sales by channel dengan cache
  Future<List<SalesByChannel>> getSalesByChannelCached({
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
    void Function(List<SalesByChannel>)? onDataUpdated,
  }) async {
    // Build cache key dengan date range
    final cacheKey = 'dashboard_sales_by_channel_${startDate.toIso8601String()}_${endDate.toIso8601String()}';
    
    // Use direct Hive caching for List types (more reliable)
    if (!forceRefresh) {
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final cached = box.get('data');
        if (cached != null && cached is String) {
          final jsonList = jsonDecode(cached) as List<dynamic>;
          final channels = jsonList.map((json) => SalesByChannel.fromJson(json as Map<String, dynamic>)).toList();
          debugPrint('✅ Cache hit: $cacheKey');
          
          // Trigger background sync
          _syncSalesByChannelInBackground(
            startDate: startDate,
            endDate: endDate,
            cacheKey: cacheKey,
            onDataUpdated: onDataUpdated,
          );
          
          return channels;
        }
      } catch (e) {
        debugPrint('⚠️ Error loading cached sales by channel: $e');
      }
    }
    
    // Cache miss or force refresh
    debugPrint('🔄 Cache miss: $cacheKey - fetching fresh data...');
    final fresh = await _reportsRepo.getSalesByChannel(
      startDate: startDate,
      endDate: endDate,
    );
    
    // Cache it
    try {
      if (!Hive.isBoxOpen(cacheKey)) {
        await Hive.openBox(cacheKey);
      }
      final box = Hive.box(cacheKey);
      final jsonList = fresh.map((c) => c.toJson()).toList();
      await box.put('data', jsonEncode(jsonList));
      await _updateLastSync('dashboard_sales_by_channel');
    } catch (e) {
      debugPrint('⚠️ Error caching sales by channel: $e');
    }
    
    return fresh;
  }
  
  /// Background sync for sales by channel
  Future<void> _syncSalesByChannelInBackground({
    required DateTime startDate,
    required DateTime endDate,
    required String cacheKey,
    void Function(List<SalesByChannel>)? onDataUpdated,
  }) async {
    try {
      // Add timeout to prevent hanging
      final fresh = await _reportsRepo.getSalesByChannel(
        startDate: startDate,
        endDate: endDate,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Timeout fetching sales by channel, returning empty list');
          return <SalesByChannel>[];
        },
      );
      
      // Ensure fresh is a List
      if (fresh is! List<SalesByChannel>) {
        debugPrint('⚠️ Warning: getSalesByChannel returned non-List: ${fresh.runtimeType}');
        return;
      }
      
      try {
        if (!Hive.isBoxOpen(cacheKey)) {
          await Hive.openBox(cacheKey);
        }
        final box = Hive.box(cacheKey);
        final jsonList = fresh.map((c) => c.toJson()).toList();
        await box.put('data', jsonEncode(jsonList));
        await _updateLastSync('dashboard_sales_by_channel');
      } catch (e) {
        debugPrint('⚠️ Error updating sales by channel cache: $e');
      }
      
      if (onDataUpdated != null && fresh is List<SalesByChannel>) {
        onDataUpdated(fresh);
      }
      debugPrint('✅ Background sync completed: $cacheKey');
    } catch (e) {
      debugPrint('❌ Background sync failed for $cacheKey: $e');
      // Don't call onDataUpdated on error to prevent type issues
    }
  }
  
  /// Force refresh semua dashboard data
  Future<void> refreshAll() async {
    await Future.wait([
      getStatisticsCached(forceRefresh: true),
      getDashboardV2Cached(forceRefresh: true),
      getSubscriptionCached(forceRefresh: true),
      getPendingTasksCached(forceRefresh: true),
    ]);
  }
  
  /// Sync all dashboard data in background
  Future<void> syncAllInBackground({
    void Function()? onDataUpdated,
  }) async {
    try {
      await Future.wait([
        getStatisticsCached(),
        getDashboardV2Cached(),
        getSubscriptionCached(),
        getPendingTasksCached(),
      ]);
      
      if (onDataUpdated != null) {
        onDataUpdated();
      }
      debugPrint('✅ Background sync completed: dashboard');
    } catch (e) {
      debugPrint('❌ Background sync failed: $e');
    }
  }
  
  /// Invalidate all dashboard cache
  Future<void> invalidateAll() async {
    await PersistentCacheService.invalidateMultiple([
      'dashboard_stats',
      'dashboard_v2',
      'dashboard_subscription',
      'dashboard_pending_tasks',
      'dashboard_sales_by_channel',
    ]);
  }
}

