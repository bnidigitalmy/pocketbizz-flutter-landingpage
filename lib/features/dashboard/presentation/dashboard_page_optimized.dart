import 'dart:async';
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
import 'widgets/purchase_recommendations_widget.dart';
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
import '../../../data/repositories/finished_products_repository_supabase.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../core/services/cache_service.dart';
import 'widgets/v2/production_suggestion_card_v2.dart';
import 'widgets/v2/primary_quick_actions_v2.dart';
import 'widgets/v2/finished_products_alerts_v2.dart';
import 'widgets/v2/smart_insights_card_v2.dart';
import 'widgets/v2/today_snapshot_hero_v2.dart';
import 'widgets/v2/top_products_cards_v2.dart';
import 'widgets/v2/weekly_cashflow_card_v2.dart';
import 'widgets/booking_alerts_widget.dart';

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
  bool _hasUrgentIssuesFlag = false; // Cached urgent issues flag
  bool _isLoadingData = false; // Prevent double loading

  // Real-time subscriptions for dashboard metrics
  StreamSubscription? _salesSubscription;
  StreamSubscription? _saleItemsSubscription;
  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _bookingItemsSubscription;
  StreamSubscription? _claimsSubscription;
  StreamSubscription? _claimItemsSubscription;
  StreamSubscription? _expensesSubscription;
  StreamSubscription? _productsSubscription;
  Timer? _debounceTimer;
  
  // Scroll controller to preserve scroll position during rebuilds
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    _loadAllData();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    _saleItemsSubscription?.cancel();
    _bookingsSubscription?.cancel();
    _bookingItemsSubscription?.cancel();
    _claimsSubscription?.cancel();
    _claimItemsSubscription?.cancel();
    _expensesSubscription?.cancel();
    _productsSubscription?.cancel();
    _debounceTimer?.cancel();
    _scrollEndTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Setup scroll listener to detect when user is scrolling
  /// This prevents rebuilds during active scrolling
  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Mark as scrolling when scroll position changes
      if (!_isScrolling) {
        _isScrolling = true;
      }
      
      // Cancel previous timer
      _scrollEndTimer?.cancel();
      
      // Set timer to mark scrolling as ended after scroll stops
      // Wait 500ms after last scroll event to consider scrolling stopped
      _scrollEndTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _isScrolling = false;
        }
      });
    });
  }

  /// Setup real-time subscriptions for all dashboard-related tables
  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to sales table changes (affects Masuk/Untung)
      _salesSubscription = supabase
          .from('sales')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to sale_items table changes (affects Kos/Production Cost)
      _saleItemsSubscription = supabase
          .from('sale_items')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to bookings table changes (affects Masuk when status = completed)
      _bookingsSubscription = supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to booking_items table changes (affects Kos)
      _bookingItemsSubscription = supabase
          .from('booking_items')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to consignment_claims table changes (affects Masuk when status = settled)
      _claimsSubscription = supabase
          .from('consignment_claims')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to consignment_claim_items table changes (affects Kos)
      _claimItemsSubscription = supabase
          .from('consignment_claim_items')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to expenses table changes (affects Belanja)
      _expensesSubscription = supabase
          .from('expenses')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to products table changes (affects Kos if cost_per_unit changes)
      _productsSubscription = supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      debugPrint('✅ Dashboard real-time subscriptions setup complete');
    } catch (e) {
      debugPrint('⚠️ Error setting up dashboard real-time subscriptions: $e');
      // Continue without real-time - fallback to manual refresh
    }
  }

  /// Debounced refresh to avoid excessive updates
  /// Invalidates cache when real-time detects changes
  /// Delays refresh if user is actively scrolling to prevent scroll jitter
  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    
    // If user is scrolling, wait longer before refreshing
    final delay = _isScrolling 
        ? const Duration(milliseconds: 3000) // Wait 3 seconds if scrolling
        : const Duration(milliseconds: 1000); // Normal 1 second delay
    
    _debounceTimer = Timer(delay, () {
      if (mounted && !_isScrolling) {
        // Only refresh if user is not actively scrolling
        // Invalidate dashboard cache when real-time detects changes
        CacheService.invalidateMultiple([
          'dashboard_stats',
          'dashboard_v2',
          'dashboard_pending_tasks',
          'dashboard_sales_by_channel',
          'dashboard_urgent_issues',
        ]);
        _loadAllData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh if not already loading (prevent double loading)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLoadingData && _stats == null) {
        _loadAllData();
      }
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted || _isLoadingData) return;
    
    _isLoadingData = true;
    setState(() => _loading = true);

    try {
      // Run planner auto-service in background (non-blocking)
      // Don't wait for it - let it run while we load critical data
      _plannerAuto.runAll().catchError((e) {
        debugPrint('Planner auto-service error (non-critical): $e');
      });

      // Load critical data first (what user needs to see immediately)
      // Use cache for faster loading - invalidated by real-time subscriptions
      final criticalResults = await Future.wait([
        CacheService.getOrFetch(
          'dashboard_stats',
          () => _bookingsRepo.getStatistics(),
          ttl: const Duration(minutes: 5),
        ),
        CacheService.getOrFetch(
          'dashboard_v2',
          () => _v2Service.load(),
          ttl: const Duration(minutes: 5),
        ),
        CacheService.getOrFetch(
          'dashboard_subscription',
          () => SubscriptionService().getCurrentSubscription(),
          ttl: const Duration(minutes: 10), // Subscription changes less frequently
        ),
      ]);

      if (!mounted) {
        _isLoadingData = false;
        return;
      }

      final subscription = criticalResults[2] as Subscription?;
      final v2 = criticalResults[1] as SmeDashboardV2Data;

      // Show critical data immediately (progressive loading)
      setState(() {
        _stats = criticalResults[0] as Map<String, dynamic>;
        _subscription = subscription;
        _v2 = v2;
        _loading = false; // Show dashboard with critical data
      });

      // Load secondary data in background (non-blocking)
      _loadSecondaryData(subscription).catchError((e) {
        debugPrint('Error loading secondary dashboard data: $e');
      });

    } catch (e) {
      if (!mounted) {
        _isLoadingData = false;
        return;
      }
      setState(() => _loading = false);
      _isLoadingData = false;
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

  /// Load secondary/non-critical data in background
  /// Uses cache for faster loading
  Future<void> _loadSecondaryData(Subscription? subscription) async {
    try {
      // Load all secondary data in parallel with cache
      final results = await Future.wait([
        CacheService.getOrFetch(
          'dashboard_pending_tasks',
          () => _loadPendingTasks(),
          ttl: const Duration(minutes: 3),
        ),
        CacheService.getOrFetch(
          'dashboard_sales_by_channel',
          () => _loadSalesByChannel(),
          ttl: const Duration(minutes: 5),
        ),
        CacheService.getOrFetch(
          'dashboard_business_profile',
          () => _businessProfileRepo.getBusinessProfile(),
          ttl: const Duration(minutes: 30), // Business profile rarely changes
        ),
        CacheService.getOrFetch(
          'dashboard_urgent_issues',
          () => _checkUrgentIssues(),
          ttl: const Duration(minutes: 2), // Urgent issues need frequent checks
        ),
        CacheService.getOrFetch(
          'dashboard_unread_notifications',
          () => _loadUnreadNotifications(subscription),
          ttl: const Duration(minutes: 1), // Notifications need frequent updates
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _pendingTasks = results[0] as Map<String, dynamic>;
        _salesByChannel = results[1] as List<SalesByChannel>;
        _businessProfile = results[2] as BusinessProfile?;
        _hasUrgentIssuesFlag = results[3] as bool;
        _unreadNotifications = results[4] as int;
      });
    } catch (e) {
      debugPrint('Error loading secondary dashboard data: $e');
      // Don't show error to user - secondary data is optional
    } finally {
      _isLoadingData = false;
    }
  }

  Future<Map<String, dynamic>> _loadPendingTasks() async {
    try {
      // Optimize: Use parallel queries instead of loading all POs
      final results = await Future.wait([
        // Query only pending POs (more efficient than loading all and filtering)
        _poRepo.getAllPurchaseOrders(limit: 100).then((pos) => 
          pos.where((po) => po.status == 'pending').length
        ),
        _stockRepo.getLowStockItems().then((items) => items.length),
      ]);

      return {
        'pendingPOs': results[0] as int,
        'lowStockCount': results[1] as int,
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
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // Subscription Expiring Alert
                  if (_subscription != null && _subscription!.isExpiringSoon)
                    _buildSubscriptionAlert(),

                  // Morning Briefing Card (Adaptive based on mood)
                  MorningBriefingCard(
                    userName: _businessProfile?.businessName ?? 
                              user?.email?.split('@').first ?? 
                              'SME Owner',
                    hasUrgentIssues: _hasUrgentIssues(),
                  ),

                  const SizedBox(height: 20),

                  // V2: Today Snapshot (Masuk/Kos/Untung/Belanja)
                  if (_v2 != null)
                    TodaySnapshotHeroV2(
                      inflow: _v2!.today.inflow,
                      productionCost: _v2!.today.productionCost,
                      profit: _v2!.today.profit,
                      expense: _v2!.today.expense,
                    ),

                  const SizedBox(height: 16),

                  // V2: Primary quick actions (moved up for action-first)
                  PrimaryQuickActionsV2(
                    onAddSale: () => Navigator.of(context).pushNamed('/sales/create'),
                    onAddStock: () => Navigator.of(context).pushNamed('/stock'),
                    onStartProduction: () => Navigator.of(context).pushNamed('/production'),
                    onDelivery: () => Navigator.of(context).pushNamed('/deliveries'),
                    onAddExpense: () => Navigator.of(context).pushNamed('/expenses'),
                    moreActions: [
                      MoreQuickActionV2(
                        label: 'Scan Resit',
                        icon: Icons.document_scanner_rounded,
                        color: Colors.orange,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReceiptScanPage()),
                        ),
                      ),
                      MoreQuickActionV2(
                        label: 'Tempahan',
                        icon: Icons.event_note_rounded,
                        color: Colors.indigo,
                        onTap: () => Navigator.of(context).pushNamed('/bookings'),
                      ),
                      MoreQuickActionV2(
                        label: 'PO',
                        icon: Icons.shopping_bag_rounded,
                        color: Colors.blue,
                        onTap: () => Navigator.of(context).pushNamed('/purchase-orders'),
                      ),
                      MoreQuickActionV2(
                        label: 'Tuntutan',
                        icon: Icons.receipt_long_rounded,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.of(context).pushNamed('/claims'),
                      ),
                      MoreQuickActionV2(
                        label: 'Laporan',
                        icon: Icons.bar_chart_rounded,
                        color: Colors.purple,
                        onTap: () => Navigator.of(context).pushNamed('/reports'),
                      ),
                      MoreQuickActionV2(
                        label: 'Dokumen',
                        icon: Icons.folder_open_rounded,
                        color: Colors.teal,
                        onTap: () => Navigator.of(context).pushNamed('/documents'),
                      ),
                      MoreQuickActionV2(
                        label: 'Komuniti',
                        icon: Icons.groups_rounded,
                        color: Colors.green,
                        onTap: () => Navigator.of(context).pushNamed('/community'),
                      ),
                      MoreQuickActionV2(
                        label: 'Langganan',
                        icon: Icons.workspace_premium_rounded,
                        color: Colors.amber,
                        onTap: () => Navigator.of(context).pushNamed('/subscription'),
                      ),
                      MoreQuickActionV2(
                        label: 'Tetapan',
                        icon: Icons.settings_rounded,
                        color: Colors.grey,
                        onTap: () => Navigator.of(context).pushNamed('/settings'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Sales by Channel Card
                  if (_salesByChannel.isNotEmpty) ...[
                    SalesByChannelCard(
                      salesByChannel: _salesByChannel,
                      totalRevenue: (_salesByChannel.fold<double>(
                        0.0,
                        (sum, channel) => sum + channel.revenue,
                      ) * 100).round() / 100, // Round to 2 decimal places to match database precision
                    ),
                    const SizedBox(height: 16),
                  ],

                  // V2: Smart Insights (CADANGAN) - Adaptive suggestions (moved below Sales by Channel)
                  if (_v2 != null) ...[
                    SmartInsightsCardV2(
                      data: _v2!,
                      hasUrgentIssues: _hasUrgentIssues(),
                      onAddSale: () => Navigator.of(context).pushNamed('/sales/create'),
                      onAddExpense: () => Navigator.of(context).pushNamed('/expenses'),
                      onViewFinishedStock: () => Navigator.of(context).pushNamed('/finished-products'),
                      onViewSales: () => Navigator.of(context).pushNamed('/sales'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Planner mini widget (moved below performance for less stress)
                  PlannerTodayCard(
                    onViewAll: () => Navigator.of(context).pushNamed('/planner'),
                  ),

                  const SizedBox(height: 20),

                  // Booking Alerts (overdue, upcoming, pending)
                  const BookingAlertsWidget(),

                  const SizedBox(height: 20),

                  // Tindakan Segera (action-first)
                  UrgentActionsWidget(
                    pendingBookings: _stats?['pending'] ?? 0,
                    pendingPOs: _pendingTasks?['pendingPOs'] ?? 0,
                    lowStockCount: _pendingTasks?['lowStockCount'] ?? 0,
                    onViewBookings: () => Navigator.of(context).pushNamed('/bookings'),
                    onViewPOs: () => Navigator.of(context).pushNamed('/purchase-orders'),
                    onViewStock: () => Navigator.of(context).pushNamed('/stock'),
                  ),

                  const SizedBox(height: 20),

                  // V2: Stok produk siap (alert awal)
                  FinishedProductsAlertsV2(
                    onViewAll: () => Navigator.of(context).pushNamed('/finished-products'),
                  ),

                  const SizedBox(height: 20),

                  // Stok bahan mentah (low stock)
                  const LowStockAlertsWidget(),

                  const SizedBox(height: 20),

                  // Cadangan Pembelian (purchase recommendations)
                  const PurchaseRecommendationsWidget(),

                  const SizedBox(height: 20),

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

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// Check for urgent issues that require immediate attention
  /// Returns true if: stok = 0, order overdue, batch expired
  Future<bool> _checkUrgentIssues() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Optimize: Check urgent issues in parallel with specific queries
      final results = await Future.wait([
        // Check 1: Stock items with quantity = 0 (use count query instead of loading all)
        _stockRepo.getAllStockItems(limit: 50).then((items) => 
          items.any((item) => item.currentQuantity <= 0)
        ).catchError((_) => false),
        
        // Check 2: Overdue bookings (optimize by checking date in query if possible)
        Future.wait([
          _bookingsRepo.listBookings(status: 'pending', limit: 50),
          _bookingsRepo.listBookings(status: 'confirmed', limit: 50),
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

        // Check 3: Expired batches (load summary only)
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
          })
          .catchError((_) => false),
      ]);

      return (results[0] as bool) || (results[1] as bool) || (results[2] as bool);
    } catch (e) {
      // If check fails, return false to avoid blocking dashboard
      debugPrint('Error checking urgent issues: $e');
      return false;
    }
  }

  /// Get cached urgent issues flag
  bool _hasUrgentIssues() {
    return _hasUrgentIssuesFlag;
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

