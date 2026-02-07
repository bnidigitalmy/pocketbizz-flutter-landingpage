import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
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
import '../../../data/repositories/bookings_repository_supabase_cached.dart';
import '../../../data/repositories/stock_repository_supabase_cached.dart' show StockRepositorySupabaseCached;
import '../../../data/repositories/finished_products_repository_supabase.dart';
import 'widgets/v3/hero_section_v3.dart';
import 'widgets/v3/alert_bar_v3.dart';
import 'widgets/v3/dashboard_tabs_v3.dart';
import 'widgets/v3/tab_ringkasan_v3.dart';
import 'widgets/v3/tab_jualan_v3.dart';
import 'widgets/v3/tab_stok_v3.dart';
import 'widgets/v3/tab_insight_v3.dart';
import 'widgets/v2/primary_quick_actions_v2.dart';
import 'widgets/v3/dashboard_skeleton_v3.dart';
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
  final _bookingsRepo = BookingsRepositorySupabaseCached();
  final _stockRepoCached = StockRepositorySupabaseCached(supabase);

  // Data
  BusinessProfile? _businessProfile;
  SmeDashboardV2Data? _v2Data;
  Subscription? _subscription;
  List<SalesByChannel> _salesByChannel = [];
  int _unreadNotifications = 0;
  int _todayTransactionCount = 0;
  double? _yesterdayInflow;
  bool _loading = true;
  bool _isLoadingData = false;
  bool _hasUrgentIssues = false;

  // Booking data
  int _todayBookingsCount = 0;
  double _todayBookingsAmount = 0;
  int _tomorrowBookingsCount = 0;
  double _tomorrowBookingsAmount = 0;
  int _weekBookingsCount = 0;
  double _weekBookingsAmount = 0;

  // Tab state
  int _selectedTabIndex = 0;

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  // Keys for child widget refresh
  final _alertBarKey = GlobalKey<AlertBarV3State>();
  final _tabStokKey = GlobalKey<TabStokV3State>();

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
        // Refresh child widgets that manage their own data
        _alertBarKey.currentState?.refresh();
        _tabStokKey.currentState?.refresh();
      }
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    if (_isLoadingData) return; // Prevent concurrent loads
    _isLoadingData = true;
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
        _loadTodayTransactionCount(),
      ]);

      if (!mounted) return;

      setState(() {
        _v2Data = results[0] as SmeDashboardV2Data;
        _subscription = results[1] as Subscription?;
        _businessProfile = results[2] as BusinessProfile?;
        _unreadNotifications = results[3] as int;
        _todayTransactionCount = results[4] as int;
        _loading = false;
      });

      // Load secondary data in background
      _loadSecondaryData();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    } finally {
      _isLoadingData = false;
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
        _loadYesterdayInflow(),
        _loadBookingData(),
        _checkUrgentIssues(),
      ]);

      if (mounted) {
        setState(() {
          _salesByChannel = results[0] as List<SalesByChannel>;
          _yesterdayInflow = results[1] as double?;
          // Booking data is set inside _loadBookingData via setState
          _hasUrgentIssues = results[3] as bool;
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

  Future<void> _loadBookingData() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final weekEnd = today.add(const Duration(days: 7));

      // Load pending and confirmed bookings (upcoming ones)
      final results = await Future.wait([
        _bookingsRepo.listBookingsCached(status: 'pending', limit: 100),
        _bookingsRepo.listBookingsCached(status: 'confirmed', limit: 100),
      ]);

      final allBookings = [...results[0], ...results[1]];

      int todayCount = 0;
      double todayAmount = 0;
      int tomorrowCount = 0;
      double tomorrowAmount = 0;
      int weekCount = 0;
      double weekAmount = 0;

      for (final booking in allBookings) {
        try {
          final deliveryDate = DateTime.parse(booking.deliveryDate);
          final deliveryDateOnly = DateTime(
            deliveryDate.year,
            deliveryDate.month,
            deliveryDate.day,
          );

          if (deliveryDateOnly.isAtSameMomentAs(today)) {
            todayCount++;
            todayAmount += booking.totalAmount;
          } else if (deliveryDateOnly.isAtSameMomentAs(tomorrow)) {
            tomorrowCount++;
            tomorrowAmount += booking.totalAmount;
          }

          // Week includes today through next 7 days
          if (!deliveryDateOnly.isBefore(today) && deliveryDateOnly.isBefore(weekEnd)) {
            weekCount++;
            weekAmount += booking.totalAmount;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _todayBookingsCount = todayCount;
          _todayBookingsAmount = todayAmount;
          _tomorrowBookingsCount = tomorrowCount;
          _tomorrowBookingsAmount = tomorrowAmount;
          _weekBookingsCount = weekCount;
          _weekBookingsAmount = weekAmount;
        });
      }
    } catch (e) {
      debugPrint('Error loading booking data: $e');
    }
  }

  Future<bool> _checkUrgentIssues() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final results = await Future.wait([
        // Check 1: Stock items with quantity = 0
        _stockRepoCached.getAllStockItemsCached(limit: 50).then(
          (items) => items.any((item) => item.currentQuantity <= 0),
        ).catchError((_) => false),

        // Check 2: Overdue bookings
        Future.wait([
          _bookingsRepo.listBookingsCached(status: 'pending', limit: 50),
          _bookingsRepo.listBookingsCached(status: 'confirmed', limit: 50),
        ]).then((results) {
          final allBookings = [...results[0], ...results[1]];
          return allBookings.any((booking) {
            try {
              final deliveryDate = DateTime.parse(booking.deliveryDate);
              final deliveryDateOnly = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
              return deliveryDateOnly.isBefore(today);
            } catch (e) {
              return false;
            }
          });
        }).catchError((_) => false),

        // Check 3: Expired batches
        FinishedProductsRepository()
            .getFinishedProductsSummary()
            .then((products) {
          return products.any((product) {
            if (product.nearestExpiry == null || product.totalRemaining <= 0) {
              return false;
            }
            final expiryDate = product.nearestExpiry!;
            final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
            return expiryDateOnly.isBefore(today);
          });
        }).catchError((_) => false),
      ]);

      return results[0] || results[1] || results[2];
    } catch (e) {
      debugPrint('Error checking urgent issues: $e');
      return false;
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
    return _TapScaleWidget(
      onTap: onTap ?? () {
        HapticFeedback.lightImpact();
        Navigator.pop(context);
        if (route != null) Navigator.pushNamed(context, route);
      },
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
          ? _buildSkeletonView()
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
                        onMenuTap: () => Scaffold.of(context).openDrawer(),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AlertBarV3(key: _alertBarKey),
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

                  // Tab Content with animation
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.05, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_selectedTabIndex),
                          child: _buildTabContent(),
                        ),
                      ),
                    ),
                  ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildSkeletonView() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: HeroSectionSkeleton(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AlertBarSkeleton(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        // Tab bar skeleton
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(4, (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TabRingkasanSkeleton(),
          ),
        ),
      ],
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
          todayBookingsCount: _todayBookingsCount,
          todayBookingsAmount: _todayBookingsAmount,
          tomorrowBookingsCount: _tomorrowBookingsCount,
          tomorrowBookingsAmount: _tomorrowBookingsAmount,
          weekBookingsCount: _weekBookingsCount,
          weekBookingsAmount: _weekBookingsAmount,
          onViewAllBookings: () => Navigator.pushNamed(context, '/bookings'),
        );
      case 2:
        return TabStokV3(
          key: _tabStokKey,
          onViewStock: () => Navigator.pushNamed(context, '/stock'),
          onCreatePO: () => Navigator.pushNamed(context, '/purchase-orders'),
          onViewShoppingList: () => Navigator.pushNamed(context, '/shopping-list'),
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

/// Tap scale animation widget for micro-interactions
class _TapScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScaleWidget({
    required this.child,
    required this.onTap,
  });

  @override
  State<_TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<_TapScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
