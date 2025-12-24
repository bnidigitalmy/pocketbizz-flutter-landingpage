import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

/// Reports Page - Phase 1: Foundation
/// Shows Profit/Loss, Top Products, Top Vendors, and Monthly Trends
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  final _repo = ReportsRepositorySupabase();
  late TabController _tabController;

  // Data
  ProfitLossReport? _profitLoss;
  List<TopProduct> _topProducts = [];
  List<TopVendor> _topVendors = [];
  List<MonthlyTrend> _monthlyTrends = [];
  List<SalesByChannel> _salesByChannel = [];

  // Loading states
  bool _loadingProfitLoss = true;
  bool _loadingProducts = true;
  bool _loadingVendors = true;
  bool _loadingTrends = true;
  bool _loadingChannels = true;

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
    
    _loadAllData();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _profitLoss != null || _topProducts.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.reports,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.reports : TooltipContent.reportsEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait<void>([
      _loadProfitLoss(),
      _loadTopProducts(),
      _loadTopVendors(),
      _loadMonthlyTrends(),
      _loadSalesByChannel(),
    ]);
  }

  Future<void> _loadProfitLoss() async {
    setState(() => _loadingProfitLoss = true);
    try {
      final report = await _repo.getProfitLossReport(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _profitLoss = report;
          _loadingProfitLoss = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProfitLoss = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profit/loss: $e')),
        );
      }
    }
  }

  Future<void> _loadTopProducts() async {
    setState(() => _loadingProducts = true);
    try {
      final products = await _repo.getTopProducts(
        limit: 10,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _topProducts = products;
          _loadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  Future<void> _loadTopVendors() async {
    setState(() => _loadingVendors = true);
    try {
      final vendors = await _repo.getTopVendors(
        limit: 10,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _topVendors = vendors;
          _loadingVendors = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingVendors = false);
      }
    }
  }

  Future<void> _loadMonthlyTrends() async {
    setState(() => _loadingTrends = true);
    try {
      final trends = await _repo.getMonthlyTrends(months: 12);
      if (mounted) {
        setState(() {
          _monthlyTrends = trends;
          _loadingTrends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTrends = false);
      }
    }
  }

  Future<void> _loadSalesByChannel() async {
    setState(() => _loadingChannels = true);
    try {
      final channels = await _repo.getSalesByChannel(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() {
          _salesByChannel = channels;
          _loadingChannels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingChannels = false);
      }
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
      await _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Analitik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Pilih tarikh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportPDF,
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
          _buildOverviewTab(),
          _buildProductsTab(),
          _buildVendorsTab(),
          _buildTrendsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_loadingProfitLoss) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profitLoss == null) {
      return const Center(child: Text('Tiada data'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range info
          if (_startDate != null && _endDate != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('d MMM yyyy', 'ms_MY').format(_startDate!)} - ${DateFormat('d MMM yyyy', 'ms_MY').format(_endDate!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Profit/Loss Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Jumlah Jualan',
                  _profitLoss!.totalSales,
                  Icons.attach_money,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Jumlah Kos',
                  _profitLoss!.totalCosts,
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Kerugian Tolakan',
                  _profitLoss!.rejectionLoss,
                  Icons.block,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Untung Bersih',
                  _profitLoss!.netProfit,
                  Icons.trending_up,
                  _profitLoss!.netProfit >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Profit Margin Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Margin Untung',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_profitLoss!.profitMargin.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _profitLoss!.profitMargin >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sales by Channel Breakdown
          if (_salesByChannel.isNotEmpty) ...[
            const Text(
              'Jualan Mengikut Saluran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _salesByChannel.map((channel) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              channel.channelLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: LinearProgressIndicator(
                              value: channel.percentage / 100,
                              backgroundColor: Colors.grey.shade200,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'RM ${NumberFormat('#,##0.00').format(channel.revenue)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${channel.percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
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

  Widget _buildProductsTab() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_topProducts.isEmpty) {
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
          const SizedBox(height: 16),

          // Bar Chart
          SizedBox(
            height: 300,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _topProducts.isNotEmpty
                        ? _topProducts.map((p) => p.totalProfit).reduce((a, b) => a > b ? a : b) * 1.2
                        : 100,
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
                            if (value.toInt() >= 0 && value.toInt() < _topProducts.length) {
                              final product = _topProducts[value.toInt()];
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
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'RM${(value / 1000).toStringAsFixed(0)}K',
                              style: const TextStyle(fontSize: 10),
                            );
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
                    barGroups: _topProducts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final product = entry.value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: product.totalProfit,
                            color: AppColors.primary,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Products List
          ..._topProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(product.productName),
                subtitle: Text('${product.totalSold.toStringAsFixed(0)} terjual'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${NumberFormat('#,##0.00').format(product.totalProfit)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '${product.profitMargin.toStringAsFixed(1)}% margin',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVendorsTab() {
    if (_loadingVendors) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_topVendors.isEmpty) {
      return const Center(child: Text('Tiada data vendor'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _topVendors.length,
      itemBuilder: (context, index) {
        final vendor = _topVendors[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(vendor.vendorName),
            subtitle: Text('${vendor.totalDeliveries} penghantaran'),
            trailing: Text(
              'RM ${NumberFormat('#,##0.00').format(vendor.totalAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendsTab() {
    if (_loadingTrends) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_monthlyTrends.isEmpty) {
      return const Center(child: Text('Tiada data trend'));
    }

    final maxValue = _monthlyTrends
        .map((t) => t.sales > t.costs ? t.sales : t.costs)
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
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < _monthlyTrends.length) {
                              final trend = _monthlyTrends[value.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  trend.month.substring(5), // Show MM only
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
                          getTitlesWidget: (value, meta) {
                            return Text(
                              'RM${(value / 1000).toStringAsFixed(0)}K',
                              style: const TextStyle(fontSize: 10),
                            );
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
                    maxX: (_monthlyTrends.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxValue * 1.2,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _monthlyTrends.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value.sales);
                        }).toList(),
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                      LineChartBarData(
                        spots: _monthlyTrends.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value.costs);
                        }).toList(),
                        isCurved: true,
                        color: Colors.red,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Jualan', AppColors.primary),
              const SizedBox(width: 24),
              _buildLegendItem('Kos', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Future<void> _exportPDF() async {
    if (_profitLoss == null) {
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

      // Generate PDF
      final pdfBytes = await ReportsPDFGenerator.generateProfitLossPDF(
        profitLoss: _profitLoss!,
        topProducts: _topProducts,
        topVendors: _topVendors,
        monthlyTrends: _monthlyTrends,
        startDate: _startDate,
        endDate: _endDate,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berjaya dijana'),
            backgroundColor: Colors.green,
          ),
        );
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

