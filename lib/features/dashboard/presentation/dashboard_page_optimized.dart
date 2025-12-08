import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/bookings_repository_supabase.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../data/repositories/purchase_order_repository_supabase.dart'
    show PurchaseOrderRepository;
import '../../../data/repositories/stock_repository_supabase.dart';
import 'widgets/morning_briefing_card.dart';
import 'widgets/today_performance_card.dart';
import 'widgets/urgent_actions_widget.dart';
import 'widgets/smart_suggestions_widget.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/low_stock_alerts_widget.dart';
import 'widgets/sales_by_channel_card.dart';
import '../../planner/presentation/widgets/planner_today_card.dart';
import '../../../core/services/planner_auto_service.dart';
import '../../reports/data/repositories/reports_repository_supabase.dart';
import '../../reports/data/models/sales_by_channel.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/models/consignment_claim.dart';

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
  final _plannerAuto = PlannerAutoService();
  final _reportsRepo = ReportsRepositorySupabase();
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _todayStats;
  List<SalesByChannel> _salesByChannel = [];
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
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Kick off auto-task generation (best effort, non-blocking wait)
      await _plannerAuto.runAll();

      // Load all stats in parallel
      final results = await Future.wait([
        _bookingsRepo.getStatistics(),
        _loadTodaySalesStats(),
        _loadPendingTasks(),
        _loadSalesByChannel(),
      ]);

      if (!mounted) return; // Check again after async operations

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
        _salesByChannel = results[3] as List<SalesByChannel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

      // Get today's completed bookings
      final todayBookings = await _bookingsRepo.listBookings(
        status: 'completed',
        limit: 10000,
      );
      final todayBookingsInRange = todayBookings.where((booking) {
        final bookingDate = booking.createdAt;
        return bookingDate.isAfter(todayStart.subtract(const Duration(days: 1))) &&
            bookingDate.isBefore(todayEnd);
      }).toList();

      // Get yesterday's completed bookings
      final yesterdayBookings = await _bookingsRepo.listBookings(
        status: 'completed',
        limit: 10000,
      );
      final yesterdayBookingsInRange = yesterdayBookings.where((booking) {
        final bookingDate = booking.createdAt;
        return bookingDate.isAfter(yesterdayStart.subtract(const Duration(days: 1))) &&
            bookingDate.isBefore(yesterdayEnd);
      }).toList();

      // Get today's consignment revenue (settled claims)
      final todayClaimsResponse = await _claimsRepo.listClaims(
        fromDate: todayStart,
        toDate: todayEnd,
        status: ClaimStatus.settled,
        limit: 10000,
      );
      final todaySettledClaims = (todayClaimsResponse['data'] as List)
          .cast<ConsignmentClaim>()
          .where((claim) => claim.status == ClaimStatus.settled)
          .toList();
      final todayConsignmentRevenue = todaySettledClaims.fold<double>(
        0.0,
        (sum, claim) => sum + claim.netAmount,
      );

      // Get yesterday's consignment revenue
      final yesterdayClaimsResponse = await _claimsRepo.listClaims(
        fromDate: yesterdayStart,
        toDate: yesterdayEnd,
        status: ClaimStatus.settled,
        limit: 10000,
      );
      final yesterdaySettledClaims = (yesterdayClaimsResponse['data'] as List)
          .cast<ConsignmentClaim>()
          .where((claim) => claim.status == ClaimStatus.settled)
          .toList();
      final yesterdayConsignmentRevenue = yesterdaySettledClaims.fold<double>(
        0.0,
        (sum, claim) => sum + claim.netAmount,
      );

      // Calculate revenue including bookings and consignment
      // Use finalAmount (after discount) for consistency with sales by channel
      final todaySalesRevenue = todaySales.fold<double>(
        0.0,
        (sum, sale) => sum + sale.finalAmount,
      );
      final todayBookingRevenue = todayBookingsInRange.fold<double>(
        0.0,
        (sum, booking) => sum + booking.totalAmount,
      );
      final todayRevenue = todaySalesRevenue + todayBookingRevenue + todayConsignmentRevenue;

      final yesterdaySalesRevenue = yesterdaySales.fold<double>(
        0.0,
        (sum, sale) => sum + sale.finalAmount,
      );
      final yesterdayBookingRevenue = yesterdayBookingsInRange.fold<double>(
        0.0,
        (sum, booking) => sum + booking.totalAmount,
      );
      final yesterdayRevenue = yesterdaySalesRevenue + yesterdayBookingRevenue + yesterdayConsignmentRevenue;

      final revenueChange = yesterdayRevenue > 0
          ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue * 100)
          : (todayRevenue > 0 ? 100.0 : 0.0);

      return {
        'todayRevenue': todayRevenue,
        'yesterdayRevenue': yesterdayRevenue,
        'revenueChange': revenueChange,
        'todaySalesCount': todaySales.length + todayBookingsInRange.length,
        'yesterdaySalesCount': yesterdaySales.length + yesterdayBookingsInRange.length,
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

  Future<List<SalesByChannel>> _loadSalesByChannel() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final channels = await _reportsRepo.getSalesByChannel(
        startDate: todayStart,
        endDate: todayEnd,
      );

      return channels;
    } catch (e) {
      return [];
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

                  const SizedBox(height: 16),

                  // Sales by Channel Card
                  if (_salesByChannel.isNotEmpty) ...[
                    SalesByChannelCard(
                      salesByChannel: _salesByChannel,
                      totalRevenue: _salesByChannel.fold<double>(
                        0.0,
                        (sum, channel) => sum + channel.revenue,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Planner mini widget (moved below performance for less stress)
                  PlannerTodayCard(
                    onViewAll: () => Navigator.of(context).pushNamed('/planner'),
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

