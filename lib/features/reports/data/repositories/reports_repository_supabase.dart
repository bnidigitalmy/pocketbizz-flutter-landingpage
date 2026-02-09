/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:intl/intl.dart';

import '../../../../core/supabase/supabase_client.dart';
import '../../../../data/repositories/expenses_repository_supabase.dart';
import '../../../../data/repositories/sales_repository_supabase.dart';
import '../../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../../data/repositories/bookings_repository_supabase.dart';
import '../../../../data/models/consignment_claim.dart';
import '../models/profit_loss_report.dart';
import '../models/top_product.dart';
import '../models/top_vendor.dart';
import '../models/monthly_trend.dart';
import '../models/sales_by_channel.dart';

/// Reports Repository for Supabase
/// Handles all data aggregation for reports
class ReportsRepositorySupabase {
  // Constants for COGS estimation (fallback when actual COGS not available)
  // These are used when products don't have actual cost data recorded
  double _cogsPercentage = 0.6; // 60% of revenue as COGS (configurable)
  double _profitMargin = 0.4; // 40% profit margin (configurable)
  static const int _maxQueryLimit = 10000; // Safety cap per query

  final _salesRepo = SalesRepositorySupabase();
  final _expensesRepo = ExpensesRepositorySupabase();
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _bookingsRepo = BookingsRepositorySupabase();

  /// Configure COGS estimation percentage (0.0 to 1.0)
  /// Use this when business has a known average COGS ratio
  void setCogsPercentage(double percentage) {
    _cogsPercentage = percentage.clamp(0.0, 1.0);
    _profitMargin = 1.0 - _cogsPercentage;
  }

  /// Get Profit & Loss Report
  Future<ProfitLossReport> getProfitLossReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Default to current month if no dates provided
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Get sales in date range
    final sales = await _salesRepo.listSales(
      startDate: start,
      endDate: end,
      limit: _maxQueryLimit,
    );

