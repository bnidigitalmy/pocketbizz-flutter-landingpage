import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../data/repositories/purchase_order_repository_supabase.dart' show PurchaseOrderRepository;
import '../../../data/repositories/stock_repository_supabase.dart';
import 'widgets/morning_briefing_card.dart';
import 'widgets/today_performance_card.dart';
import 'widgets/urgent_actions_widget.dart';
import 'widgets/smart_suggestions_widget.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/low_stock_alerts_widget.dart';

/// Optimized Dashboard for SME Malaysia
/// Concept: "Urus bisnes dari poket tanpa stress"
/// Designed to be the FIRST app they check every morning
class DashboardPageOptimized extends StatefulWidget {
  const DashboardPageOptimized({super.key});

  @override
  State<DashboardPageOptimized> createState() => _DashboardPageOptimizedState();
}

class _DashboardPageOptimizedState extends State<DashboardPageOptimized> {
  final _bookingsRepo = BookingsRepositorySupabase();
  final _salesRepo = SalesRepositorySupabase();
  final _poRepo = PurchaseOrderRepository(supabase);
  final _stockRepo = StockRepository(supabase);

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _todayStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when page becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAllData();
      }
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);

    try {
      // Load all stats in parallel
      final results = await Future.wait([
        _bookingsRepo.getStatistics(),
        _loadTodaySalesStats(),
        _loadPendingTasks(),
      ]);

      // Merge pending tasks into todayStats
      final pendingTasks = results[2] as Map<String, dynamic>;
      final todayStats = results[1] as Map<String, dynamic>;
      final mergedTodayStats = {
        ...todayStats,
        ...pendingTasks,
      };

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _todayStats = mergedTodayStats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _loadTodaySalesStats() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final yesterdayEnd = yesterdayStart.add(const Duration(days: 1));

      // Get today's sales
      final todaySales = await _salesRepo.listSales(
        startDate: todayStart,
        endDate: todayEnd,
      );

      // Get yesterday's sales
      final yesterdaySales = await _salesRepo.listSales(
        startDate: yesterdayStart,
        endDate: yesterdayEnd,
      );

      final todayRevenue = todaySales.fold<double>(
        0.0,
        (sum, sale) => sum + (sale.totalAmount ?? 0.0),
      );

      final yesterdayRevenue = yesterdaySales.fold<double>(
        0.0,
        (sum, sale) => sum + (sale.totalAmount ?? 0.0),
      );

      final revenueChange = yesterdayRevenue > 0
          ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100)
          : (todayRevenue > 0 ? 100.0 : 0.0);

      return {
        'todayRevenue': todayRevenue,
        'yesterdayRevenue': yesterdayRevenue,
        'revenueChange': revenueChange,
        'todaySalesCount': todaySales.length,
        'yesterdaySalesCount': yesterdaySales.length,
      };
    } catch (e) {
      return {
        'todayRevenue': 0.0,
        'yesterdayRevenue': 0.0,
        'revenueChange': 0.0,
        'todaySalesCount': 0,
        'yesterdaySalesCount': 0,
      };
    }
  }

  Future<Map<String, dynamic>> _loadPendingTasks() async {
    try {
      // Get all purchase orders and filter by status
      final allPOs = await _poRepo.getAllPurchaseOrders();
      final pendingPOs = allPOs.where((po) => po.status == 'pending').toList();

      // Get low stock items count
      final lowStockItems = await _stockRepo.getLowStockItems();

      return {
        'pendingPOs': pendingPOs.length,
        'lowStockCount': lowStockItems.length,
      };
    } catch (e) {
      return {
        'pendingPOs': 0,
        'lowStockCount': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final now = DateTime.now();
    final hour = now.hour;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PocketBizz',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              DateFormat('EEEE, d MMMM yyyy', 'ms_MY').format(now),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Morning Briefing Card
                  MorningBriefingCard(
                    userName: user?.email?.split('@').first ?? 'SME Owner',
                    hour: hour,
                  ),

                  const SizedBox(height: 20),

                  // Today's Performance
                  if (_todayStats != null)
                    TodayPerformanceCard(
                      todayRevenue: _todayStats!['todayRevenue'] ?? 0.0,
                      yesterdayRevenue: _todayStats!['yesterdayRevenue'] ?? 0.0,
                      revenueChange: _todayStats!['revenueChange'] ?? 0.0,
                      todaySalesCount: _todayStats!['todaySalesCount'] ?? 0,
                      yesterdaySalesCount: _todayStats!['yesterdaySalesCount'] ?? 0,
                    ),

                  const SizedBox(height: 20),

                  // Urgent Actions
                  UrgentActionsWidget(
                    pendingBookings: _stats?['pending'] ?? 0,
                    pendingPOs: _todayStats?['pendingPOs'] ?? 0,
                    lowStockCount: _todayStats?['lowStockCount'] ?? 0,
                    onViewBookings: () => Navigator.of(context).pushNamed('/bookings'),
                    onViewPOs: () => Navigator.of(context).pushNamed('/purchase-orders'),
                    onViewStock: () => Navigator.of(context).pushNamed('/stock'),
                  ),

                  const SizedBox(height: 20),

                  // Smart Suggestions
                  SmartSuggestionsWidget(
                    stats: _stats,
                    todayStats: _todayStats,
                  ),

                  const SizedBox(height: 20),

                  // Quick Actions
                  const QuickActionGrid(),

                  const SizedBox(height: 20),

                  // Low Stock Alerts
                  const LowStockAlertsWidget(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

