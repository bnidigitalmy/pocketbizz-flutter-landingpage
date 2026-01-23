import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/supabase/supabase_client.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/bookings_repository_supabase_cached.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../data/models/consignment_claim.dart';
import '../../reports/data/repositories/reports_repository_supabase.dart';
import '../domain/sme_dashboard_v2_models.dart';

/// SME Dashboard V2 data loader.
///
/// Goals:
/// - Accurate profit calculation: profit = Jualan - Kos Pengeluaran (COGS).
/// - Kos Pengeluaran = kos untuk produk yang dijual (quantity * cost_per_unit).
/// - Week is Ahad–Sabtu.
/// - Top products are cross-channel and grouped by normalized product_name.
/// - Avoid modifying stable core modules; this is a thin wrapper/aggregator.
class SmeDashboardV2Service {
  final _salesRepo = SalesRepositorySupabase();
  final _bookingsRepo = BookingsRepositorySupabaseCached();
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _reportsRepo = ReportsRepositorySupabase();

  /// Load all SME dashboard V2 data.
  Future<SmeDashboardV2Data> load() async {
    final now = DateTime.now();

    // Today range (local day boundaries converted to UTC for timestamptz filters).
    final todayStartLocal = DateTime(now.year, now.month, now.day);
    final todayEndLocal = todayStartLocal.add(const Duration(days: 1));
    final todayStartUtc = todayStartLocal.toUtc();
    final todayEndUtc = todayEndLocal.toUtc();

    // Week range (Ahad–Sabtu), computed in local time.
    final weekStartLocal = _startOfWeekSunday(now);
    final weekEndLocal = weekStartLocal.add(const Duration(days: 7));
    final weekStartUtc = weekStartLocal.toUtc();
    final weekEndUtc = weekEndLocal.toUtc();

    final results = await Future.wait([
      _loadInflowAndTransactions(startUtc: todayStartUtc, endUtc: todayEndUtc),
      _loadProductionCost(startUtc: todayStartUtc, endUtc: todayEndUtc),
      _loadExpenseTotal(startLocal: todayStartLocal, endLocalExclusive: todayEndLocal),
      _loadInflowTotal(startUtc: weekStartUtc, endUtc: weekEndUtc),
      _loadProductionCost(startUtc: weekStartUtc, endUtc: weekEndUtc),
      _loadExpenseTotal(startLocal: weekStartLocal, endLocalExclusive: weekEndLocal),
      _loadTopProducts(
        todayStartUtc: todayStartUtc,
        todayEndUtc: todayEndUtc,
        weekStartUtc: weekStartUtc,
        weekEndUtc: weekEndUtc,
      ),
    ]);

    final todayInflowAndTx = results[0] as _InflowAndTransactions;
    final todayProductionCost = results[1] as double;
    final todayExpense = results[2] as double;
    final weekInflow = results[3] as double;
    final weekProductionCost = results[4] as double;
    final weekExpense = results[5] as double;
    final topProducts = results[6] as DashboardTopProducts;

    // FIX: Untung = Jualan - Kos Pengeluaran (bukan Masuk - Belanja)
    // Kos Pengeluaran = kos untuk produk yang dijual hari ini
    final todayProfit = todayInflowAndTx.inflow - todayProductionCost;
    final weekNet = weekInflow - weekProductionCost;

    final productionSuggestion = _buildProductionSuggestion(
      topProducts: topProducts,
      todayInflow: todayInflowAndTx.inflow,
      weekNet: weekNet,
    );

    return SmeDashboardV2Data(
      today: DashboardMoneySummary(
        inflow: todayInflowAndTx.inflow,
        productionCost: todayProductionCost,
        profit: todayProfit,
        expense: todayExpense,
        transactions: todayInflowAndTx.transactions,
      ),
      week: DashboardCashflowWeekly(
        inflow: weekInflow,
        expense: weekExpense,
        net: weekNet,
      ),
      topProducts: topProducts,
      productionSuggestion: productionSuggestion,
    );
  }

  DateTime _startOfWeekSunday(DateTime dateLocal) {
    // Dart: Monday=1..Sunday=7. We want Sunday start.
    // For Sunday (7): 7 % 7 = 0 days back.
    final daysBack = dateLocal.weekday % 7;
    final d = dateLocal.subtract(Duration(days: daysBack));
    return DateTime(d.year, d.month, d.day);
  }

