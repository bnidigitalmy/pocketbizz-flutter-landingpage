import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
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
import '../../subscription/services/subscription_service.dart';
import '../../subscription/data/models/subscription.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../../../data/repositories/announcements_repository_supabase.dart';
import '../../announcements/presentation/notifications_page.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

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
  final _businessProfileRepo = BusinessProfileRepository();
  final _announcementsRepo = AnnouncementsRepositorySupabase();

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _todayStats;
  List<SalesByChannel> _salesByChannel = [];
  Subscription? _subscription;
  BusinessProfile? _businessProfile;
  int _unreadNotifications = 0;
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
        _checkAndShowTooltip();
      }
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.dashboard,
    );
    
    if (shouldShow && mounted) {
      await TooltipHelper.showTooltip(
        context,
        TooltipContent.dashboard.moduleKey,
        TooltipContent.dashboard.title,
        TooltipContent.dashboard.message,
      );
    }
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
        SubscriptionService().getCurrentSubscription(),
        _businessProfileRepo.getBusinessProfile(),
      ]);

      if (!mounted) return; // Check again after async operations

      // Merge pending tasks into todayStats
      final pendingTasks = results[2] as Map<String, dynamic>;
      final todayStats = results[1] as Map<String, dynamic>;
      final mergedTodayStats = {
        ...todayStats,
        ...pendingTasks,
      };

      final subscription = results[4] as Subscription?;
      
      // Load unread notifications after subscription is loaded
      final unreadCount = await _loadUnreadNotifications(subscription);

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _todayStats = mergedTodayStats;
        _salesByChannel = results[3] as List<SalesByChannel>;
        _subscription = subscription;
        _businessProfile = results[5] as BusinessProfile?;
        _unreadNotifications = unreadCount;
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

      // Get today's completed bookings (optimized: only fetch what we need)
      final todayBookings = await _bookingsRepo.listBookings(
        status: 'completed',
        limit: 100, // Reduced from 10000 - only need recent bookings
      );
      final todayBookingsInRange = todayBookings.where((booking) {
        final bookingDate = booking.createdAt;
        return bookingDate.isAfter(todayStart.subtract(const Duration(days: 1))) &&
            bookingDate.isBefore(todayEnd);
      }).toList();

      // Get yesterday's completed bookings (optimized: only fetch what we need)
      final yesterdayBookings = await _bookingsRepo.listBookings(
        status: 'completed',
        limit: 100, // Reduced from 10000 - only need recent bookings
      );
      final yesterdayBookingsInRange = yesterdayBookings.where((booking) {
        final bookingDate = booking.createdAt;
        return bookingDate.isAfter(yesterdayStart.subtract(const Duration(days: 1))) &&
            bookingDate.isBefore(yesterdayEnd);
      }).toList();

      // Get today's consignment revenue (settled claims) - optimized limit
      final todayClaimsResponse = await _claimsRepo.listClaims(
        fromDate: todayStart,
        toDate: todayEnd,
        status: ClaimStatus.settled,
        limit: 100, // Reduced from 10000 - only need today's claims
      );
      final todaySettledClaims = (todayClaimsResponse['data'] as List)
          .cast<ConsignmentClaim>()
          .where((claim) => claim.status == ClaimStatus.settled)
          .toList();
      final todayConsignmentRevenue = todaySettledClaims.fold<double>(
        0.0,
        (sum, claim) => sum + claim.netAmount,
      );

      // Get yesterday's consignment revenue - optimized limit
      final yesterdayClaimsResponse = await _claimsRepo.listClaims(
        fromDate: yesterdayStart,
        toDate: yesterdayEnd,
        status: ClaimStatus.settled,
        limit: 100, // Reduced from 10000 - only need yesterday's claims
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
      final allPOs = await _poRepo.getAllPurchaseOrders(limit: 100);
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

  Future<int> _loadUnreadNotifications(Subscription? subscription) async {
    try {
      // Get subscription status for targeting
      String? subscriptionStatus;
      if (subscription != null) {
        if (subscription.isOnTrial) {
          subscriptionStatus = 'trial';
        } else if (subscription.status == SubscriptionStatus.active) {
          subscriptionStatus = 'active';
        } else if (subscription.status == SubscriptionStatus.expired) {
          subscriptionStatus = 'expired';
        } else if (subscription.status == SubscriptionStatus.grace) {
          subscriptionStatus = 'grace';
        }
      }
      
      return await _announcementsRepo.getUnreadCount(
        subscriptionStatus: subscriptionStatus,
      );
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

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
              DateFormat('EEEE, d MMMM yyyy', 'ms').format(DateTimeHelper.now()),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsPage()),
                  ).then((_) => _loadAllData()); // Refresh after returning
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
                  // Subscription Expiring Alert
                  if (_subscription != null && _subscription!.isExpiringSoon)
                    _buildSubscriptionAlert(),

                  // Morning Briefing Card
                  MorningBriefingCard(
                    userName: _businessProfile?.businessName ?? 
                              user?.email?.split('@').first ?? 
                              'SME Owner',
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

  Widget _buildSubscriptionAlert() {
    final days = _subscription!.daysRemaining;
    final isTrial = _subscription!.isOnTrial;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withOpacity(0.1),
            AppColors.warning.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTrial ? 'Trial Hampir Tamat!' : 'Langganan Hampir Tamat!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isTrial
                      ? 'Trial percuma anda akan tamat dalam $days hari. Pilih pakej untuk teruskan.'
                      : 'Langganan anda akan tamat dalam $days hari. Renew sekarang untuk teruskan.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/subscription');
            },
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Upgrade'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

