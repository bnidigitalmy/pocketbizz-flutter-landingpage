import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/repositories/reports_repository_supabase.dart';
import '../data/models/profit_loss_report.dart';
import '../data/models/top_product.dart';
import '../data/models/top_vendor.dart';
import '../data/models/monthly_trend.dart';
import '../data/models/sales_by_channel.dart';
import '../../../core/supabase/supabase_client.dart';

/// Reports State - Immutable state class
class ReportsState {
  final ProfitLossReport? profitLoss;
  final List<TopProduct> topProducts;
  final List<TopVendor> topVendors;
  final List<MonthlyTrend> monthlyTrends;
  final List<SalesByChannel> salesByChannel;
  
  final bool isLoadingProfitLoss;
  final bool isLoadingProducts;
  final bool isLoadingVendors;
  final bool isLoadingTrends;
  final bool isLoadingChannels;
  
  final String? profitLossError;
  final String? productsError;
  final String? vendorsError;
  final String? trendsError;
  final String? channelsError;
  
  final DateTime? startDate;
  final DateTime? endDate;

  const ReportsState({
    this.profitLoss,
    this.topProducts = const [],
    this.topVendors = const [],
    this.monthlyTrends = const [],
    this.salesByChannel = const [],
    this.isLoadingProfitLoss = false,
    this.isLoadingProducts = false,
    this.isLoadingVendors = false,
    this.isLoadingTrends = false,
    this.isLoadingChannels = false,
    this.profitLossError,
    this.productsError,
    this.vendorsError,
    this.trendsError,
    this.channelsError,
    this.startDate,
    this.endDate,
  });

