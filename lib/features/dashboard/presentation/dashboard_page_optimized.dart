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
import '../../expenses/presentation/receipt_scan_page.dart';
import '../domain/sme_dashboard_v2_models.dart';
import '../services/sme_dashboard_v2_service.dart';
import 'widgets/v2/production_suggestion_card_v2.dart';
import 'widgets/v2/primary_quick_actions_v2.dart';
import 'widgets/v2/smart_insights_card_v2.dart';
import 'widgets/v2/today_snapshot_hero_v2.dart';
import 'widgets/v2/top_products_cards_v2.dart';
import 'widgets/v2/weekly_cashflow_card_v2.dart';

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
  final _v2Service = SmeDashboardV2Service();

  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _pendingTasks;
  List<SalesByChannel> _salesByChannel = [];
  Subscription? _subscription;
  BusinessProfile? _businessProfile;
  int _unreadNotifications = 0;
  bool _loading = true;
  SmeDashboardV2Data? _v2;

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
        _loadPendingTasks(),
        _loadSalesByChannel(),
        SubscriptionService().getCurrentSubscription(),
        _businessProfileRepo.getBusinessProfile(),
        _v2Service.load(),
      ]);

      if (!mounted) return; // Check again after async operations

      final subscription = results[3] as Subscription?;
      
      // Load unread notifications after subscription is loaded
      final unreadCount = await _loadUnreadNotifications(subscription);
      final v2 = results[5] as SmeDashboardV2Data;

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _pendingTasks = results[1] as Map<String, dynamic>;
        _salesByChannel = results[2] as List<SalesByChannel>;
        _subscription = subscription;
        _businessProfile = results[4] as BusinessProfile?;
        _unreadNotifications = unreadCount;
        _v2 = v2;
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
      final todayStartLocal = DateTime(today.year, today.month, today.day);
      final todayEndLocal = todayStartLocal.add(const Duration(days: 1));
      final todayStartUtc = todayStartLocal.toUtc();
      final todayEndUtc = todayEndLocal.toUtc();

      // Get sales by channel from reports (already includes bookings and consignment)
      final channels = await _reportsRepo.getSalesByChannel(
        startDate: todayStartUtc,
        endDate: todayEndUtc,
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

                  // V2: Today Snapshot (Masuk/Belanja/Untung/Transaksi)
                  if (_v2 != null)
                    TodaySnapshotHeroV2(
                      inflow: _v2!.today.inflow,
                      expense: _v2!.today.expense,
                      profit: _v2!.today.profit,
                      transactions: _v2!.today.transactions,
                    ),

                  const SizedBox(height: 16),

                  // V2: Cashflow Minggu Ini (Ahad–Sabtu)
                  if (_v2 != null)
                    WeeklyCashflowCardV2(
                      inflow: _v2!.week.inflow,
                      expense: _v2!.week.expense,
                      net: _v2!.week.net,
                    ),

                  const SizedBox(height: 16),

                  // V2: Top Produk (cross-channel)
                  if (_v2 != null)
                    TopProductsCardsV2(
                      todayTop3: _v2!.topProducts.todayTop3,
                      weekTop3: _v2!.topProducts.weekTop3,
                    ),

                  const SizedBox(height: 16),

                  // V2: Cadangan produksi (rule-based)
                  if (_v2?.productionSuggestion.show == true)
                    ProductionSuggestionCardV2(
                      title: _v2!.productionSuggestion.title,
                      message: _v2!.productionSuggestion.message,
                      onStartProduction: () => Navigator.of(context).pushNamed('/production'),
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
                    pendingPOs: _pendingTasks?['pendingPOs'] ?? 0,
                    lowStockCount: _pendingTasks?['lowStockCount'] ?? 0,
                    onViewBookings: () => Navigator.of(context).pushNamed('/bookings'),
                    onViewPOs: () => Navigator.of(context).pushNamed('/purchase-orders'),
                    onViewStock: () => Navigator.of(context).pushNamed('/stock'),
                  ),

                  const SizedBox(height: 20),

                  // V2: Insight ringkas (rule-based)
                  if (_v2 != null)
                    SmartInsightsCardV2(
                      data: _v2!,
                      onAddSale: () => Navigator.of(context).pushNamed('/sales/create'),
                      onAddExpense: () => Navigator.of(context).pushNamed('/expenses'),
                      onAddStock: () => Navigator.of(context).pushNamed('/stock'),
                      onViewSales: () => Navigator.of(context).pushNamed('/sales'),
                    ),

                  const SizedBox(height: 20),

                  // V2: Primary quick actions (5)
                  PrimaryQuickActionsV2(
                    onAddSale: () => Navigator.of(context).pushNamed('/sales/create'),
                    onScanReceipt: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReceiptScanPage()),
                    ),
                    onStartProduction: () => Navigator.of(context).pushNamed('/production'),
                    onAddStock: () => Navigator.of(context).pushNamed('/stock'),
                    onAddExpense: () => Navigator.of(context).pushNamed('/expenses'),
                  ),

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

