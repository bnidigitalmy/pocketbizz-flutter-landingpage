import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/supabase/supabase_client.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../data/models/consignment_claim.dart';
import '../../reports/data/repositories/reports_repository_supabase.dart';
import '../domain/sme_dashboard_v2_models.dart';

/// SME Dashboard V2 data loader.
///
/// Goals:
/// - Keep "accounting-lite": profit = Masuk - Belanja (no COGS).
/// - Week is Ahad–Sabtu.
/// - Top products are cross-channel and grouped by normalized product_name.
/// - Avoid modifying stable core modules; this is a thin wrapper/aggregator.
class SmeDashboardV2Service {
  final _salesRepo = SalesRepositorySupabase();
  final _bookingsRepo = BookingsRepositorySupabase();
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
      _loadExpenseTotal(startLocal: todayStartLocal, endLocalExclusive: todayEndLocal),
      _loadInflowTotal(startUtc: weekStartUtc, endUtc: weekEndUtc),
      _loadExpenseTotal(startLocal: weekStartLocal, endLocalExclusive: weekEndLocal),
      _loadTopProducts(
        todayStartUtc: todayStartUtc,
        todayEndUtc: todayEndUtc,
        weekStartUtc: weekStartUtc,
        weekEndUtc: weekEndUtc,
      ),
    ]);

    final todayInflowAndTx = results[0] as _InflowAndTransactions;
    final todayExpense = results[1] as double;
    final weekInflow = results[2] as double;
    final weekExpense = results[3] as double;
    final topProducts = results[4] as DashboardTopProducts;

    final todayProfit = todayInflowAndTx.inflow - todayExpense;
    final weekNet = weekInflow - weekExpense;

    final productionSuggestion = _buildProductionSuggestion(
      topProducts: topProducts,
      todayInflow: todayInflowAndTx.inflow,
      weekNet: weekNet,
    );

    return SmeDashboardV2Data(
      today: DashboardMoneySummary(
        inflow: todayInflowAndTx.inflow,
        expense: todayExpense,
        profit: todayProfit,
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
    // Transactions count is: sales count + completed bookings count (claims are not treated as a transaction here).
    double inflow = 0.0;
    int tx = 0;

    try {
      final sales = await _salesRepo.listSales(
        startDate: startUtc,
        endDate: endUtc,
        limit: 500,
      );
      inflow += sales.fold<double>(0.0, (sum, s) => sum + s.finalAmount);
      tx += sales.length;
    } catch (e) {
      debugPrint('SmeDashboardV2Service: failed to load sales inflow: $e');
    }

    try {
      // We only have listBookings(status, limit) in stable repo.
      // Fetch a bounded window and filter in-memory by createdAt.
      final completedBookings = await _bookingsRepo.listBookings(
        status: 'completed',
        limit: 300,
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
        limit: 200,
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