  ReportsState copyWith({
    ProfitLossReport? profitLoss,
    List<TopProduct>? topProducts,
    List<TopVendor>? topVendors,
    List<MonthlyTrend>? monthlyTrends,
    List<SalesByChannel>? salesByChannel,
    bool? isLoadingProfitLoss,
    bool? isLoadingProducts,
    bool? isLoadingVendors,
    bool? isLoadingTrends,
    bool? isLoadingChannels,
    String? profitLossError,
    String? productsError,
    String? vendorsError,
    String? trendsError,
    String? channelsError,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return ReportsState(
      profitLoss: profitLoss ?? this.profitLoss,
      topProducts: topProducts ?? this.topProducts,
      topVendors: topVendors ?? this.topVendors,
      monthlyTrends: monthlyTrends ?? this.monthlyTrends,
      salesByChannel: salesByChannel ?? this.salesByChannel,
      isLoadingProfitLoss: isLoadingProfitLoss ?? this.isLoadingProfitLoss,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      isLoadingVendors: isLoadingVendors ?? this.isLoadingVendors,
      isLoadingTrends: isLoadingTrends ?? this.isLoadingTrends,
      isLoadingChannels: isLoadingChannels ?? this.isLoadingChannels,
      profitLossError: profitLossError ?? this.profitLossError,
      productsError: productsError ?? this.productsError,
      vendorsError: vendorsError ?? this.vendorsError,
      trendsError: trendsError ?? this.trendsError,
      channelsError: channelsError ?? this.channelsError,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

/// Reports State Notifier - Manages reports state with granular updates
/// 
/// IMPORTANT: Each browser window/tab creates its own instance via Riverpod ProviderScope.
/// All instances subscribe to the same Supabase Realtime channel.
/// When data changes, Supabase pushes events to ALL subscribers via WebSocket.
/// Each instance updates its own state incrementally (no full reload).
/// UI rebuilds automatically via ref.watch() when state changes.
class ReportsStateNotifier extends StateNotifier<ReportsState> {
  final ReportsRepositorySupabase _repo;
  final List<StreamSubscription> _subscriptions = [];
  RealtimeChannel? _realtimeChannel; // Store channel reference for proper cleanup
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString(); // Unique ID for debugging

  ReportsStateNotifier(this._repo) : super(const ReportsState()) {
    debugPrint('🆕 Reports StateNotifier instance created (ID: $_instanceId)');
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Reports StateNotifier disposing (ID: $_instanceId)');
    
    // Cancel all stream subscriptions first
    for (var subscription in _subscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        debugPrint('⚠️ Error canceling subscription: $e');
      }
    }
    _subscriptions.clear();
    
    // Unsubscribe from Supabase realtime channel to prevent memory leaks and hot restart hang
    // IMPORTANT: unsubscribe() is synchronous and properly closes WebSocket connection
    // removeChannel() is not needed if unsubscribe() is called
    if (_realtimeChannel != null) {
      try {
        debugPrint('🔌 Reports: Unsubscribing from realtime channel');
        _realtimeChannel!.unsubscribe();
        debugPrint('✅ Reports: Realtime channel unsubscribed');
      } catch (e) {
        debugPrint('⚠️ Error unsubscribing reports realtime channel: $e');
        // Fallback: try to remove channel if unsubscribe fails
        try {
          supabase.removeChannel(_realtimeChannel!);
        } catch (e2) {
          debugPrint('⚠️ Error removing channel after unsubscribe failure: $e2');
        }
      }
      _realtimeChannel = null;
    }
    
    debugPrint('✅ Reports StateNotifier disposed (ID: $_instanceId)');
    super.dispose();
  }

  /// Initial load of all data
  Future<void> loadAllData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Set date range
    state = state.copyWith(
      startDate: startDate ?? state.startDate,
      endDate: endDate ?? state.endDate,
    );

    await Future.wait([
      loadProfitLoss(),
      loadTopProducts(),
      loadTopVendors(),
      loadMonthlyTrends(),
      loadSalesByChannel(),
    ]);
  }

  /// Load Profit Loss Report
  Future<void> loadProfitLoss() async {
    // Guard: prevent concurrent loads
    if (state.isLoadingProfitLoss) return;
    
    state = state.copyWith(isLoadingProfitLoss: true, profitLossError: null);
    try {
      final report = await _repo.getProfitLossReport(
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        profitLoss: report,
        isLoadingProfitLoss: false,
        profitLossError: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingProfitLoss: false,
        profitLossError: e.toString(),
      );
    }
  }

  /// Load Top Products
  Future<void> loadTopProducts() async {
    // Guard: prevent concurrent loads
    if (state.isLoadingProducts) return;
    
    state = state.copyWith(isLoadingProducts: true, productsError: null);
    try {
      final products = await _repo.getTopProducts(
        limit: 10,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        topProducts: products,
        isLoadingProducts: false,
        productsError: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingProducts: false,
        productsError: e.toString(),
      );
    }
  }

  /// Load Top Vendors
  Future<void> loadTopVendors() async {
    // Guard: prevent concurrent loads
    if (state.isLoadingVendors) return;
    
    state = state.copyWith(isLoadingVendors: true, vendorsError: null);
    try {
      final vendors = await _repo.getTopVendors(
        limit: 10,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        topVendors: vendors,
        isLoadingVendors: false,
        vendorsError: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingVendors: false,
        vendorsError: e.toString(),
      );
    }
  }

  /// Load Monthly Trends
  Future<void> loadMonthlyTrends() async {
    // Guard: prevent concurrent loads
    if (state.isLoadingTrends) return;
    
    state = state.copyWith(isLoadingTrends: true, trendsError: null);
    try {
      final trends = await _repo.getMonthlyTrends(
        months: 12,
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        monthlyTrends: trends,
        isLoadingTrends: false,
        trendsError: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTrends: false,
        trendsError: e.toString(),
      );
    }
  }

  /// Load Sales By Channel
  Future<void> loadSalesByChannel() async {
    // Guard: prevent concurrent loads
    if (state.isLoadingChannels) return;
    
    state = state.copyWith(isLoadingChannels: true, channelsError: null);
    try {
      final channels = await _repo.getSalesByChannel(
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        salesByChannel: channels,
        isLoadingChannels: false,
        channelsError: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingChannels: false,
        channelsError: e.toString(),
      );
    }
  }

  /// GRANULAR UPDATE METHODS - True incremental updates without full refresh

  /// Update Profit Loss incrementally from sale change
  /// Handles INSERT, UPDATE, DELETE with true delta calculation (no refetch)
  void _updateProfitLossFromSale(
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
    String eventType,
  ) {
    // Guard: prevent spam loads if already loading
    if (state.isLoadingProfitLoss) {
      debugPrint('⏭️ Reports: Already loading P&L - skipping granular update');
      return;
    }
    
    // Only load full data if state is null (first load scenario)
    // This should NOT happen during real-time updates after initial load
    if (state.profitLoss == null) {
      debugPrint('⚠️ Reports: P&L state is null - performing initial load (this should be rare during real-time)');
      loadProfitLoss();
      return;
    }

    final currentPL = state.profitLoss!;
    
    // Calculate sales and COGS delta based on event type
    double salesDelta = 0.0;
    double cogsDelta = 0.0;
    
    if (eventType == 'INSERT') {
      final saleAmount = (newRecord?['final_amount'] as num?)?.toDouble() ?? 0.0;
      final saleCogs = (newRecord?['cogs'] as num?)?.toDouble();
      
      salesDelta = saleAmount;
      // Calculate COGS: use actual if available, otherwise estimate 60%
      cogsDelta = saleCogs != null && saleCogs > 0 
          ? saleCogs 
          : saleAmount * 0.6;
          
    } else if (eventType == 'DELETE') {
      final saleAmount = (oldRecord?['final_amount'] as num?)?.toDouble() ?? 0.0;
      final saleCogs = (oldRecord?['cogs'] as num?)?.toDouble();
      
      salesDelta = -saleAmount;
      // Calculate COGS: use actual if available, otherwise estimate 60%
      cogsDelta = saleCogs != null && saleCogs > 0 
          ? -saleCogs 
          : -(saleAmount * 0.6);
          
    } else if (eventType == 'UPDATE') {
      // ✅ PROPER DELTA CALCULATION: Calculate difference from old and new values
      final oldAmount = (oldRecord?['final_amount'] as num?)?.toDouble() ?? 0.0;
      final newAmount = (newRecord?['final_amount'] as num?)?.toDouble() ?? 0.0;
      final oldCogs = (oldRecord?['cogs'] as num?)?.toDouble();
      final newCogs = (newRecord?['cogs'] as num?)?.toDouble();
      
      salesDelta = newAmount - oldAmount;
      
      // Calculate COGS delta: use actual if available, otherwise estimate
      if (oldCogs != null && oldCogs > 0 && newCogs != null && newCogs > 0) {
        cogsDelta = newCogs - oldCogs;
      } else {
        // Estimate based on amount delta
        cogsDelta = salesDelta * 0.6;
      }
    }

    // Only update if there's a meaningful change
    if (salesDelta == 0.0 && cogsDelta == 0.0) {
      debugPrint('⏭️ Reports: Sale delta is 0.0 - skipping P&L update');
      return;
    }

    debugPrint('📊 Reports: Updating P&L incrementally - salesDelta: $salesDelta, cogsDelta: $cogsDelta (eventType: $eventType)');
    // Update P&L incrementally
    final newTotalSales = currentPL.totalSales + salesDelta;
    final newTotalCogs = currentPL.costOfGoodsSold + cogsDelta;
    final newGrossProfit = newTotalSales - newTotalCogs;
    final newGrossProfitMargin = newTotalSales > 0 ? (newGrossProfit / newTotalSales) * 100 : 0.0;
    final newOperatingProfit = newGrossProfit - currentPL.operatingExpenses;
    final newNetProfit = newOperatingProfit - currentPL.otherExpenses;
    final newNetProfitMargin = newTotalSales > 0 ? (newNetProfit / newTotalSales) * 100 : 0.0;

    state = state.copyWith(
      profitLoss: ProfitLossReport(
        totalSales: newTotalSales,
        costOfGoodsSold: newTotalCogs,
        grossProfit: newGrossProfit,
        operatingExpenses: currentPL.operatingExpenses,
        operatingProfit: newOperatingProfit,
        otherExpenses: currentPL.otherExpenses,
        netProfit: newNetProfit,
        grossProfitMargin: newGrossProfitMargin,
        netProfitMargin: newNetProfitMargin,
        startDate: currentPL.startDate,
        endDate: currentPL.endDate,
      ),
    );
    debugPrint('✅ Reports: P&L state updated incrementally from sale - newTotalSales: ${newTotalSales.toStringAsFixed(2)}, newNetProfit: ${newNetProfit.toStringAsFixed(2)} (NO FULL RELOAD)');
  }

  /// Update Profit Loss incrementally from expense change
  /// Handles INSERT, UPDATE, DELETE with true delta calculation (no refetch)
  void _updateProfitLossFromExpense(
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
    String eventType,
  ) {
    // Guard: prevent spam loads if already loading
    if (state.isLoadingProfitLoss) {
      debugPrint('⏭️ Reports: Already loading P&L - skipping granular expense update');
      return;
    }
    
    // Only load full data if state is null (first load scenario)
    // This should NOT happen during real-time updates after initial load
    if (state.profitLoss == null) {
      debugPrint('⚠️ Reports: P&L state is null - performing initial load (this should be rare during real-time)');
      loadProfitLoss();
      return;
    }

    final currentPL = state.profitLoss!;
    
    // Calculate expense delta based on event type
    double expenseDelta = 0.0;
    if (eventType == 'INSERT') {
      final expenseAmount = (newRecord?['amount'] as num?)?.toDouble() ?? 0.0;
      expenseDelta = expenseAmount;
    } else if (eventType == 'DELETE') {
      final expenseAmount = (oldRecord?['amount'] as num?)?.toDouble() ?? 0.0;
      expenseDelta = -expenseAmount;
    } else if (eventType == 'UPDATE') {
      // For UPDATE, calculate delta from old and new values
      final oldAmount = (oldRecord?['amount'] as num?)?.toDouble() ?? 0.0;
      final newAmount = (newRecord?['amount'] as num?)?.toDouble() ?? 0.0;
      expenseDelta = newAmount - oldAmount;
    }

    // Only update if there's a meaningful change
    if (expenseDelta == 0.0) {
      debugPrint('⏭️ Reports: Expense delta is 0.0 - skipping update');
      return;
    }

    debugPrint('📊 Reports: Updating P&L incrementally - expenseDelta: $expenseDelta (eventType: $eventType)');
    // Update P&L incrementally
    final newOperatingExpenses = currentPL.operatingExpenses + expenseDelta;
    final newOperatingProfit = currentPL.grossProfit - newOperatingExpenses;
    final newNetProfit = newOperatingProfit - currentPL.otherExpenses;
    final newNetProfitMargin = currentPL.totalSales > 0 ? (newNetProfit / currentPL.totalSales) * 100 : 0.0;

    state = state.copyWith(
      profitLoss: ProfitLossReport(
        totalSales: currentPL.totalSales,
        costOfGoodsSold: currentPL.costOfGoodsSold,
        grossProfit: currentPL.grossProfit,
        operatingExpenses: newOperatingExpenses,
        operatingProfit: newOperatingProfit,
        otherExpenses: currentPL.otherExpenses,
        netProfit: newNetProfit,
        grossProfitMargin: currentPL.grossProfitMargin,
        netProfitMargin: newNetProfitMargin,
        startDate: currentPL.startDate,
        endDate: currentPL.endDate,
      ),
    );
    debugPrint('✅ Reports: P&L state updated incrementally from expense - newOperatingExpenses: ${newOperatingExpenses.toStringAsFixed(2)}, newNetProfit: ${newNetProfit.toStringAsFixed(2)} (NO FULL RELOAD)');
  }

  /// Update Top Products incrementally from sale_item change
  /// Handles INSERT, UPDATE, DELETE with true delta calculation (no refetch)
  void _updateTopProductsFromSaleItem(
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
    String eventType,
  ) {
    // Guard: prevent spam loads if already loading
    if (state.isLoadingProducts) return;
    
    // Get product ID from either record
    final productId = (newRecord?['product_id'] ?? oldRecord?['product_id']) as String?;
    if (productId == null) return;

    // Find product in current list
    final productIndex = state.topProducts.indexWhere((p) => p.productId == productId);
    
    // Calculate deltas based on event type
    double quantityDelta = 0.0;
    double revenueDelta = 0.0;
    double profitDelta = 0.0;
    String productName = (newRecord?['product_name'] ?? oldRecord?['product_name'] ?? 'Unknown') as String;
    
    if (eventType == 'INSERT') {
      final quantity = (newRecord?['quantity'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (newRecord?['subtotal'] as num?)?.toDouble() ?? 0.0;
      final costOfGoods = (newRecord?['cost_of_goods'] as num?)?.toDouble();
      
      quantityDelta = quantity;
      revenueDelta = subtotal;
      profitDelta = costOfGoods != null && costOfGoods > 0
          ? subtotal - costOfGoods
          : subtotal * 0.4; // Estimate 40% profit margin
          
    } else if (eventType == 'DELETE') {
      final quantity = (oldRecord?['quantity'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (oldRecord?['subtotal'] as num?)?.toDouble() ?? 0.0;
      final costOfGoods = (oldRecord?['cost_of_goods'] as num?)?.toDouble();
      
      quantityDelta = -quantity;
      revenueDelta = -subtotal;
      profitDelta = costOfGoods != null && costOfGoods > 0
          ? -(subtotal - costOfGoods)
          : -(subtotal * 0.4);
          
    } else if (eventType == 'UPDATE') {
      // ✅ PROPER DELTA CALCULATION: Calculate difference from old and new values
      final oldQuantity = (oldRecord?['quantity'] as num?)?.toDouble() ?? 0.0;
      final newQuantity = (newRecord?['quantity'] as num?)?.toDouble() ?? 0.0;
      final oldSubtotal = (oldRecord?['subtotal'] as num?)?.toDouble() ?? 0.0;
      final newSubtotal = (newRecord?['subtotal'] as num?)?.toDouble() ?? 0.0;
      final oldCogs = (oldRecord?['cost_of_goods'] as num?)?.toDouble();
      final newCogs = (newRecord?['cost_of_goods'] as num?)?.toDouble();
      
      quantityDelta = newQuantity - oldQuantity;
      revenueDelta = newSubtotal - oldSubtotal;
      
      // Calculate profit delta
      double oldProfit = 0.0;
      double newProfit = 0.0;
      
      if (oldCogs != null && oldCogs > 0) {
        oldProfit = oldSubtotal - oldCogs;
      } else {
        oldProfit = oldSubtotal * 0.4;
      }
      
      if (newCogs != null && newCogs > 0) {
        newProfit = newSubtotal - newCogs;
      } else {
        newProfit = newSubtotal * 0.4;
      }
      
      profitDelta = newProfit - oldProfit;
    }

    // Only update if there's a meaningful change
    if (quantityDelta == 0.0 && revenueDelta == 0.0 && profitDelta == 0.0) return;
    
    if (productIndex != -1) {
      // Existing product: Update with deltas
      final currentProduct = state.topProducts[productIndex];
      final newTotalSold = (currentProduct.totalSold + quantityDelta).clamp(0.0, double.infinity);
      final newTotalRevenue = (currentProduct.totalRevenue + revenueDelta).clamp(0.0, double.infinity);
      final newTotalProfit = (currentProduct.totalProfit + profitDelta).clamp(0.0, double.infinity);
      final newProfitMargin = newTotalRevenue > 0 ? (newTotalProfit / newTotalRevenue) * 100 : 0.0;

      if (newTotalSold <= 0 || newTotalRevenue <= 0) {
        // Remove product from list if values become zero/negative
        final updatedProducts = List<TopProduct>.from(state.topProducts)..removeAt(productIndex);
        state = state.copyWith(topProducts: updatedProducts);
      } else {
        // Update existing product
        final updatedProducts = List<TopProduct>.from(state.topProducts);
        updatedProducts[productIndex] = TopProduct(
          productId: currentProduct.productId,
          productName: currentProduct.productName,
          totalSold: newTotalSold,
          totalRevenue: newTotalRevenue,
          totalProfit: newTotalProfit,
          profitMargin: newProfitMargin,
        );
        // Re-sort by profit
        updatedProducts.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
        state = state.copyWith(topProducts: updatedProducts);
      }
    } else {
      // New product (INSERT only) - add to list
      if (eventType == 'INSERT' && quantityDelta > 0 && revenueDelta > 0) {
        final newProduct = TopProduct(
          productId: productId,
          productName: productName,
          totalSold: quantityDelta,
          totalRevenue: revenueDelta,
          totalProfit: profitDelta,
          profitMargin: revenueDelta > 0 ? (profitDelta / revenueDelta) * 100 : 0.0,
        );
        final updatedProducts = List<TopProduct>.from(state.topProducts)..add(newProduct);
        // Re-sort and keep top 10
        updatedProducts.sort((a, b) => b.totalProfit.compareTo(a.totalProfit));
        state = state.copyWith(topProducts: updatedProducts.take(10).toList());
      }
      // UPDATE or DELETE on non-existent product: ignore (shouldn't happen in normal flow)
    }
  }

  /// Update Monthly Trends incrementally from sale/expense change
  /// 
  /// NOTE: Currently uses full recompute for trends aggregation.
  /// This is acceptable for v1 as trends are complex multi-period aggregates.
  /// 
  /// TODO (v2 optimization): Patch only affected month bucket for true incremental trends.
  /// This would require:
  /// - Extracting date from data payload
  /// - Finding corresponding MonthlyTrend entry
  /// - Updating only that period's sales/costs/profit
  /// - Recalculating growth rates if needed
  void _updateMonthlyTrendsFromData(Map<String, dynamic> data, String eventType) {
    // Guard: prevent spam loads if already loading
    if (state.isLoadingTrends) return;
    
    // For trends, we need to know the date to update specific period
    // Since trends are aggregated by period, we'll recalculate only affected period
    // For now, recalculate trends (minimal: only trends, not all data)
    loadMonthlyTrends();
  }

  /// Update Sales By Channel incrementally from sale/booking/claim change
  void _updateSalesByChannelFromData(Map<String, dynamic> data, String eventType) {
    // Determine channel from data
    String? channel = data['channel'] as String?;
    if (channel == null) {
      // Try to infer from table
      if (data.containsKey('status')) {
        // Booking or claim
        final status = data['status'] as String?;
        if (status == 'completed') {
          channel = 'booking';
        } else if (status == 'settled') {
          channel = 'consignment';
        }
      }
    }
    
    if (channel == null) {
      // Recalculate if can't determine channel
      loadSalesByChannel();
      return;
    }

    final amount = (data['final_amount'] ?? data['total_amount'] ?? data['net_amount']) as num?;
    final revenueDelta = amount?.toDouble() ?? 0.0;

    if (revenueDelta == 0.0) {
      loadSalesByChannel();
      return;
    }

    // Find channel in current list
    final channelIndex = state.salesByChannel.indexWhere((c) => c.channel == channel);
    
    // Calculate total revenue for percentage calculation
    double totalRevenue = state.salesByChannel.fold<double>(
      0.0,
      (sum, c) => sum + c.revenue,
    );

    if (eventType == 'DELETE') {
      totalRevenue -= revenueDelta;
      if (channelIndex != -1) {
        final currentChannel = state.salesByChannel[channelIndex];
        final newRevenue = (currentChannel.revenue - revenueDelta).clamp(0.0, double.infinity);
        final newTransactionCount = (currentChannel.transactionCount - 1).clamp(0, double.infinity).toInt();

        if (newRevenue <= 0 || newTransactionCount <= 0) {
          // Remove channel from list
          final updatedChannels = List<SalesByChannel>.from(state.salesByChannel)..removeAt(channelIndex);
          // Recalculate percentages
          final recalculatedChannels = updatedChannels.map((c) {
            final newTotal = updatedChannels.fold<double>(0.0, (sum, ch) => sum + ch.revenue);
            return SalesByChannel(
              channel: c.channel,
              channelLabel: c.channelLabel,
              revenue: c.revenue,
              percentage: newTotal > 0 ? (c.revenue / newTotal) * 100 : 0.0,
              transactionCount: c.transactionCount,
            );
          }).toList();
          state = state.copyWith(salesByChannel: recalculatedChannels);
        } else {
          // Update channel
          final updatedChannels = List<SalesByChannel>.from(state.salesByChannel);
          updatedChannels[channelIndex] = SalesByChannel(
            channel: currentChannel.channel,
            channelLabel: currentChannel.channelLabel,
            revenue: newRevenue,
            percentage: totalRevenue > 0 ? (newRevenue / totalRevenue) * 100 : 0.0,
            transactionCount: newTransactionCount,
          );
          // Recalculate all percentages
          final recalculatedChannels = updatedChannels.map((c) {
            final newTotal = updatedChannels.fold<double>(0.0, (sum, ch) => sum + ch.revenue);
            return SalesByChannel(
              channel: c.channel,
              channelLabel: c.channelLabel,
              revenue: c.revenue,
              percentage: newTotal > 0 ? (c.revenue / newTotal) * 100 : 0.0,
              transactionCount: c.transactionCount,
            );
          }).toList();
          state = state.copyWith(salesByChannel: recalculatedChannels);
        }
      }
    } else {
      // INSERT or UPDATE
      totalRevenue += revenueDelta;
      final transactionDelta = eventType == 'INSERT' ? 1 : 0;

      if (channelIndex != -1) {
        // Update existing channel
        final currentChannel = state.salesByChannel[channelIndex];
        final updatedChannels = List<SalesByChannel>.from(state.salesByChannel);
        updatedChannels[channelIndex] = SalesByChannel(
          channel: currentChannel.channel,
          channelLabel: currentChannel.channelLabel,
          revenue: currentChannel.revenue + revenueDelta,
          percentage: totalRevenue > 0 ? ((currentChannel.revenue + revenueDelta) / totalRevenue) * 100 : 0.0,
          transactionCount: currentChannel.transactionCount + transactionDelta,
        );
        // Recalculate all percentages
        final recalculatedChannels = updatedChannels.map((c) {
          final newTotal = updatedChannels.fold<double>(0.0, (sum, ch) => sum + ch.revenue);
          return SalesByChannel(
            channel: c.channel,
            channelLabel: c.channelLabel,
            revenue: c.revenue,
            percentage: newTotal > 0 ? (c.revenue / newTotal) * 100 : 0.0,
            transactionCount: c.transactionCount,
          );
        }).toList();
        state = state.copyWith(salesByChannel: recalculatedChannels);
      } else {
        // New channel - add to list
        final channelLabels = {
          'walk-in': 'Jualan Langsung',
          'online': 'Jualan Online',
          'delivery': 'Penghantaran',
          'booking': 'Tempahan',
          'consignment': 'Konsainan',
        };
        final newChannel = SalesByChannel(
          channel: channel,
          channelLabel: channelLabels[channel] ?? channel,
          revenue: revenueDelta,
          percentage: totalRevenue > 0 ? (revenueDelta / totalRevenue) * 100 : 0.0,
          transactionCount: transactionDelta,
        );
        final updatedChannels = List<SalesByChannel>.from(state.salesByChannel)..add(newChannel);
        // Recalculate all percentages
        final recalculatedChannels = updatedChannels.map((c) {
          final newTotal = updatedChannels.fold<double>(0.0, (sum, ch) => sum + ch.revenue);
          return SalesByChannel(
            channel: c.channel,
            channelLabel: c.channelLabel,
            revenue: c.revenue,
            percentage: newTotal > 0 ? (c.revenue / newTotal) * 100 : 0.0,
            transactionCount: c.transactionCount,
          );
        }).toList();
        state = state.copyWith(salesByChannel: recalculatedChannels);
      }
    }
  }

  /// Setup real-time subscriptions with granular event mapping using PostgresChanges
  /// Properly manages channel lifecycle to prevent memory leaks and duplicate events
  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ Reports realtime: User not authenticated');
        return;
      }

      // Create channel for reports real-time updates
      // Store channel reference for proper cleanup in dispose()
      // Note: All windows/tabs use the same channel name, so they all receive the same events
      _realtimeChannel = supabase.channel('reports_realtime_${userId.hashCode}');
      final channel = _realtimeChannel!;
      debugPrint('📡 Reports: Setting up realtime channel for instance $_instanceId');

      // Subscribe to sales - affects P&L, Top Products, Sales by Channel, Trends
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sales',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_owner_id',
          value: userId,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          // Determine event type (PostgresChanges always provides at least one record)
          String eventType = 'UPDATE';
          if (oldRecord == null) {
            eventType = 'INSERT';
          } else if (newRecord == null) {
            eventType = 'DELETE';
          }
          
          // Get data record (newRecord for INSERT/UPDATE, oldRecord for DELETE)
          final dataRecord = newRecord ?? oldRecord;
          if (dataRecord != null) {
            // ✅ CRITICAL: Check date range BEFORE updating to prevent unnecessary updates/reloads
            final saleDate = dataRecord['created_at'] as String?;
            if (saleDate != null && state.startDate != null && state.endDate != null) {
              final date = DateTime.tryParse(saleDate);
              if (date != null) {
                final saleDateTime = DateTime(date.year, date.month, date.day);
                final start = DateTime(state.startDate!.year, state.startDate!.month, state.startDate!.day);
                final end = DateTime(state.endDate!.year, state.endDate!.month, state.endDate!.day, 23, 59, 59);
                
                // Skip update if outside date range - prevents unnecessary state changes
                if (saleDateTime.isBefore(start) || saleDateTime.isAfter(end)) {
                  debugPrint('⏭️ Reports: Sale $eventType event outside date range - skipping update (no reload)');
                  return;
                }
              }
            }
            
            debugPrint('🔄 Reports: Sale $eventType event received - updating incrementally (no reload)');
            _updateProfitLossFromSale(newRecord, oldRecord, eventType);
            _updateSalesByChannelFromData(dataRecord, eventType);
            _updateMonthlyTrendsFromData(dataRecord, eventType);
            debugPrint('✅ Reports: Sale update complete - UI will rebuild automatically');
          }
        },
      );

      // Subscribe to sale_items - affects Top Products, P&L COGS
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sale_items',
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          // Determine event type (PostgresChanges always provides at least one record)
          String eventType = 'UPDATE';
          if (oldRecord == null) {
            eventType = 'INSERT';
          } else if (newRecord == null) {
            eventType = 'DELETE';
          }
          
          _updateTopProductsFromSaleItem(newRecord, oldRecord, eventType);
          // Note: COGS changes from sale_items are already reflected in sale-level COGS
          // So P&L will be updated via sales table subscription
          // No need to trigger additional P&L update here
        },
      );

      // Subscribe to bookings - affects P&L, Sales by Channel, Trends
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bookings',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_owner_id',
          value: userId,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          // Determine event type (PostgresChanges always provides at least one record)
          String eventType = 'UPDATE';
          if (oldRecord == null) {
            eventType = 'INSERT';
          } else if (newRecord == null) {
            eventType = 'DELETE';
          }
          
          // Get data record (newRecord for INSERT/UPDATE, oldRecord for DELETE)
          final dataRecord = newRecord ?? oldRecord;
          if (dataRecord != null) {
            // Only update if booking is completed
            final status = dataRecord['status'] as String?;
            if (status == 'completed' || eventType == 'DELETE') {
              // ✅ CRITICAL: Check date range BEFORE updating to prevent unnecessary updates/reloads
              final bookingDate = dataRecord['created_at'] as String?;
              if (bookingDate != null && state.startDate != null && state.endDate != null) {
                final date = DateTime.tryParse(bookingDate);
                if (date != null) {
                  final bookingDateTime = DateTime(date.year, date.month, date.day);
                  final start = DateTime(state.startDate!.year, state.startDate!.month, state.startDate!.day);
                  final end = DateTime(state.endDate!.year, state.endDate!.month, state.endDate!.day, 23, 59, 59);
                  
                  // Skip update if outside date range - prevents unnecessary state changes
                  if (bookingDateTime.isBefore(start) || bookingDateTime.isAfter(end)) {
                    debugPrint('⏭️ Reports: Booking $eventType event outside date range - skipping update (no reload)');
                    return;
                  }
                }
              }
              
              debugPrint('🔄 Reports: Booking $eventType event received - updating incrementally (no reload)');
              _updateProfitLossFromSale(newRecord, oldRecord, eventType);
              _updateSalesByChannelFromData(dataRecord, eventType);
              _updateMonthlyTrendsFromData(dataRecord, eventType);
              debugPrint('✅ Reports: Booking update complete - UI will rebuild automatically');
            }
          }
        },
      );

      // Subscribe to consignment_claims - affects P&L, Sales by Channel
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'consignment_claims',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_owner_id',
          value: userId,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          // Determine event type (PostgresChanges always provides at least one record)
          String eventType = 'UPDATE';
          if (oldRecord == null) {
            eventType = 'INSERT';
          } else if (newRecord == null) {
            eventType = 'DELETE';
          }
          
          // Get data record (newRecord for INSERT/UPDATE, oldRecord for DELETE)
          final dataRecord = newRecord ?? oldRecord;
          if (dataRecord != null) {
            // Only update if claim is settled
            final status = dataRecord['status'] as String?;
            if (status == 'settled' || eventType == 'DELETE') {
              // ✅ CRITICAL: Check date range BEFORE updating to prevent unnecessary updates/reloads
              final claimDate = dataRecord['created_at'] as String?;
              if (claimDate != null && state.startDate != null && state.endDate != null) {
                final date = DateTime.tryParse(claimDate);
                if (date != null) {
                  final claimDateTime = DateTime(date.year, date.month, date.day);
                  final start = DateTime(state.startDate!.year, state.startDate!.month, state.startDate!.day);
                  final end = DateTime(state.endDate!.year, state.endDate!.month, state.endDate!.day, 23, 59, 59);
                  
                  // Skip update if outside date range - prevents unnecessary state changes
                  if (claimDateTime.isBefore(start) || claimDateTime.isAfter(end)) {
                    debugPrint('⏭️ Reports: Claim $eventType event outside date range - skipping update (no reload)');
                    return;
                  }
                }
              }
              
              debugPrint('🔄 Reports: Claim $eventType event received - updating incrementally (no reload)');
              _updateProfitLossFromSale(newRecord, oldRecord, eventType);
              _updateSalesByChannelFromData(dataRecord, eventType);
              debugPrint('✅ Reports: Claim update complete - UI will rebuild automatically');
            }
          }
        },
      );

      // Subscribe to expenses - affects P&L, Trends
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expenses',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_owner_id',
          value: userId,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          // Determine event type (PostgresChanges always provides at least one record)
          String eventType = 'UPDATE';
          if (oldRecord == null) {
            eventType = 'INSERT';
          } else if (newRecord == null) {
            eventType = 'DELETE';
          }
          
          // Get data record (newRecord for INSERT/UPDATE, oldRecord for DELETE)
          final dataRecord = newRecord ?? oldRecord;
          if (dataRecord != null) {
            // ✅ CRITICAL: Check date range BEFORE updating to prevent unnecessary updates/reloads
            final expenseDate = dataRecord['expense_date'] as String?;
            if (expenseDate != null && state.startDate != null && state.endDate != null) {
              final date = DateTime.tryParse(expenseDate);
              if (date != null) {
                final expenseDateTime = DateTime(date.year, date.month, date.day);
                final start = DateTime(state.startDate!.year, state.startDate!.month, state.startDate!.day);
                final end = DateTime(state.endDate!.year, state.endDate!.month, state.endDate!.day, 23, 59, 59);
                
                // Debug: Log date comparison details
                debugPrint('📅 Reports: Expense date check - expenseDate: $expenseDate, parsed: $expenseDateTime');
                debugPrint('📅 Reports: Date range - start: $start, end: $end');
                debugPrint('📅 Reports: Date comparison - isBefore: ${expenseDateTime.isBefore(start)}, isAfter: ${expenseDateTime.isAfter(end)}');
                
                // Skip update if outside date range - prevents unnecessary state changes
                if (expenseDateTime.isBefore(start) || expenseDateTime.isAfter(end)) {
                  debugPrint('⏭️ Reports: Expense $eventType event outside date range - skipping update (no reload)');
                  debugPrint('📅 Reports: Expense date ($expenseDateTime) is outside range ($start to $end)');
                  return;
                } else {
                  debugPrint('✅ Reports: Expense date ($expenseDateTime) is WITHIN range ($start to $end) - proceeding with update');
                }
              } else {
                debugPrint('⚠️ Reports: Failed to parse expense_date: $expenseDate');
              }
            } else {
              debugPrint('⚠️ Reports: Missing date info - expenseDate: $expenseDate, startDate: ${state.startDate}, endDate: ${state.endDate}');
            }
            
            debugPrint('🔄 Reports: Expense $eventType event received - updating P&L incrementally (no reload)');
            _updateProfitLossFromExpense(newRecord, oldRecord, eventType);
            _updateMonthlyTrendsFromData(dataRecord, eventType);
            debugPrint('✅ Reports: P&L updated incrementally - UI will rebuild automatically');
          }
        },
      );

      // Subscribe to vendor_deliveries - affects Top Vendors
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'vendor_deliveries',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'business_owner_id',
          value: userId,
        ),
        callback: (payload) {
          // Update top vendors incrementally
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          // Determine event type (PostgresChanges always provides at least one record)
          String eventType = 'UPDATE';
          if (oldRecord == null) {
            eventType = 'INSERT';
          } else if (newRecord == null) {
            eventType = 'DELETE';
          }
          
          _updateTopVendorsFromDelivery(newRecord, oldRecord, eventType);
        },
      );

      // Subscribe to channel - CRITICAL: This activates all onPostgresChanges listeners
      channel.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('✅ Reports: Realtime channel SUBSCRIBED successfully (instance: $_instanceId)');
          debugPrint('📡 Reports: Listening for changes on: sales, sale_items, bookings, consignment_claims, expenses, vendor_deliveries');
        } else if (status == RealtimeSubscribeStatus.timedOut) {
          debugPrint('⚠️ Reports: Realtime channel subscription TIMED OUT (instance: $_instanceId)');
          debugPrint('⚠️ Reports: Real-time updates may not work. Manual refresh required.');
        } else if (status == RealtimeSubscribeStatus.channelError) {
          debugPrint('❌ Reports: Realtime channel ERROR: $error (instance: $_instanceId)');
          debugPrint('❌ Reports: Real-time updates will not work. Manual refresh required.');
        } else {
          debugPrint('🔄 Reports: Realtime channel status: $status (instance: $_instanceId)');
        }
      });
      debugPrint('✅ Reports real-time subscriptions setup complete');
      debugPrint('📡 Reports: Each browser window/tab has its own StateNotifier instance');
      debugPrint('📡 Reports: All instances subscribe to same Supabase Realtime channel');
      debugPrint('📡 Reports: When data changes, ALL windows update simultaneously via WebSocket');
      debugPrint('📡 Reports: Date range filtering applied - only events within startDate/endDate will trigger updates');
    } catch (e) {
      // Log error for debugging - realtime is optional, continue without it
      debugPrint('❌ Error setting up reports real-time subscriptions: $e');
      debugPrint('⚠️ Reports will continue without real-time updates. Manual refresh required.');
      // Continue without real-time - fallback to manual refresh
    }
  }

  /// Update Top Vendors incrementally from delivery change
  void _updateTopVendorsFromDelivery(
    Map<String, dynamic>? newRecord,
    Map<String, dynamic>? oldRecord,
    String eventType,
  ) {
    final vendorId = (newRecord?['vendor_id'] ?? oldRecord?['vendor_id']) as String?;
    final vendorName = (newRecord?['vendor_name'] ?? oldRecord?['vendor_name']) as String? ?? 'Unknown';
    final amount = ((newRecord?['total_amount'] ?? oldRecord?['total_amount']) as num?)?.toDouble() ?? 0.0;

    if (vendorId == null) return;

    final vendorIndex = state.topVendors.indexWhere((v) => v.vendorId == vendorId);

    if (eventType == 'DELETE') {
      if (vendorIndex != -1) {
        final currentVendor = state.topVendors[vendorIndex];
        final newTotalDeliveries = (currentVendor.totalDeliveries - 1).clamp(0, double.infinity).toInt();
        final newTotalAmount = (currentVendor.totalAmount - amount).clamp(0.0, double.infinity);

        if (newTotalDeliveries <= 0) {
          // Remove vendor from list
          final updatedVendors = List<TopVendor>.from(state.topVendors)..removeAt(vendorIndex);
          state = state.copyWith(topVendors: updatedVendors);
        } else {
          // Update vendor
          final updatedVendors = List<TopVendor>.from(state.topVendors);
          updatedVendors[vendorIndex] = TopVendor(
            vendorId: currentVendor.vendorId,
            vendorName: currentVendor.vendorName,
            totalDeliveries: newTotalDeliveries,
            totalAmount: newTotalAmount,
          );
          // Re-sort by amount
          updatedVendors.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
          state = state.copyWith(topVendors: updatedVendors);
        }
      }
    } else {
      // INSERT or UPDATE
      if (vendorIndex != -1) {
        // Update existing vendor
        final currentVendor = state.topVendors[vendorIndex];
        final deliveriesDelta = eventType == 'INSERT' ? 1 : 0;
        final amountDelta = eventType == 'INSERT' ? amount : 0.0;

        final updatedVendors = List<TopVendor>.from(state.topVendors);
        updatedVendors[vendorIndex] = TopVendor(
          vendorId: currentVendor.vendorId,
          vendorName: currentVendor.vendorName,
          totalDeliveries: currentVendor.totalDeliveries + deliveriesDelta,
          totalAmount: currentVendor.totalAmount + amountDelta,
        );
        // Re-sort by amount
        updatedVendors.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        state = state.copyWith(topVendors: updatedVendors);
      } else {
        // New vendor - add to list
        final newVendor = TopVendor(
          vendorId: vendorId,
          vendorName: vendorName,
          totalDeliveries: 1,
          totalAmount: amount,
        );
        final updatedVendors = List<TopVendor>.from(state.topVendors)..add(newVendor);
        // Re-sort and keep top 10
        updatedVendors.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        state = state.copyWith(topVendors: updatedVendors.take(10).toList());
      }
    }
  }

  // Note: _updateProfitLossFromSaleItem removed
  // COGS changes from sale_items are already reflected in sale-level COGS field
  // P&L updates are handled via sales table subscription with proper delta calculation
}

/// Provider for Reports Repository
final reportsRepositoryProvider = Provider<ReportsRepositorySupabase>((ref) {
  return ReportsRepositorySupabase();
});

/// Provider for Reports State Notifier
final reportsStateNotifierProvider = StateNotifierProvider<ReportsStateNotifier, ReportsState>((ref) {
  final repo = ref.watch(reportsRepositoryProvider);
  return ReportsStateNotifier(repo);
});
