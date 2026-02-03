import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/cache_service.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/repositories/announcements_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../../announcements/presentation/notifications_page.dart';
import '../../subscription/services/subscription_service.dart';
import '../../subscription/data/models/subscription.dart';
import '../../reports/data/repositories/reports_repository_supabase.dart';
import '../../reports/data/models/sales_by_channel.dart';
import '../domain/sme_dashboard_v2_models.dart';
import '../services/sme_dashboard_v2_service.dart';
import '../services/dashboard_cache_service.dart';
import 'widgets/v3/hero_section_v3.dart';
import 'widgets/v3/alert_bar_v3.dart';
import 'widgets/v3/dashboard_tabs_v3.dart';
import 'widgets/v3/tab_ringkasan_v3.dart';
import 'widgets/v3/tab_jualan_v3.dart';
import 'widgets/v3/tab_stok_v3.dart';
import 'widgets/v3/tab_insight_v3.dart';
import 'widgets/v2/primary_quick_actions_v2.dart';
import '../../expenses/presentation/receipt_scan_page.dart';

/// Dashboard Page V3 - Clean, focused, action-first design
/// Concept: "Buka → Tengok → Tindakan → Tutup"
class DashboardPageV3 extends StatefulWidget {
  const DashboardPageV3({super.key});

  @override
  State<DashboardPageV3> createState() => _DashboardPageV3State();
}

class _DashboardPageV3State extends State<DashboardPageV3> {
  final _businessProfileRepo = BusinessProfileRepository();
  final _announcementsRepo = AnnouncementsRepositorySupabase();
  final _v2Service = SmeDashboardV2Service();
  final _dashboardCache = DashboardCacheService();
  final _reportsRepo = ReportsRepositorySupabase();

  // Data
  BusinessProfile? _businessProfile;
  SmeDashboardV2Data? _v2Data;
  Subscription? _subscription;
  List<SalesByChannel> _salesByChannel = [];
  int _unreadNotifications = 0;
  int _todayTransactionCount = 0;
  double? _yesterdayInflow;
  bool _loading = true;
  bool _hasUrgentIssues = false;

