/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../data/repositories/reports_repository_supabase.dart';
import '../data/models/profit_loss_report.dart';
import '../data/models/top_product.dart';
import '../data/models/top_vendor.dart';
import '../data/models/monthly_trend.dart';
import '../data/models/sales_by_channel.dart';
import '../utils/pdf_generator.dart';
import '../../drive_sync/utils/drive_sync_helper.dart';
import '../../../core/services/document_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../providers/reports_state_notifier.dart';

/// Reports Page - Phase 1: Foundation
/// Shows Profit/Loss, Top Products, Top Vendors, and Monthly Trends
/// NOW WITH TRUE REAL-TIME UX via Riverpod StateNotifier
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> with SingleTickerProviderStateMixin {
  final _businessProfileRepo = BusinessProfileRepository();
  late TabController _tabController;

  // Date range for reports (default: current month)
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Initialize date range to current month
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _startDate = DateTime(now.year, now.month, 1);
    // End date should not exceed today
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    _endDate = lastDayOfMonth.isAfter(endOfToday) 
        ? endOfToday // Use today if last day of month is in future
        : lastDayOfMonth; // Use last day of month
    
    // Load data via StateNotifier (real-time subscriptions are handled in StateNotifier)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(reportsStateNotifierProvider.notifier).loadAllData(
        startDate: _startDate,
        endDate: _endDate,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // All data loading methods removed - now handled by Riverpod StateNotifier
  // Real-time subscriptions removed - now handled by StateNotifier with granular updates
  // No debounce needed - granular updates are instant

  /// Get user-friendly error message
  String _getErrorMessage(Object error, String featureName) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Masalah sambungan. Sila semak internet anda.';
    } else if (errorStr.contains('timeout')) {
      return 'Masa tamat. Sila cuba lagi.';
    } else if (errorStr.contains('unauthorized') || errorStr.contains('auth')) {
      return 'Sesi tamat. Sila log masuk semula.';
    } else if (errorStr.contains('not found')) {
      return 'Data tidak dijumpai untuk tempoh yang dipilih.';
    } else {
      return 'Gagal memuatkan $featureName. Sila cuba lagi.';
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    // Use end of today as lastDate to allow selecting today
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Ensure initialDateRange doesn't exceed lastDate
    DateTimeRange? initialRange;
    if (_startDate != null && _endDate != null) {
      // Clamp end date to not exceed today
      final clampedEnd = _endDate!.isAfter(endOfToday) ? endOfToday : _endDate!;
      initialRange = DateTimeRange(start: _startDate!, end: clampedEnd);
    } else {
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
      final clampedLastDay = lastDayOfMonth.isAfter(now) 
          ? endOfToday 
          : DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      initialRange = DateTimeRange(start: firstDayOfMonth, end: clampedLastDay);
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: endOfToday,
      initialDateRange: initialRange,
    );

    if (picked != null) {
      setState(() {
        // Set start date to beginning of day (00:00:00)
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        // Set end date to end of day (23:59:59) to include all data for that day
        // But ensure it doesn't exceed today
        final endOfPickedDay = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _endDate = endOfPickedDay.isAfter(endOfToday) ? endOfToday : endOfPickedDay;
      });
      // Reload data with new date range via StateNotifier
      ref.read(reportsStateNotifierProvider.notifier).loadAllData(
        startDate: _startDate,
        endDate: _endDate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch reports state from Riverpod - UI rebuilds automatically on state changes
    final reportsState = ref.watch(reportsStateNotifierProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Analitik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(reportsStateNotifierProvider.notifier).loadAllData(
                startDate: _startDate,
                endDate: _endDate,
              );
            },
            tooltip: 'Muat semula',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Pilih tarikh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: reportsState.profitLoss != null ? () => _exportPDF(reportsState) : null,
            tooltip: 'Export PDF',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ringkasan', icon: Icon(Icons.dashboard)),
            Tab(text: 'Produk', icon: Icon(Icons.inventory_2)),
            Tab(text: 'Vendor', icon: Icon(Icons.store)),
            Tab(text: 'Trend', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(reportsState),
          _buildProductsTab(reportsState),
          _buildVendorsTab(reportsState),
          _buildTrendsTab(reportsState),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ReportsState state) {
    if (state.isLoadingProfitLoss) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.profitLoss == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Tiada data',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prominent Summary Card - "Jualan Bulan Ini"
          _buildProminentSummaryCard(state),
          const SizedBox(height: 20),

          // Date range info - Enhanced
          if (_startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${DateFormat('d MMM yyyy', 'ms_MY').format(_startDate!)} - ${DateFormat('d MMM yyyy', 'ms_MY').format(_endDate!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Standard P&L Format Display
          // Revenue Section
          _buildEnhancedMetricCard(
            'Jualan (Revenue)',
            state.profitLoss!.totalSales,
            Icons.attach_money,
            AppColors.primary,
            AppColors.primaryLight,
          ),
          const SizedBox(height: 12),
          
          // COGS Section
          _buildEnhancedMetricCard(
            'Kos Pengeluaran (COGS)',
            state.profitLoss!.costOfGoodsSold,
            Icons.inventory_2,
            AppColors.error,
            AppColors.errorLight,
          ),
          const SizedBox(height: 12),
          
          // Gross Profit Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: state.profitLoss!.grossProfit >= 0
                  ? LinearGradient(
                      colors: [AppColors.success, AppColors.successLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [AppColors.error, AppColors.errorLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Untung Kasar (Gross Profit)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM ${NumberFormat('#,##0.00').format(state.profitLoss!.grossProfit)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${state.profitLoss!.grossProfitMargin.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Operating Expenses Section
          _buildEnhancedMetricCard(
            'Kos Operasi (Operating Expenses)',
            state.profitLoss!.operatingExpenses,
            Icons.receipt_long,
            AppColors.warning,
            AppColors.warningLight,
          ),
          const SizedBox(height: 12),
          
          // Operating Profit Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.profitLoss!.operatingProfit >= 0 
                    ? AppColors.success.withOpacity(0.3)
                    : AppColors.error.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.business_center,
                      color: state.profitLoss!.operatingProfit >= 0 
                          ? AppColors.success 
                          : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Untung Operasi (EBIT)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'RM ${NumberFormat('#,##0.00').format(state.profitLoss!.operatingProfit)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: state.profitLoss!.operatingProfit >= 0 
                        ? AppColors.success 
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Other Expenses Section (Always show for standard P&L format)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: state.profitLoss!.otherExpenses > 0 
                  ? AppColors.warningLight.withOpacity(0.3)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.profitLoss!.otherExpenses > 0 
                    ? AppColors.warning.withOpacity(0.3)
                    : AppColors.textSecondary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.block,
                      color: state.profitLoss!.otherExpenses > 0 
                          ? AppColors.warning 
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Perbelanjaan Lain (Other Expenses)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'RM ${NumberFormat('#,##0.00').format(state.profitLoss!.otherExpenses)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: state.profitLoss!.otherExpenses > 0 
                        ? AppColors.warning 
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Net Profit Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: state.profitLoss!.netProfit >= 0
                  ? AppColors.successGradient
                  : LinearGradient(
                      colors: [AppColors.error, AppColors.errorLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        state.profitLoss!.netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Untung Bersih (Net Profit)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM ${NumberFormat('#,##0.00').format(state.profitLoss!.netProfit)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SizedBox(height: 20),
          
          // Profit Margins Display
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Margin Kasar',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.profitLoss!.grossProfitMargin.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: state.profitLoss!.netProfitMargin >= 0
                        ? AppColors.successGradient
                        : LinearGradient(
                            colors: [AppColors.error, AppColors.errorLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Margin Untung Bersih',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.profitLoss!.netProfitMargin.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Legacy Profit Margin Card (if needed for reference)
          if (false) Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: state.profitLoss!.netProfitMargin >= 0
                  ? AppColors.successGradient
                  : LinearGradient(
                      colors: [AppColors.error, AppColors.errorLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.percent,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Margin Untung Bersih',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.profitLoss!.netProfitMargin.toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sales by Channel Breakdown - Enhanced
          if (state.salesByChannel.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Jualan Mengikut Saluran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: AppColors.cardShadow,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.salesByChannel.length,
                itemBuilder: (context, index) {
                  final channel = state.salesByChannel[index];
                  final colors = [
                    AppColors.primary,
                    AppColors.accent,
                    AppColors.success,
                    AppColors.warning,
                    AppColors.info,
                  ];
                  final channelColor = colors[index % colors.length];
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: index < state.salesByChannel.length - 1 ? 16 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: channelColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                channel.channelLabel,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'RM ${NumberFormat('#,##0.00').format(channel.revenue)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: channelColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: channelColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${channel.percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: channelColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: channel.percentage / 100,
                            backgroundColor: Colors.grey.shade200,
                            minHeight: 10,
                            valueColor: AlwaysStoppedAnimation<Color>(channelColor),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, double value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'RM ${NumberFormat('#,##0.00').format(value)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Enhanced metric card with gradient background
  Widget _buildEnhancedMetricCard(
    String title,
    double value,
    IconData icon,
    Color primaryColor,
    Color lightColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor.withOpacity(0.1), lightColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'RM ${NumberFormat('#,##0.00').format(value)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Prominent summary card showing total sales
  Widget _buildProminentSummaryCard(ReportsState state) {
    if (state.profitLoss == null) return const SizedBox.shrink();

    final isPositive = state.profitLoss!.netProfit >= 0;
    
    // Generate dynamic title based on date range
    String summaryTitle = 'Jualan';
    if (_startDate != null && _endDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final startOfDay = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      
      // Check if it's today
      if (startOfDay == today && endOfDay == today) {
        summaryTitle = 'Jualan Hari Ini';
      }
      // Check if it's current month
      else if (_startDate!.year == startOfMonth.year && 
          _startDate!.month == startOfMonth.month &&
          _endDate!.year == endOfMonth.year &&
          _endDate!.month == endOfMonth.month) {
        summaryTitle = 'Jualan Bulan Ini';
      } else {
        // Check date range duration
        final daysDiff = _endDate!.difference(_startDate!).inDays;
        if (daysDiff == 0) {
          summaryTitle = 'Jualan Hari Dipilih';
        } else if (daysDiff <= 7) {
          summaryTitle = 'Jualan Minggu Dipilih';
        } else if (daysDiff <= 31) {
          summaryTitle = 'Jualan Bulan Dipilih';
        } else {
          summaryTitle = 'Jualan Tempoh Dipilih';
        }
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summaryTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isPositive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Untung',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'RM ${NumberFormat('#,##0.00').format(state.profitLoss!.totalSales)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Untung Bersih: ',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              Text(
                'RM ${NumberFormat('#,##0.00').format(state.profitLoss!.netProfit)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab(ReportsState state) {
    if (state.isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.topProducts.isEmpty) {
      return const Center(child: Text('Tiada data produk'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produk Paling Untung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nota: Jumlah profit produk adalah dari jualan langsung sahaja. Untung Bersih di Ringkasan termasuk semua sumber pendapatan dan tolak kos operasi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bar Chart - Enhanced
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: AppColors.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: state.topProducts.isNotEmpty
                      ? (state.topProducts.map((p) => p.totalProfit).reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble()
                      : 100.0,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      tooltipBgColor: Colors.black87,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < state.topProducts.length) {
                            final product = state.topProducts[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                product.productName.length > 10
                                    ? '${product.productName.substring(0, 10)}...'
                                    : product.productName,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value <= 0) return const Text('');
                          if (value >= 1000) {
                            return Text(
                              'RM${(value / 1000).toStringAsFixed(1)}K',
                              style: const TextStyle(fontSize: 10),
                            );
                          } else {
                            return Text(
                              'RM${value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  barGroups: state.topProducts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final product = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: product.totalProfit,
                          gradient: AppColors.primaryGradient,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Summary Card - Total Profit from Products
          if (state.topProducts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jumlah Profit Produk',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${NumberFormat('#,##0.00').format(state.topProducts.fold<double>(0.0, (sum, p) => sum + p.totalProfit))}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Products List - Enhanced (using ListView.builder for virtual scrolling)
          SizedBox(
            height: state.topProducts.length > 5 ? 400 : null,
            child: ListView.builder(
              shrinkWrap: state.topProducts.length <= 5,
              physics: state.topProducts.length <= 5 ? const NeverScrollableScrollPhysics() : null,
              itemCount: state.topProducts.length,
              itemBuilder: (context, index) {
                final product = state.topProducts[index];
                return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: AppColors.cardShadow,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  product.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${product.totalSold.toStringAsFixed(0)} terjual',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${NumberFormat('#,##0.00').format(product.totalProfit)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${product.profitMargin.toStringAsFixed(1)}% margin',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorsTab(ReportsState state) {
    if (state.isLoadingVendors) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.topVendors.isEmpty) {
      return const Center(child: Text('Tiada data vendor'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.topVendors.length,
      itemBuilder: (context, index) {
        final vendor = state.topVendors[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: AppColors.cardShadow,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              vendor.vendorName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.local_shipping, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${vendor.totalDeliveries} penghantaran',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM ${NumberFormat('#,##0.00').format(vendor.totalAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendsTab(ReportsState state) {
    if (state.isLoadingTrends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.monthlyTrends.isEmpty) {
      return const Center(child: Text('Tiada data trend'));
    }

    // Calculate summary statistics
    final totalSales = state.monthlyTrends.fold<double>(0.0, (sum, t) => sum + t.sales);
    final totalCosts = state.monthlyTrends.fold<double>(0.0, (sum, t) => sum + t.costs);
    final totalProfit = totalSales - totalCosts;
    final avgSales = state.monthlyTrends.isNotEmpty ? totalSales / state.monthlyTrends.length : 0.0;
    final avgCosts = state.monthlyTrends.isNotEmpty ? totalCosts / state.monthlyTrends.length : 0.0;
    final avgProfit = avgSales - avgCosts;
    
    // Calculate growth (first vs last period)
    // Only show growth if we have meaningful data
    double? growthRate;
    if (state.monthlyTrends.length >= 2) {
      final firstSales = state.monthlyTrends.first.sales;
      final lastSales = state.monthlyTrends.last.sales;
      
      // Only calculate growth if both periods have meaningful data
      // Avoid showing misleading 100% changes from zero
      if (firstSales > 10 && lastSales > 10) {
        // Both have meaningful data, calculate growth
        growthRate = ((lastSales - firstSales) / firstSales) * 100;
      } else if (firstSales == 0 && lastSales > 10) {
        // Growth from zero to positive - show as "new" (don't show as 100% increase)
        growthRate = null; // Don't show misleading growth
      } else if (firstSales > 10 && lastSales == 0) {
        // Drop to zero - this is meaningful, show as -100%
        growthRate = -100.0;
      }
      // If both are 0 or both are very small, don't show growth (null)
    }

    // Determine granularity label
    String granularityLabel = 'Bulanan';
    if (_startDate != null && _endDate != null) {
      final daysDiff = _endDate!.difference(_startDate!).inDays;
      if (daysDiff <= 14) {
        granularityLabel = 'Harian';
      } else if (daysDiff <= 90) {
        granularityLabel = 'Mingguan';
      } else {
        granularityLabel = 'Bulanan';
      }
    }

    final maxValue = state.monthlyTrends.isEmpty
        ? 100.0
        : state.monthlyTrends
            .map((t) {
              final profit = t.sales - t.costs;
              return t.sales > t.costs ? t.sales : (t.costs > profit ? t.costs : profit);
            })
            .reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trend Jualan & Kos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tempoh: ${DateFormat('d MMM yyyy', 'ms_MY').format(_startDate!)} - ${DateFormat('d MMM yyyy', 'ms_MY').format(_endDate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      granularityLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Info box explaining averages
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maklumat Purata:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Purata adalah nilai per ${granularityLabel.toLowerCase()} untuk tempoh yang dipilih. Contoh: Purata Jualan RM 1,852.05 bermakna purata jualan setiap hari adalah RM 1,852.05.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Summary Statistics Cards - Averages Row
          Row(
            children: [
              Expanded(
                child: _buildTrendStatCard(
                  'Purata Jualan',
                  avgSales,
                  Icons.trending_up,
                  AppColors.primary,
                  subtitle: 'Per ${granularityLabel.toLowerCase()}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendStatCard(
                  'Purata Kos',
                  avgCosts,
                  Icons.trending_down,
                  AppColors.error,
                  subtitle: 'Per ${granularityLabel.toLowerCase()}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendStatCard(
                  'Purata Untung',
                  avgProfit,
                  Icons.attach_money,
                  avgProfit >= 0 ? AppColors.success : AppColors.error,
                  subtitle: 'Per ${granularityLabel.toLowerCase()}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Summary Statistics Cards - Totals Row
          Row(
            children: [
              Expanded(
                child: _buildTrendStatCard(
                  'Jumlah Jualan',
                  totalSales,
                  Icons.shopping_cart,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendStatCard(
                  'Jumlah Kos',
                  totalCosts,
                  Icons.receipt_long,
                  AppColors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendStatCard(
                  'Jumlah Untung',
                  totalProfit,
                  Icons.account_balance_wallet,
                  totalProfit >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
          if (growthRate != null && growthRate!.abs() < 10000) ...[
            // Only show growth if it's reasonable (not extreme values like 100% from zero)
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: growthRate! >= 0 
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: growthRate! >= 0 
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    growthRate! >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: growthRate! >= 0 ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pertumbuhan: ${growthRate!.abs().toStringAsFixed(1)}% ${growthRate! >= 0 ? 'peningkatan' : 'penurunan'} dari tempoh pertama',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: growthRate! >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            height: 420,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: AppColors.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        // Calculate interval: show every 2-3 months depending on data count
                        interval: state.monthlyTrends.length > 6 ? 2.0 : 1.0,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < state.monthlyTrends.length) {
                            final trend = state.monthlyTrends[index];
                            String label;
                            
                            try {
                              // Check format: yyyy-MM-dd (daily), yyyy-W## (weekly), or yyyy-MM (monthly)
                              if (trend.month.contains('-W')) {
                                // Weekly format: yyyy-W##
                                final parts = trend.month.split('-W');
                                if (parts.length == 2) {
                                  final year = parts[0];
                                  final week = parts[1];
                                  label = 'M$week';
                                } else {
                                  label = trend.month;
                                }
                              } else {
                                final parts = trend.month.split('-');
                                if (parts.length == 3) {
                                  // Daily format: yyyy-MM-dd
                                  final day = int.parse(parts[2]);
                                  final monthNum = int.parse(parts[1]);
                                  final months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'];
                                  label = '$day ${months[monthNum - 1]}';
                                } else if (parts.length == 2) {
                                  // Monthly format: yyyy-MM
                                  final monthNum = int.parse(parts[1]);
                                  final months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'];
                                  label = months[monthNum - 1];
                                } else {
                                  label = trend.month;
                                }
                              }
                            } catch (e) {
                              label = trend.month;
                            }
                            
                            // Show labels at intervals to avoid crowding
                            final interval = state.monthlyTrends.length > 10 ? 2.0 : 1.0;
                            if (index % interval.toInt() == 0 || index == state.monthlyTrends.length - 1) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value <= 0) return const Text('');
                          if (value >= 1000) {
                            return Text(
                              'RM${(value / 1000).toStringAsFixed(1)}K',
                              style: const TextStyle(fontSize: 10),
                            );
                          } else {
                            return Text(
                              'RM${value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minX: 0,
                  maxX: state.monthlyTrends.isEmpty ? 0 : (state.monthlyTrends.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxValue > 0 ? (maxValue * 1.2).ceilToDouble() : 100.0,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      tooltipBgColor: Colors.black87,
                      tooltipPadding: const EdgeInsets.all(12),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final index = touchedSpot.x.toInt();
                          if (index >= 0 && index < state.monthlyTrends.length) {
                            final trend = state.monthlyTrends[index];
                            final profit = trend.sales - trend.costs;
                            String periodLabel = trend.month;
                            
                            // Format period label
                            try {
                              if (trend.month.contains('-W')) {
                                final parts = trend.month.split('-W');
                                periodLabel = 'Minggu ${parts[1]}';
                              } else {
                                final parts = trend.month.split('-');
                                if (parts.length == 3) {
                                  final day = int.parse(parts[2]);
                                  final monthNum = int.parse(parts[1]);
                                  final months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'];
                                  periodLabel = '$day ${months[monthNum - 1]}';
                                } else if (parts.length == 2) {
                                  final monthNum = int.parse(parts[1]);
                                  final months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'];
                                  periodLabel = months[monthNum - 1];
                                }
                              }
                            } catch (e) {
                              // Keep original label
                            }
                            
                            if (touchedSpot.barIndex == 0) {
                              return LineTooltipItem(
                                '$periodLabel\nJualan: RM ${NumberFormat('#,##0.00').format(trend.sales)}\nKos: RM ${NumberFormat('#,##0.00').format(trend.costs)}\nUntung: RM ${NumberFormat('#,##0.00').format(profit)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            } else if (touchedSpot.barIndex == 1) {
                              return LineTooltipItem(
                                '$periodLabel\nKos: RM ${NumberFormat('#,##0.00').format(trend.costs)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    // Sales line
                    LineChartBarData(
                      spots: state.monthlyTrends.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.sales);
                      }).toList(),
                      isCurved: true,
                      gradient: AppColors.primaryGradient,
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            AppColors.primary.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Costs line
                    LineChartBarData(
                      spots: state.monthlyTrends.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.costs);
                      }).toList(),
                      isCurved: true,
                      color: AppColors.error,
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AppColors.error,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.error.withOpacity(0.1),
                            AppColors.error.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Profit line (dashed) - only show if there's meaningful variation
                    if (state.monthlyTrends.length > 1)
                      LineChartBarData(
                        spots: state.monthlyTrends.asMap().entries.map((entry) {
                          final profit = entry.value.sales - entry.value.costs;
                          return FlSpot(entry.key.toDouble(), profit);
                        }).toList(),
                        isCurved: true,
                        color: AppColors.success,
                        barWidth: 3,
                        dashArray: [5, 5], // Dashed line for profit
                        dotData: FlDotData(
                          show: state.monthlyTrends.length <= 20, // Only show dots if not too many points
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.success,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Jualan', AppColors.primary),
              const SizedBox(width: 16),
              _buildLegendItem('Kos', AppColors.error),
              const SizedBox(width: 16),
              _buildLegendItem('Untung', AppColors.success, isDashed: true),
            ],
          ),
          const SizedBox(height: 24),

          // Detailed Data Table
          const Text(
            'Butiran Trend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Tempoh',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Jualan',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Kos',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Untung',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Data rows - Use ListView.builder for virtual scrolling
                SizedBox(
                  height: state.monthlyTrends.length > 8 ? 400 : null,
                  child: ListView.builder(
                    shrinkWrap: state.monthlyTrends.length <= 8,
                    physics: state.monthlyTrends.length <= 8 ? const NeverScrollableScrollPhysics() : null,
                    itemCount: state.monthlyTrends.length,
                    itemBuilder: (context, index) {
                      final trend = state.monthlyTrends[index];
                      final profit = trend.sales - trend.costs;
                      
                      String periodLabel = trend.month;
                      try {
                        if (trend.month.contains('-W')) {
                          final parts = trend.month.split('-W');
                          periodLabel = 'Minggu ${parts[1]}';
                        } else {
                          final parts = trend.month.split('-');
                          if (parts.length == 3) {
                            final day = int.parse(parts[2]);
                            final monthNum = int.parse(parts[1]);
                            final months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'];
                            periodLabel = '$day ${months[monthNum - 1]} ${parts[0]}';
                          } else if (parts.length == 2) {
                            final monthNum = int.parse(parts[1]);
                            final months = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ogo', 'Sep', 'Okt', 'Nov', 'Dis'];
                            periodLabel = '${months[monthNum - 1]} ${parts[0]}';
                          }
                        }
                      } catch (e) {
                        // Keep original
                      }
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: index < state.monthlyTrends.length - 1 ? 1 : 0,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                periodLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'RM ${NumberFormat('#,##0.00').format(trend.sales)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'RM ${NumberFormat('#,##0.00').format(trend.costs)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'RM ${NumberFormat('#,##0.00').format(profit)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: profit >= 0 ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendStatCard(String title, double value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'RM ${NumberFormat('#,##0.00').format(value)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {bool isDashed = false}) {
    return Row(
      children: [
        if (isDashed)
          Container(
            width: 20,
            height: 2,
            decoration: BoxDecoration(
              color: color,
            ),
          )
        else
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _exportPDF(ReportsState state) async {
    if (state.profitLoss == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila tunggu data dimuatkan terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menjana PDF...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Fetch business profile
      final businessProfile = await _businessProfileRepo.getBusinessProfile();

      // Generate PDF
      final pdfBytes = await ReportsPDFGenerator.generateProfitLossPDF(
        profitLoss: state.profitLoss!,
        topProducts: state.topProducts,
        topVendors: state.topVendors,
        monthlyTrends: state.monthlyTrends,
        startDate: _startDate,
        endDate: _endDate,
        businessProfile: businessProfile,
        salesByChannel: state.salesByChannel.isNotEmpty ? state.salesByChannel : null,
      );

      // Auto-backup to Supabase Storage (non-blocking)
      final dateRangeText = _startDate != null && _endDate != null
          ? '${DateFormat('yyyyMMdd').format(_startDate!)}_${DateFormat('yyyyMMdd').format(_endDate!)}'
          : DateFormat('yyyyMM').format(DateTime.now());
      final fileName = 'Laporan_UntungRugi_$dateRangeText.pdf';
      
      DocumentStorageService.uploadDocumentSilently(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: 'profit_loss_report',
        relatedEntityType: 'report',
      );

      // Auto-sync to Google Drive (non-blocking, optional)
      DriveSyncHelper.syncDocumentSilently(
        pdfData: pdfBytes,
        fileName: fileName,
        fileType: 'profit_loss_report',
        relatedEntityType: 'report',
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Platform-specific download
        if (kIsWeb) {
          // Web: trigger download
          final blob = html.Blob([pdfBytes], 'application/pdf');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute('download', fileName)
            ..click();
          html.Url.revokeObjectUrl(url);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF berjaya dimuat turun!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Mobile: show print dialog
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF berjaya dijana'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menjana PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