  Future<_InflowAndTransactions> _loadInflowAndTransactions({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    // "Masuk" is cross-channel: direct sales + completed bookings + settled claims (net_amount).
    // IMPORTANT: Use same calculation method as getSalesByChannel to ensure exact match
    // This ensures "Hari Ini" card matches "Jualan Mengikut Saluran" total exactly
    
    // Use getSalesByChannel to get the exact same calculation
    try {
      final channels = await _reportsRepo.getSalesByChannel(
        startDate: startUtc,
        endDate: endUtc,
      );
      
      // Sum all channel revenues to get total inflow (exact match with Sales by Channel)
      // Round to 2 decimal places to match database NUMERIC(12,2) precision
      final totalInflow = (channels.fold<double>(0.0, (sum, c) => sum + c.revenue) * 100).round() / 100;
      
      // Count transactions: sum of all channel transaction counts
      final totalTx = channels.fold<int>(0, (sum, c) => sum + c.transactionCount);
      
      return _InflowAndTransactions(inflow: totalInflow, transactions: totalTx);
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to load inflow via getSalesByChannel: $e');
      // Fallback to original method if getSalesByChannel fails
      return await _loadInflowAndTransactionsFallback(startUtc: startUtc, endUtc: endUtc);
    }
  }

  /// Fallback method using original calculation logic
  Future<_InflowAndTransactions> _loadInflowAndTransactionsFallback({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    double inflow = 0.0;
    int tx = 0;

    try {
      final sales = await _salesRepo.listSales(
        startDate: startUtc,
        endDate: endUtc,
        limit: 10000,
      );
      inflow += sales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
      tx += sales.length;
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to load sales inflow: $e');
    }

    try {
      final completedBookings = await _bookingsRepo.listBookings(
        status: 'completed',
        limit: 10000,
      );
      final inRange = completedBookings.where((b) {
        final tUtc = b.createdAt.toUtc();
        return tUtc.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
            tUtc.isBefore(endUtc);
      }).toList();
      inflow += inRange.fold<double>(0.0, (sum, b) => sum + b.totalAmount);
      tx += inRange.length;
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to load booking inflow: $e');
    }

    try {
      final resp = await _claimsRepo.listClaims(
        fromDate: startUtc,
        toDate: endUtc,
        status: ClaimStatus.settled,
        limit: 10000,
      );
      final claims = (resp['data'] as List).whereType<ConsignmentClaim>().toList();
      inflow += claims.fold<double>(0.0, (sum, c) => sum + c.netAmount);
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to load consignment inflow: $e');
    }

    return _InflowAndTransactions(inflow: inflow, transactions: tx);
  }

  Future<double> _loadInflowTotal({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    // For week, prefer existing report aggregation for sales-by-channel (already combines sources),
    // but we only need total inflow.
    try {
      final channels = await _reportsRepo.getSalesByChannel(
        startDate: startUtc,
        endDate: endUtc,
      );
      return channels.fold<double>(0.0, (sum, c) => sum + c.revenue);
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to load weekly inflow via reports: $e');
    }

    // Fallback: reuse inflow loader without tx.
    final r = await _loadInflowAndTransactions(startUtc: startUtc, endUtc: endUtc);
    return r.inflow;
  }

  Future<double> _loadExpenseTotal({
    required DateTime startLocal,
    required DateTime endLocalExclusive,
  }) async {
    // expenses.expense_date is DATE (stored as yyyy-MM-dd string in app). Filter by date strings.
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0.0;

    final startDateStr = _dateOnly(startLocal);
    // endLocalExclusive is next day at 00:00; inclusive end date is previous day.
    final endInclusive = endLocalExclusive.subtract(const Duration(days: 1));
    final endDateStr = _dateOnly(endInclusive);

    try {
      final rows = await supabase
          .from('expenses')
          .select('amount, expense_date')
          .eq('business_owner_id', userId)
          .gte('expense_date', startDateStr)
          .lte('expense_date', endDateStr);

      double total = 0.0;
      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        total += (r['amount'] as num?)?.toDouble() ?? 0.0;
      }
      return total;
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to load expenses total: $e');
      return 0.0;
    }
  }

  String _dateOnly(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Calculate production cost for products sold in the given time range
  /// Production Cost = Sum(quantity * cost_per_unit) for all sold items
  /// This is the actual cost of goods sold (COGS) for products
  /// Optimized: Bulk load all product costs at once to avoid N+1 queries
  Future<double> _loadProductionCost({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    double totalCost = 0.0;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0.0;

    // Collect all items data and product IDs in parallel
    final List<Map<String, dynamic>> allItems = [];
    final Set<String> productIds = {};

    // Load all items in parallel
    final results = await Future.wait([
      // 1. Sales items
      supabase
          .from('sale_items')
          .select('quantity, product_id, sales!inner(created_at)')
          .eq('sales.business_owner_id', userId)
          .gte('sales.created_at', startUtc.toIso8601String())
          .lt('sales.created_at', endUtc.toIso8601String())
          .limit(2000)
          .then((data) => (data as List).cast<Map<String, dynamic>>())
          .catchError((e) {
            debugPrint('SmeDashboardV2Service: failed to load sales items: $e');
            return <Map<String, dynamic>>[];
          }),
      
      // 2. Booking items
      supabase
          .from('booking_items')
          .select('quantity, product_id, bookings!inner(status, created_at, business_owner_id)')
          .eq('bookings.status', 'completed')
          .eq('bookings.business_owner_id', userId)
          .gte('bookings.created_at', startUtc.toIso8601String())
          .lt('bookings.created_at', endUtc.toIso8601String())
          .limit(2000)
          .then((data) => (data as List).cast<Map<String, dynamic>>())
          .catchError((e) {
            debugPrint('SmeDashboardV2Service: failed to load booking items: $e');
            return <Map<String, dynamic>>[];
          }),
      
      // 3. Consignment claim items
      () async {
        try {
          final startLocal = startUtc.toLocal();
          final endLocalExclusive = endUtc.toLocal();
          final startDateStr = _dateOnly(startLocal);
          final endDateStr = _dateOnly(endLocalExclusive.subtract(const Duration(days: 1)));

          final data = await supabase
              .from('consignment_claim_items')
              .select('''
                quantity_sold,
                delivery_item:vendor_delivery_items(product_id),
                claim:consignment_claims!inner(status, claim_date, business_owner_id)
              ''')
              .eq('claim.status', 'settled')
              .eq('claim.business_owner_id', userId)
              .gte('claim.claim_date', startDateStr)
              .lte('claim.claim_date', endDateStr)
              .limit(2000);
          return (data as List).cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('SmeDashboardV2Service: failed to load consignment items: $e');
          return <Map<String, dynamic>>[];
        }
      }(),
    ]);

    final salesItems = results[0] as List<Map<String, dynamic>>;
    final bookingItems = results[1] as List<Map<String, dynamic>>;
    final claimItems = results[2] as List<Map<String, dynamic>>;

    // Collect product IDs from all items
    for (final item in salesItems) {
      final productId = item['product_id'] as String?;
      if (productId != null) {
        productIds.add(productId);
        allItems.add({'type': 'sale', 'item': item});
      }
    }

    for (final item in bookingItems) {
      final productId = item['product_id'] as String?;
      if (productId != null) {
        productIds.add(productId);
        allItems.add({'type': 'booking', 'item': item});
      }
    }

    for (final item in claimItems) {
      final deliveryItem = item['delivery_item'];
      String? productId;
      if (deliveryItem is Map<String, dynamic>) {
        productId = deliveryItem['product_id'] as String?;
      }
      if (productId != null) {
        productIds.add(productId);
        allItems.add({'type': 'claim', 'item': item});
      }
    }

    // Bulk load all product costs at once (optimization: single query instead of N queries)
    final Map<String, double> productCostCache = {};
    if (productIds.isNotEmpty) {
      try {
        final products = await supabase
            .from('products')
            .select('id, cost_per_unit, cost_price')
            .eq('business_owner_id', userId)
            .inFilter('id', productIds.toList());

        for (final product in (products as List).cast<Map<String, dynamic>>()) {
          final id = product['id'] as String;
          final costPerUnit = (product['cost_per_unit'] as num?)?.toDouble();
          final costPrice = (product['cost_price'] as num?)?.toDouble() ?? 0.0;
          // Use cost_per_unit if available, otherwise fallback to cost_price
          productCostCache[id] = costPerUnit != null ? costPerUnit : costPrice;
        }
      } catch (e) {
        debugPrint('SmeDashboardV2Service: failed to bulk load product costs: $e');
        // Fallback: load costs one by one if bulk load fails
        for (final productId in productIds) {
          if (!productCostCache.containsKey(productId)) {
            productCostCache[productId] = await _getProductCostPerUnit(productId);
          }
        }
      }
    }

    // Calculate total cost using cached values
    for (final entry in allItems) {
      final type = entry['type'] as String;
      final item = entry['item'] as Map<String, dynamic>;
      
      String? productId;
      double quantity = 0.0;

      if (type == 'sale') {
        productId = item['product_id'] as String?;
        quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      } else if (type == 'booking') {
        productId = item['product_id'] as String?;
        quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      } else if (type == 'claim') {
        final deliveryItem = item['delivery_item'];
        if (deliveryItem is Map<String, dynamic>) {
          productId = deliveryItem['product_id'] as String?;
        }
        quantity = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
      }

      if (productId != null && quantity > 0) {
        final cost = productCostCache[productId] ?? 0.0;
        totalCost += quantity * cost;
      }
    }

    return totalCost;
  }

  /// Get product cost_per_unit from products table
  /// Falls back to cost_price if cost_per_unit is null
  Future<double> _getProductCostPerUnit(String productId) async {
    try {
      final product = await supabase
          .from('products')
          .select('cost_per_unit, cost_price')
          .eq('id', productId)
          .single();

      if (product == null) return 0.0;

      final costPerUnit = (product['cost_per_unit'] as num?)?.toDouble();
      final costPrice = (product['cost_price'] as num?)?.toDouble() ?? 0.0;

      // Use cost_per_unit if available (includes packaging), otherwise fallback to cost_price
      return costPerUnit ?? costPrice;
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to get product cost for $productId: $e');
      return 0.0;
    }
  }

  Future<DashboardTopProducts> _loadTopProducts({
    required DateTime todayStartUtc,
    required DateTime todayEndUtc,
    required DateTime weekStartUtc,
    required DateTime weekEndUtc,
  }) async {
    final today = await _loadTopProductUnitsForRange(
      startUtc: todayStartUtc,
      endUtc: todayEndUtc,
    );
    final week = await _loadTopProductUnitsForRange(
      startUtc: weekStartUtc,
      endUtc: weekEndUtc,
    );
    return DashboardTopProducts(
      todayTop3: today,
      weekTop3: week,
    );
  }

  Future<List<TopProductUnits>> _loadTopProductUnitsForRange({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final Map<String, _UnitsAgg> map = {};

    await Future.wait([
      _accumulateFromSalesItems(map: map, startUtc: startUtc, endUtc: endUtc),
      _accumulateFromBookingItems(map: map, startUtc: startUtc, endUtc: endUtc),
      _accumulateFromSettledConsignment(map: map, startUtc: startUtc, endUtc: endUtc),
    ]);

    final list = map.values
        .map(
          (v) => TopProductUnits(key: v.key, displayName: v.displayName, units: v.units),
        )
        .toList()
      ..sort((a, b) => b.units.compareTo(a.units));

    return list.take(3).toList();
  }

  Future<void> _accumulateFromSalesItems({
    required Map<String, _UnitsAgg> map,
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    try {
      // Pull items joined to sales for time range.
      final rows = await supabase
          .from('sale_items')
          .select('quantity, product_name, sales!inner(created_at)')
          .gte('sales.created_at', startUtc.toIso8601String())
          .lt('sales.created_at', endUtc.toIso8601String())
          .limit(2000);

      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final name = (r['product_name'] as String?) ?? '';
        final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;
        _addUnits(map: map, productName: name, units: qty);
      }
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed sales top products: $e');
    }
  }

  Future<void> _accumulateFromBookingItems({
    required Map<String, _UnitsAgg> map,
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    try {
      // Only include completed bookings.
      final rows = await supabase
          .from('booking_items')
          .select('quantity, product_name, bookings!inner(status, created_at)')
          .eq('bookings.status', 'completed')
          .gte('bookings.created_at', startUtc.toIso8601String())
          .lt('bookings.created_at', endUtc.toIso8601String())
          .limit(2000);

      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final name = (r['product_name'] as String?) ?? '';
        final qty = (r['quantity'] as num?)?.toDouble() ?? 0.0;
        _addUnits(map: map, productName: name, units: qty);
      }
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed bookings top products: $e');
    }
  }

  Future<void> _accumulateFromSettledConsignment({
    required Map<String, _UnitsAgg> map,
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    // Claims use claim_date (DATE), not created_at. Use local date strings.
    final startLocal = startUtc.toLocal();
    final endLocalExclusive = endUtc.toLocal();
    final startDateStr = _dateOnly(startLocal);
    final endDateStr = _dateOnly(endLocalExclusive.subtract(const Duration(days: 1)));

    try {
      final rows = await supabase
          .from('consignment_claim_items')
          .select('''
            quantity_sold,
            claim:consignment_claims!inner(status, claim_date),
            delivery_item:vendor_delivery_items(product_name)
          ''')
          .eq('claim.status', 'settled')
          .gte('claim.claim_date', startDateStr)
          .lte('claim.claim_date', endDateStr)
          .limit(2000);

      for (final r in (rows as List).cast<Map<String, dynamic>>()) {
        final qty = (r['quantity_sold'] as num?)?.toDouble() ?? 0.0;
        final deliveryItem = r['delivery_item'];
        final name = deliveryItem is Map<String, dynamic>
            ? (deliveryItem['product_name'] as String?) ?? ''
            : '';
        _addUnits(map: map, productName: name, units: qty);
      }
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed consignment top products: $e');
    }
  }

  void _addUnits({
    required Map<String, _UnitsAgg> map,
    required String productName,
    required double units,
  }) {
    final normalized = _normalizeProductName(productName);
    if (normalized.isEmpty || units <= 0) return;

    final existing = map[normalized];
    if (existing != null) {
      existing.units += units;
      // Prefer a "nicer" display name if current is empty.
      if (existing.displayName.isEmpty && productName.trim().isNotEmpty) {
        existing.displayName = productName.trim();
      }
      return;
    }

    map[normalized] = _UnitsAgg(
      key: normalized,
      displayName: productName.trim(),
      units: units,
    );
  }

  String _normalizeProductName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    // Normalize: trim, lowercase, collapse spaces.
    final lowered = trimmed.toLowerCase();
    final collapsed = lowered.replaceAll(RegExp(r'\s+'), ' ');
    return collapsed;
  }

  DashboardProductionSuggestion _buildProductionSuggestion({
    required DashboardTopProducts topProducts,
    required double todayInflow,
    required double weekNet,
  }) {
    // Rule-based, non-AI.
    // MVP logic:
    // - If there is a clear top product for the week, suggest production.
    // - If week net is negative, we keep tone supportive and action-oriented.
    final topWeek = topProducts.weekTop3;
    if (topWeek.isEmpty) {
      return const DashboardProductionSuggestion(
        show: false,
        title: '',
        message: '',
      );
    }

    final top = topWeek.first;
    final name = top.displayName.isNotEmpty ? top.displayName : top.key;

    if (top.units < 3) {
      return const DashboardProductionSuggestion(show: false, title: '', message: '');
    }

    final title = 'Cadangan Produksi Hari Ini';
    final message = weekNet < 0
        ? 'Produk "$name" paling laku minggu ini. Buat batch kecil hari ini untuk naikkan sales.'
        : 'Produk "$name" paling laku minggu ini. Disyorkan buat batch hari ini supaya stok cukup.';

    return DashboardProductionSuggestion(show: true, title: title, message: message);
  }
}

class _UnitsAgg {
  final String key;
  String displayName;
  double units;

  _UnitsAgg({
    required this.key,
    required this.displayName,
    required this.units,
  });
}

class _InflowAndTransactions {
  final double inflow;
  final int transactions;

  _InflowAndTransactions({
    required this.inflow,
    required this.transactions,
  });
}