    // Calculate total sales (including consignment revenue)
    final directSales = sales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.finalAmount,
    );

    // Get settled claims for consignment revenue (server-side filter)
    final settledClaimsResponse = await _claimsRepo.listClaims(
      fromDate: start,
      toDate: end,
      status: ClaimStatus.settled,
      limit: _maxQueryLimit,
    );
    final settledClaims = (settledClaimsResponse['data'] as List).cast<ConsignmentClaim>();

    final consignmentRevenue = settledClaims.fold<double>(
      0.0,
      (sum, claim) => sum + claim.netAmount,
    );

    // Get booking revenue (total_amount from completed bookings)
    final completedBookings = await _bookingsRepo.listBookings(
      status: 'completed',
      limit: 10000,
    );

    // Filter bookings by date range
    // Convert start and end to UTC for comparison (booking.createdAt is in UTC)
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();
    final bookingsInRange = completedBookings.where((booking) {
      final bookingDateUtc = booking.createdAt.toUtc();
      return !bookingDateUtc.isBefore(startUtc) &&
          !bookingDateUtc.isAfter(endUtc);
    }).toList();

    final bookingRevenue = bookingsInRange.fold<double>(
      0.0,
      (sum, booking) => sum + booking.totalAmount,
    );

    // Total sales = Direct sales + Consignment revenue + Booking revenue
    final totalSales = directSales + consignmentRevenue + bookingRevenue;

    // Calculate total COGS from sales
    // Priority: Use sale.cogs if available, otherwise sum from sale_items.cost_of_goods
    // Fallback: Estimate 60% if no COGS data available
    double totalCogs = 0.0;
    for (final sale in sales) {
      // First priority: Use sale-level COGS if available
      if (sale.cogs != null && sale.cogs! > 0) {
        totalCogs += sale.cogs!;
      } else if (sale.items != null && sale.items!.isNotEmpty) {
        // Second priority: Sum COGS from sale items
        double itemCogs = 0.0;
        for (final item in sale.items!) {
          if (item.costOfGoods != null && item.costOfGoods! > 0) {
            itemCogs += item.costOfGoods!;
          }
        }
        if (itemCogs > 0) {
          totalCogs += itemCogs;
        } else {
          // Fallback: Estimate using default percentage if no actual data
          totalCogs += sale.finalAmount * _cogsPercentage;
        }
      } else {
        // Fallback: Estimate using default percentage if no items
        totalCogs += sale.finalAmount * _cogsPercentage;
      }
    }

    // Get expenses in date range (inclusive boundaries)
    final expenses = await _expensesRepo.getExpenses();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final expensesInRange = expenses.where((e) {
      return !e.expenseDate.isBefore(startDay) &&
          !e.expenseDate.isAfter(endDay);
    }).toList();

    final totalExpenses = expensesInRange.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    // Total costs = COGS + Expenses
    final totalCosts = totalCogs + totalExpenses;

    // Get rejected claims for rejection loss (server-side filter)
    final rejectedClaimsResponse = await _claimsRepo.listClaims(
      fromDate: start,
      toDate: end,
      status: ClaimStatus.rejected,
      limit: _maxQueryLimit,
    );
    final rejectedClaims = (rejectedClaimsResponse['data'] as List).cast<ConsignmentClaim>();

    final rejectionLoss = rejectedClaims.fold<double>(
      0.0,
      (sum, claim) {
        // Rejection loss = cost to business (vendor's portion), not full selling price
        // netAmount = vendor's share (grossAmount - commissionAmount)
        // This represents the actual cost/loss, not the revenue that was never earned
        return sum + claim.netAmount;
      },
    );

    // Standard P&L Format:
    // Revenue -> COGS -> Gross Profit -> Operating Expenses -> Operating Profit -> Other Expenses -> Net Profit
    
    // Calculate Gross Profit
    final grossProfit = totalSales - totalCogs;
    
    // Calculate Operating Profit (EBIT) = Gross Profit - Operating Expenses
    final operatingProfit = grossProfit - totalExpenses;
    
    // Calculate Net Profit = Operating Profit - Other Expenses (Rejection Loss)
    final netProfit = operatingProfit - rejectionLoss;

    // Calculate profit margins
    final grossProfitMargin = totalSales > 0 ? (grossProfit / totalSales) * 100 : 0.0;
    final netProfitMargin = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

    return ProfitLossReport(
      totalSales: totalSales,
      costOfGoodsSold: totalCogs,
      grossProfit: grossProfit,
      operatingExpenses: totalExpenses,
      operatingProfit: operatingProfit,
      otherExpenses: rejectionLoss,
      netProfit: netProfit,
      grossProfitMargin: grossProfitMargin,
      netProfitMargin: netProfitMargin,
      startDate: start,
      endDate: end,
    );
  }

  /// Get Top Products by Profit
  Future<List<TopProduct>> getTopProducts({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get sales in date range
    final sales = await _salesRepo.listSales(
      startDate: startDate,
      endDate: endDate,
      limit: 10000,
    );

    // Group sale items by product
    final productMap = <String, Map<String, dynamic>>{};

    for (final sale in sales) {
      if (sale.items != null) {
        for (final item in sale.items!) {
          final productId = item.productId;
          if (!productMap.containsKey(productId)) {
            productMap[productId] = {
              'productId': productId,
              'productName': item.productName,
              'totalSold': 0.0,
              'totalRevenue': 0.0,
              'totalProfit': 0.0,
            };
          }

          final product = productMap[productId]!;
          product['totalSold'] = (product['totalSold'] as double) + item.quantity;
          product['totalRevenue'] =
              (product['totalRevenue'] as double) + item.subtotal;

          // Calculate actual profit: Use costOfGoods if available, otherwise estimate
          double itemProfit;
          if (item.costOfGoods != null && item.costOfGoods! > 0) {
            // Use actual COGS
            itemProfit = item.subtotal - item.costOfGoods!;
          } else {
            // Fallback: Estimate using default profit margin
            itemProfit = item.subtotal * _profitMargin;
          }
          product['totalProfit'] =
              (product['totalProfit'] as double) + itemProfit;
        }
      }
    }

    // Convert to TopProduct list and sort by profit
    final topProducts = productMap.values
        .map((p) => TopProduct(
              productId: p['productId'] as String,
              productName: p['productName'] as String,
              totalSold: p['totalSold'] as double,
              totalRevenue: p['totalRevenue'] as double,
              totalProfit: p['totalProfit'] as double,
              profitMargin: p['totalRevenue'] > 0
                  ? (p['totalProfit'] as double) / (p['totalRevenue'] as double) * 100
                  : 0.0,
            ))
        .toList()
      ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    return topProducts.take(limit).toList();
  }

  /// Get Top Vendors by Activity
  Future<List<TopVendor>> getTopVendors({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Get vendor deliveries
    var query = supabase
        .from('vendor_deliveries')
        .select('vendor_id, vendor_name, total_amount')
        .eq('business_owner_id', userId);

    if (startDate != null) {
      query = query.gte('delivery_date', startDate.toIso8601String().split('T')[0]);
    }
    if (endDate != null) {
      query = query.lte('delivery_date', endDate.toIso8601String().split('T')[0]);
    }

    final deliveries = await query;

    // Group by vendor
    final vendorMap = <String, Map<String, dynamic>>{};

    for (final delivery in deliveries as List) {
      final vendorId = delivery['vendor_id'] as String;
      final vendorName = delivery['vendor_name'] as String? ?? 'Unknown';
      final amount = (delivery['total_amount'] as num?)?.toDouble() ?? 0.0;

      if (!vendorMap.containsKey(vendorId)) {
        vendorMap[vendorId] = {
          'vendorId': vendorId,
          'vendorName': vendorName,
          'totalDeliveries': 0,
          'totalAmount': 0.0,
        };
      }

      final vendor = vendorMap[vendorId]!;
      vendor['totalDeliveries'] = (vendor['totalDeliveries'] as int) + 1;
      vendor['totalAmount'] = (vendor['totalAmount'] as double) + amount;
    }

    // Convert to TopVendor list and sort by total amount
    final topVendors = vendorMap.values
        .map((v) => TopVendor(
              vendorId: v['vendorId'] as String,
              vendorName: v['vendorName'] as String,
              totalDeliveries: v['totalDeliveries'] as int,
              totalAmount: v['totalAmount'] as double,
            ))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return topVendors.take(limit).toList();
  }

  /// Get Monthly Trends
  /// If startDate and endDate provided, use them; otherwise use last N months
  Future<List<MonthlyTrend>> getMonthlyTrends({
    int months = 12,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Calculate date range
    final now = DateTime.now();
    DateTime rangeStart;
    DateTime rangeEnd;
    
    if (startDate != null && endDate != null) {
      // Use provided date range
      rangeStart = startDate;
      rangeEnd = endDate;
    } else {
      // Default to last N months
      rangeStart = DateTime(now.year, now.month - months + 1, 1);
      rangeEnd = now;
    }

    // Get all sales in range
    final sales = await _salesRepo.listSales(
      startDate: rangeStart,
      endDate: rangeEnd,
      limit: 10000,
    );

    // Get all expenses in range (inclusive boundaries)
    final expenses = await _expensesRepo.getExpenses();
    final rangeStartDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final rangeEndDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day, 23, 59, 59);
    final expensesInRange = expenses
        .where((e) => !e.expenseDate.isBefore(rangeStartDay) &&
            !e.expenseDate.isAfter(rangeEndDay))
        .toList();

    // Determine granularity based on date range
    final daysDiff = rangeEnd.difference(rangeStart).inDays;
    String dateKeyFormat;
    String Function(DateTime) getDateKey;
    
    if (daysDiff <= 14) {
      // Daily granularity for <= 14 days
      dateKeyFormat = 'yyyy-MM-dd';
      getDateKey = (date) => DateFormat('yyyy-MM-dd').format(date);
    } else if (daysDiff <= 90) {
      // Weekly granularity for <= 90 days
      dateKeyFormat = 'yyyy-ww';
      getDateKey = (date) {
        // ISO 8601 week numbering:
        // Week 1 is the week containing the first Thursday of the year
        // This ensures consistent week grouping across year boundaries
        final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));
        final jan1 = DateTime(thursday.year, 1, 1);
        final weekNumber = ((thursday.difference(jan1).inDays) / 7).ceil() + 1;
        return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
      };
    } else {
      // Monthly granularity for > 90 days
      dateKeyFormat = 'yyyy-MM';
      getDateKey = (date) => DateFormat('yyyy-MM').format(date);
    }

    // Group by determined granularity
    final trendMap = <String, Map<String, double>>{};

    // Process direct sales
    for (final sale in sales) {
      final dateKey = getDateKey(sale.createdAt);
      if (!trendMap.containsKey(dateKey)) {
        trendMap[dateKey] = {'sales': 0.0, 'costs': 0.0, 'profit': 0.0};
      }
      trendMap[dateKey]!['sales'] =
          (trendMap[dateKey]!['sales'] ?? 0.0) + sale.finalAmount;

      // Calculate COGS: Use actual if available, otherwise estimate
      double saleCogs;
      if (sale.cogs != null && sale.cogs! > 0) {
        saleCogs = sale.cogs!;
      } else if (sale.items != null && sale.items!.isNotEmpty) {
        // Sum COGS from items
        saleCogs = sale.items!.fold<double>(
          0.0,
          (sum, item) => sum + (item.costOfGoods ?? 0.0),
        );
        // Fallback to estimate if no item COGS
        if (saleCogs == 0) {
          saleCogs = sale.finalAmount * _cogsPercentage;
        }
      } else {
        // Fallback: Estimate using default percentage
        saleCogs = sale.finalAmount * _cogsPercentage;
      }
      trendMap[dateKey]!['costs'] =
          (trendMap[dateKey]!['costs'] ?? 0.0) + saleCogs;
    }

    // Add booking revenue (to match P&L calculation)
    final completedBookings = await _bookingsRepo.listBookings(
      status: 'completed',
      limit: 10000,
    );
    final startUtc = rangeStart.toUtc();
    final endUtc = rangeEnd.toUtc();
    final bookingsInRange = completedBookings.where((booking) {
      final bookingDateUtc = booking.createdAt.toUtc();
      return !bookingDateUtc.isBefore(startUtc) &&
          !bookingDateUtc.isAfter(endUtc);
    }).toList();
    
    for (final booking in bookingsInRange) {
      final dateKey = getDateKey(booking.createdAt);
      if (!trendMap.containsKey(dateKey)) {
        trendMap[dateKey] = {'sales': 0.0, 'costs': 0.0, 'profit': 0.0};
      }
      trendMap[dateKey]!['sales'] =
          (trendMap[dateKey]!['sales'] ?? 0.0) + booking.totalAmount;
    }

    // Add consignment revenue (server-side filter for settled claims only)
    final trendClaimsResponse = await _claimsRepo.listClaims(
      fromDate: rangeStart,
      toDate: rangeEnd,
      status: ClaimStatus.settled,
      limit: _maxQueryLimit,
    );
    final settledClaims = (trendClaimsResponse['data'] as List).cast<ConsignmentClaim>();
    
    for (final claim in settledClaims) {
      final dateKey = getDateKey(claim.createdAt);
      if (!trendMap.containsKey(dateKey)) {
        trendMap[dateKey] = {'sales': 0.0, 'costs': 0.0, 'profit': 0.0};
      }
      trendMap[dateKey]!['sales'] =
          (trendMap[dateKey]!['sales'] ?? 0.0) + claim.netAmount;
    }

    // Process expenses
    for (final expense in expensesInRange) {
      final dateKey = getDateKey(expense.expenseDate);
      if (!trendMap.containsKey(dateKey)) {
        trendMap[dateKey] = {'sales': 0.0, 'costs': 0.0, 'profit': 0.0};
      }
      trendMap[dateKey]!['costs'] =
          (trendMap[dateKey]!['costs'] ?? 0.0) + expense.amount;
    }

    // Calculate profit for each period
    for (final entry in trendMap.entries) {
      entry.value['profit'] = (entry.value['sales'] ?? 0.0) - (entry.value['costs'] ?? 0.0);
    }

    // Fill missing periods with zero values (especially for daily granularity)
    if (daysDiff <= 14) {
      // For daily, ensure all days in range have data points
      final allDays = <String>[];
      var currentDate = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      final endDate = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
      
      while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
        final dayKey = DateFormat('yyyy-MM-dd').format(currentDate);
        allDays.add(dayKey);
        currentDate = currentDate.add(const Duration(days: 1));
      }
      
      // Add missing days with zero values
      for (final dayKey in allDays) {
        if (!trendMap.containsKey(dayKey)) {
          trendMap[dayKey] = {'sales': 0.0, 'costs': 0.0, 'profit': 0.0};
        }
      }
    }

    // Convert to MonthlyTrend list and sort by date key
    final trends = trendMap.entries
        .map((e) => MonthlyTrend(
              month: e.key,
              sales: e.value['sales'] ?? 0.0,
              costs: e.value['costs'] ?? 0.0,
            ))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    return trends;
  }

  /// Get Sales by Channel Breakdown
  /// Includes: Direct Sales, Booking Sales, and Consignment Revenue
  Future<List<SalesByChannel>> getSalesByChannel({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Default to current month if no dates provided
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Get all sales in date range
    final sales = await _salesRepo.listSales(
      startDate: start,
      endDate: end,
      limit: 10000,
    );

    // Group sales by channel
    // IMPORTANT: Exclude sales with channel='booking' to avoid double counting
    // Bookings are tracked separately below
    final channelMap = <String, Map<String, dynamic>>{};

    for (final sale in sales) {
      final channel = sale.channel.toLowerCase();
      
      // Skip booking channel sales - they're tracked via bookings table
      if (channel == 'booking' || channel == 'tempahan') {
        continue;
      }
      
      final channelLabel = _getChannelLabel(channel);

      if (!channelMap.containsKey(channel)) {
        channelMap[channel] = {
          'channel': channel,
          'channelLabel': channelLabel,
          'revenue': 0.0,
          'transactionCount': 0,
        };
      }

      channelMap[channel]!['revenue'] =
          (channelMap[channel]!['revenue'] as double) + sale.finalAmount;
      channelMap[channel]!['transactionCount'] =
          (channelMap[channel]!['transactionCount'] as int) + 1;
    }

    // Get consignment revenue (net_amount from settled claims)
    final claims = await _claimsRepo.listClaims(
      fromDate: start,
      toDate: end,
      status: ClaimStatus.settled,
    );

    final settledClaims = (claims['data'] as List)
        .cast<ConsignmentClaim>()
        .where((claim) => claim.status == ClaimStatus.settled)
        .toList();

    final consignmentRevenue = settledClaims.fold<double>(
      0.0,
      (sum, claim) => sum + claim.netAmount,
    );

    // Add consignment as a channel
    if (consignmentRevenue > 0) {
      channelMap['consignment'] = {
        'channel': 'consignment',
        'channelLabel': 'Vendor (Consignment)',
        'revenue': consignmentRevenue,
        'transactionCount': settledClaims.length,
      };
    }

    // Get booking revenue (total_amount from completed bookings)
    final completedBookings = await _bookingsRepo.listBookings(
      status: 'completed',
      limit: 10000,
    );

    // Filter bookings by date range
    // Convert start and end to UTC for comparison (booking.createdAt is in UTC)
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();
    final bookingsInRange = completedBookings.where((booking) {
      final bookingDateUtc = booking.createdAt.toUtc();
      return !bookingDateUtc.isBefore(startUtc) &&
          !bookingDateUtc.isAfter(endUtc);
    }).toList();

    final bookingRevenue = bookingsInRange.fold<double>(
      0.0,
      (sum, booking) => sum + booking.totalAmount,
    );

    // Add booking as a channel
    if (bookingRevenue > 0) {
      channelMap['booking'] = {
        'channel': 'booking',
        'channelLabel': 'Tempahan',
        'revenue': bookingRevenue,
        'transactionCount': bookingsInRange.length,
      };
    }

    // Calculate total revenue
    final totalRevenue = channelMap.values.fold<double>(
      0.0,
      (sum, channel) => sum + (channel['revenue'] as double),
    );

    // Convert to SalesByChannel list and calculate percentages
    final salesByChannel = channelMap.values
        .map((channel) {
          final revenue = channel['revenue'] as double;
          final percentage = totalRevenue > 0 ? (revenue / totalRevenue) * 100 : 0.0;
          return SalesByChannel(
            channel: channel['channel'] as String,
            channelLabel: channel['channelLabel'] as String,
            revenue: revenue,
            percentage: percentage,
            transactionCount: channel['transactionCount'] as int,
          );
        })
        .toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return salesByChannel;
  }

  /// Get channel label in Bahasa Malaysia
  String _getChannelLabel(String channel) {
    switch (channel.toLowerCase()) {
      case 'walk-in':
      case 'walkin':
        return 'Walk-in';
      case 'booking':
      case 'tempahan':
        return 'Tempahan';
      case 'myshop':
      case 'online':
        return 'Online';
      case 'delivery':
        return 'Penghantaran';
      case 'consignment':
      case 'vendor':
        return 'Vendor (Consignment)';
      case 'wholesale':
        return 'Wholesale';
      default:
        return channel.toUpperCase();
    }
  }
}

