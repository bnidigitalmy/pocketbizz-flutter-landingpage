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
  final _salesRepo = SalesRepositorySupabase();
  final _expensesRepo = ExpensesRepositorySupabase();
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _bookingsRepo = BookingsRepositorySupabase();

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
      limit: 10000, // Large limit to get all
    );

    // Calculate total sales (including consignment revenue)
    final directSales = sales.fold<double>(
      0.0,
      (sum, sale) => sum + sale.finalAmount,
    );

    // Get all claims for consignment revenue and rejection loss (no status filter to get all)
    final allClaimsResponse = await _claimsRepo.listClaims(
      fromDate: start,
      toDate: end,
      limit: 10000, // Large limit to get all claims
    );

    final allClaimsList = (allClaimsResponse['data'] as List).cast<ConsignmentClaim>();

    // Get consignment revenue (net_amount from settled claims)
    final settledClaims = allClaimsList
        .where((claim) => claim.status == ClaimStatus.settled)
        .toList();

    final consignmentRevenue = settledClaims.fold<double>(
      0.0,
      (sum, claim) => sum + claim.netAmount,
    );

    // Get booking revenue (total_amount from completed bookings)
    final completedBookings = await _bookingsRepo.listBookings(
      status: 'completed',
      limit: 10000,
    );

    // Filter bookings by date range (exact match with "Hari Ini" card logic)
    // Use same logic as _loadInflowAndTransactions: isAfter(start - 1ms) && isBefore(end)
    final bookingsInRange = completedBookings.where((booking) {
      final bookingDateUtc = booking.createdAt.toUtc();
      return bookingDateUtc.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          bookingDateUtc.isBefore(end);
    }).toList();

    final bookingRevenue = bookingsInRange.fold<double>(
      0.0,
      (sum, booking) => sum + booking.totalAmount,
    );

    // Total sales = Direct sales + Consignment revenue + Booking revenue
    final totalSales = directSales + consignmentRevenue + bookingRevenue;

    // Calculate total COGS from sales
    // Note: If sales table has cogs field, use it. Otherwise calculate from sale_items
    double totalCogs = 0.0;
    for (final sale in sales) {
      if (sale.items != null) {
        // Calculate COGS from items if available
        // For now, we'll use a simplified approach
        // In production, you'd want to track actual COGS per sale
        totalCogs += sale.totalAmount * 0.6; // Estimate 60% as COGS
      }
    }

    // Get expenses in date range
    final expenses = await _expensesRepo.getExpenses();
    final expensesInRange = expenses.where((e) {
      return e.expenseDate.isAfter(start.subtract(const Duration(days: 1))) &&
          e.expenseDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    final totalExpenses = expensesInRange.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    // Total costs = COGS + Expenses
    final totalCosts = totalCogs + totalExpenses;

    // Get rejection loss from rejected consignment claims
    final rejectedClaims = allClaimsList
        .where((claim) => claim.status == ClaimStatus.rejected)
        .toList();

    final rejectionLoss = rejectedClaims.fold<double>(
      0.0,
      (sum, claim) {
        // Calculate loss from rejected items
        // Use gross amount as rejection loss (simplified)
        // In production, you'd want to track actual rejected item costs
        return sum + claim.grossAmount;
      },
    );

    // Calculate net profit
    final netProfit = totalSales - totalCosts - rejectionLoss;

    // Calculate profit margin
    final profitMargin = totalSales > 0 ? (netProfit / totalSales) * 100 : 0.0;

    return ProfitLossReport(
      totalSales: totalSales,
      totalCosts: totalCosts,
      rejectionLoss: rejectionLoss,
      netProfit: netProfit,
      profitMargin: profitMargin,
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

          // Estimate profit (simplified - in production, use actual COGS)
          final estimatedProfit = item.subtotal * 0.4; // 40% margin estimate
          product['totalProfit'] =
              (product['totalProfit'] as double) + estimatedProfit;
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
  Future<List<MonthlyTrend>> getMonthlyTrends({
    int months = 12,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Calculate date range
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);

    // Get all sales in range
    final sales = await _salesRepo.listSales(
      startDate: startDate,
      endDate: now,
      limit: 10000,
    );

    // Get all expenses in range
    final expenses = await _expensesRepo.getExpenses();
    final expensesInRange = expenses
        .where((e) => e.expenseDate.isAfter(startDate.subtract(const Duration(days: 1))))
        .toList();

    // Group by month
    final monthMap = <String, Map<String, double>>{};

    // Process sales
    for (final sale in sales) {
      final monthKey = DateFormat('yyyy-MM').format(sale.createdAt);
      if (!monthMap.containsKey(monthKey)) {
        monthMap[monthKey] = {'sales': 0.0, 'costs': 0.0};
      }
      monthMap[monthKey]!['sales'] =
          (monthMap[monthKey]!['sales'] ?? 0.0) + sale.finalAmount;

      // Estimate COGS
      final estimatedCogs = sale.finalAmount * 0.6;
      monthMap[monthKey]!['costs'] =
          (monthMap[monthKey]!['costs'] ?? 0.0) + estimatedCogs;
    }

    // Process expenses
    for (final expense in expensesInRange) {
      final monthKey = DateFormat('yyyy-MM').format(expense.expenseDate);
      if (!monthMap.containsKey(monthKey)) {
        monthMap[monthKey] = {'sales': 0.0, 'costs': 0.0};
      }
      monthMap[monthKey]!['costs'] =
          (monthMap[monthKey]!['costs'] ?? 0.0) + expense.amount;
    }

    // Convert to MonthlyTrend list and sort by month
    final trends = monthMap.entries
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
    final bookingsInRange = completedBookings.where((booking) {
      final bookingDate = booking.createdAt;
      return bookingDate.isAfter(start.subtract(const Duration(days: 1))) &&
          bookingDate.isBefore(end.add(const Duration(days: 1)));
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