  // Tab state
  int _selectedTabIndex = 0;

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  // Real-time subscriptions
  StreamSubscription? _salesSubscription;
  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _expensesSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _expensesSubscription?.cancel();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      _salesSubscription = supabase
          .from('sales')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      _bookingsSubscription = supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      _expensesSubscription = supabase
          .from('expenses')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      debugPrint('DashboardV3 real-time subscriptions setup complete');
    } catch (e) {
      debugPrint('Error setting up DashboardV3 subscriptions: $e');
    }
  }

  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _dashboardCache.invalidateAll();
        _loadAllData();
      }
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Load critical data in parallel
      final results = await Future.wait([
        _dashboardCache.getDashboardV2Cached(
          onDataUpdated: (data) {
            if (mounted) setState(() => _v2Data = data);
          },
        ),
        _dashboardCache.getSubscriptionCached(
          onDataUpdated: (sub) {
            if (mounted) setState(() => _subscription = sub);
          },
        ),
        CacheService.getOrFetch(
          'dashboard_business_profile',
          () => _businessProfileRepo.getBusinessProfile(),
          ttl: const Duration(minutes: 30),
        ),
        CacheService.getOrFetch(
          'dashboard_unread_notifications',
          () => _loadUnreadNotifications(),
          ttl: const Duration(minutes: 1),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _v2Data = results[0] as SmeDashboardV2Data;
        _subscription = results[1] as Subscription?;
        _businessProfile = results[2] as BusinessProfile?;
        _unreadNotifications = results[3] as int;
        _loading = false;
      });

      // Load secondary data in background
      _loadSecondaryData();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadSecondaryData() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day).toUtc();
      final todayEnd = todayStart.add(const Duration(days: 1));

      final results = await Future.wait([
        _dashboardCache.getSalesByChannelCached(
          startDate: todayStart,
          endDate: todayEnd,
          onDataUpdated: (channels) {
            if (mounted) setState(() => _salesByChannel = channels);
          },
        ),
        _loadTodayTransactionCount(),
        _loadYesterdayInflow(),
      ]);

      if (mounted) {
        setState(() {
          _salesByChannel = results[0] as List<SalesByChannel>;
          _todayTransactionCount = results[1] as int;
          _yesterdayInflow = results[2] as double?;
        });
      }
    } catch (e) {
      debugPrint('Error loading secondary data: $e');
    }
  }

  Future<int> _loadUnreadNotifications() async {
    try {
      String? subscriptionStatus;
      if (_subscription != null) {
        if (_subscription!.isOnTrial) {
          subscriptionStatus = 'trial';
        } else if (_subscription!.status == SubscriptionStatus.active) {
          subscriptionStatus = 'active';
        } else if (_subscription!.status == SubscriptionStatus.expired) {
          subscriptionStatus = 'expired';
        }
      }
      return await _announcementsRepo.getUnreadCount(
        subscriptionStatus: subscriptionStatus,
      );
    } catch (e) {
      return 0;
    }
  }

  Future<int> _loadTodayTransactionCount() async {
    try {
      // Count sales + completed bookings for today
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final salesCount = await supabase
          .from('sales')
          .select('id')
          .eq('business_owner_id', supabase.auth.currentUser!.id)
          .gte('created_at', todayStart.toIso8601String())
          .count();

      return salesCount.count;
    } catch (e) {
      return 0;
    }
  }

  Future<double?> _loadYesterdayInflow() async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStart = DateTime(yesterday.year, yesterday.month, yesterday.day).toUtc();
      final yesterdayEnd = yesterdayStart.add(const Duration(days: 1));

      final response = await supabase
          .from('sales')
          .select('total_amount')
          .eq('business_owner_id', supabase.auth.currentUser!.id)
          .gte('created_at', yesterdayStart.toIso8601String())
          .lt('created_at', yesterdayEnd.toIso8601String());

      double total = 0;
      for (final sale in response) {
        total += (sale['total_amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      return null;
    }
  }

  void _openMoreActionsModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Menu Lain',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: [
                    _buildModalAction('Penghantaran', Icons.local_shipping_rounded, Colors.orange, '/deliveries'),
                    _buildModalAction('Belanja', Icons.payments_rounded, Colors.red, '/expenses'),
                    _buildModalAction('Scan Resit', Icons.document_scanner_rounded, Colors.teal, null, onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptScanPage()));
                    }),
                    _buildModalAction('Tempahan', Icons.event_note_rounded, Colors.indigo, '/bookings'),
                    _buildModalAction('Purchase Order', Icons.shopping_bag_rounded, Colors.blue, '/purchase-orders'),
                    _buildModalAction('Tuntutan', Icons.receipt_long_rounded, Colors.deepOrange, '/claims'),
                    _buildModalAction('Laporan', Icons.bar_chart_rounded, Colors.purple, '/reports'),
                    _buildModalAction('Dokumen', Icons.folder_open_rounded, Colors.brown, '/documents'),
                    _buildModalAction('Tetapan', Icons.settings_rounded, Colors.grey, '/settings'),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalAction(String label, IconData icon, Color color, String? route, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          Navigator.pop(context);
          if (route != null) Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userName = _businessProfile?.businessName ??
                     user?.email?.split('@').first ??
                     'User';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // App bar spacer (for status bar)
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
                  ),

                  // Hero Section (always visible at top)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: HeroSectionV3(
                        userName: userName,
                        todayInflow: _v2Data?.today.inflow ?? 0,
                        todayProfit: _v2Data?.today.profit ?? 0,
                        todayTransactionCount: _todayTransactionCount,
                        yesterdayInflow: _yesterdayInflow,
                        unreadNotifications: _unreadNotifications,
                        onAddSale: () => Navigator.pushNamed(context, '/sales/create'),
                        onAddStock: () => Navigator.pushNamed(context, '/stock'),
                        onStartProduction: () => Navigator.pushNamed(context, '/production'),
                        onMoreActions: _openMoreActionsModal,
                        onNotificationTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsPage()),
                          ).then((_) => _loadAllData());
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Alert Bar (collapsible)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: AlertBarV3(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Tab Navigation
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DashboardTabsV3(
                        selectedIndex: _selectedTabIndex,
                        onTabSelected: (index) {
                          setState(() => _selectedTabIndex = index);
                        },
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Tab Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildTabContent(),
                    ),
                  ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return TabRingkasanV3(
          data: _v2Data,
          onViewAllProducts: () => Navigator.pushNamed(context, '/finished-products'),
        );
      case 1:
        return TabJualanV3(
          salesByChannel: _salesByChannel,
          onViewAllBookings: () => Navigator.pushNamed(context, '/bookings'),
        );
      case 2:
        return TabStokV3(
          onViewStock: () => Navigator.pushNamed(context, '/stock'),
          onCreatePO: () => Navigator.pushNamed(context, '/purchase-orders'),
        );
      case 3:
        return TabInsightV3(
          data: _v2Data,
          hasUrgentIssues: _hasUrgentIssues,
          onStartProduction: () => Navigator.pushNamed(context, '/production'),
          onAddSale: () => Navigator.pushNamed(context, '/sales/create'),
          onViewFinishedProducts: () => Navigator.pushNamed(context, '/finished-products'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
