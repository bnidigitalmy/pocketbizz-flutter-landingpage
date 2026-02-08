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
import '../../subscription/data/models/subscription.dart';
import '../../reports/data/repositories/reports_repository_supabase.dart';
import '../../reports/data/models/sales_by_channel.dart';
import '../domain/sme_dashboard_v2_models.dart';
import '../services/sme_dashboard_v2_service.dart';
import '../services/dashboard_cache_service.dart';
import '../../../data/repositories/bookings_repository_supabase_cached.dart';
import '../../../data/repositories/stock_repository_supabase_cached.dart' show StockRepositorySupabaseCached;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/repositories/finished_products_repository_supabase.dart';
import 'widgets/v3/hero_section_v3.dart';
import 'widgets/v3/alert_bar_v3.dart';
import 'widgets/v3/dashboard_tabs_v3.dart';
import 'widgets/v3/tab_ringkasan_v3.dart';
import 'widgets/v3/tab_jualan_v3.dart';
import 'widgets/v3/tab_stok_v3.dart';
import 'widgets/v3/tab_insight_v3.dart';
import 'widgets/v3/dashboard_skeleton_v3.dart';
import '../../expenses/presentation/receipt_scan_page.dart';
import '../../planner/presentation/widgets/planner_today_card.dart';
import 'widgets/v2/finished_products_alerts_v2.dart';

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
  final _stockRepo = StockRepository(supabase);
  final _finishedProductsRepo = FinishedProductsRepository();

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
  String? _errorMessage;
  bool _hasError = false;
  
  // Bookings data for TabJualanV3
  int _todayBookingsCount = 0;
  double _todayBookingsAmount = 0;
  int _tomorrowBookingsCount = 0;
  double _tomorrowBookingsAmount = 0;
  int _weekBookingsCount = 0;
  double _weekBookingsAmount = 0;
  
  // Scroll position preservation
  bool _isScrolling = false;
  Timer? _scrollEndTimer;
  double _lastScrollPosition = 0.0;

  // Tab state
  int _selectedTabIndex = 0;

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  // Keys removed - not needed with current implementation

  // Real-time subscriptions
  StreamSubscription? _salesSubscription;
  StreamSubscription? _saleItemsSubscription;
  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _bookingItemsSubscription;
  StreamSubscription? _claimsSubscription;
  StreamSubscription? _claimItemsSubscription;
  StreamSubscription? _expensesSubscription;
  StreamSubscription? _productsSubscription;
  Timer? _debounceTimer;

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
  void _setupScrollListener() {
    _scrollController.addListener(() {
      _lastScrollPosition = _scrollController.offset;
      
      if (!_isScrolling) {
        _isScrolling = true;
      }
      
      _scrollEndTimer?.cancel();
      _scrollEndTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _isScrolling = false;
          if (_scrollController.hasClients && 
              _scrollController.offset != _lastScrollPosition) {
            _scrollController.jumpTo(_lastScrollPosition);
          }
        }
      });
    });
  }

  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to sales table changes (affects Masuk/Untung)
      _salesSubscription = supabase
          .from('sales')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      // Subscribe to sale_items table changes (affects Kos/Production Cost)
      _saleItemsSubscription = supabase
          .from('sale_items')
          .stream(primaryKey: ['id'])
          .listen((_) => _debouncedRefresh());

      // Subscribe to bookings table changes (affects Masuk when status = completed)
      _bookingsSubscription = supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      // Subscribe to booking_items table changes (affects Kos)
      _bookingItemsSubscription = supabase
          .from('booking_items')
          .stream(primaryKey: ['id'])
          .listen((_) => _debouncedRefresh());

      // Subscribe to consignment_claims table changes (affects Masuk when status = settled)
      _claimsSubscription = supabase
          .from('consignment_claims')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      // Subscribe to consignment_claim_items table changes (affects Kos)
      _claimItemsSubscription = supabase
          .from('consignment_claim_items')
          .stream(primaryKey: ['id'])
          .listen((_) => _debouncedRefresh());

      // Subscribe to expenses table changes (affects Belanja)
      _expensesSubscription = supabase
          .from('expenses')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      // Subscribe to products table changes (affects Kos if cost_per_unit changes)
      _productsSubscription = supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      debugPrint('✅ DashboardV3 real-time subscriptions setup complete');
    } catch (e) {
      debugPrint('⚠️ Error setting up DashboardV3 subscriptions: $e');
    }
  }

  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    
    // If user is scrolling, wait longer before refreshing
    final delay = _isScrolling 
        ? const Duration(milliseconds: 3000) // Wait 3 seconds if scrolling
        : const Duration(milliseconds: 1000); // Normal 1 second delay
    
    _debounceTimer = Timer(delay, () {
      if (mounted && !_isScrolling) {
        // Only refresh if user is not actively scrolling
        _dashboardCache.invalidateAll();
        CacheService.invalidateMultiple([
          'dashboard_urgent_issues',
          'dashboard_unread_notifications',
          'dashboard_business_profile',
        ]);
        _loadAllData();
      }
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    if (_isLoadingData) return; // Prevent concurrent loads
    _isLoadingData = true;
    
    // Save scroll position before rebuild
    if (_scrollController.hasClients) {
      _lastScrollPosition = _scrollController.offset;
    }
    
    final savedPosition = _lastScrollPosition;
    
    setState(() {
      _loading = true;
      _hasError = false;
      _errorMessage = null;
    });

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
        CacheService.getOrFetch(
          'dashboard_urgent_issues',
          () => _checkUrgentIssues(),
          ttl: const Duration(minutes: 2),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _v2Data = results[0] as SmeDashboardV2Data;
        _subscription = results[1] as Subscription?;
        _businessProfile = results[2] as BusinessProfile?;
        _unreadNotifications = results[3] as int;
        _todayTransactionCount = results[4] as int;
        _hasUrgentIssues = results[5] as bool;
        _loading = false;
      });

      // Restore scroll position after rebuild
      if (mounted && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && 
              _scrollController.offset != savedPosition &&
              !_isScrolling) {
            _scrollController.jumpTo(savedPosition);
          }
        });
      }

      // Load secondary data in background
      _loadSecondaryData();
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
          _errorMessage = _getUserFriendlyError(e);
        });
        
        // Restore scroll position after error
        if (_scrollController.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && 
                _scrollController.offset != savedPosition &&
                !_isScrolling) {
              _scrollController.jumpTo(savedPosition);
            }
          });
        }
      }
    } finally {
      _isLoadingData = false;
    }
  }
  
  String _getUserFriendlyError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Masalah sambungan internet. Sila semak sambungan anda.';
    }
    if (errorStr.contains('timeout')) {
      return 'Masa menunggu tamat. Sila cuba lagi.';
    }
    return 'Ralat memuatkan data. Sila cuba lagi.';
  }
  
  /// Check for urgent issues that require immediate attention
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
        _finishedProductsRepo.getFinishedProductsSummary()
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
      debugPrint('Error checking urgent issues: $e');
      return false;
    }
  }

  Future<void> _loadSecondaryData() async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final tomorrowStart = todayEnd;
      final tomorrowEnd = tomorrowStart.add(const Duration(days: 1));
      final weekStart = _startOfWeekSunday(today);
      final weekEnd = weekStart.add(const Duration(days: 7));
      
      final todayStartUtc = todayStart.toUtc();
      final todayEndUtc = todayEnd.toUtc();
      final tomorrowStartUtc = tomorrowStart.toUtc();
      final tomorrowEndUtc = tomorrowEnd.toUtc();
      final weekStartUtc = weekStart.toUtc();
      final weekEndUtc = weekEnd.toUtc();

      final results = await Future.wait([
        _dashboardCache.getSalesByChannelCached(
          startDate: todayStartUtc,
          endDate: todayEndUtc,
          onDataUpdated: (channels) {
            if (mounted) setState(() => _salesByChannel = channels);
          },
        ),
        _loadYesterdayInflow(),
        _loadBookingsData(todayStartUtc, todayEndUtc, tomorrowStartUtc, tomorrowEndUtc, weekStartUtc, weekEndUtc),
      ]);

      if (mounted) {
        setState(() {
          _salesByChannel = results[0] as List<SalesByChannel>;
          _yesterdayInflow = results[1] as double?;
          final bookingsData = results[2] as Map<String, dynamic>;
          _todayBookingsCount = bookingsData['todayCount'] as int;
          _todayBookingsAmount = bookingsData['todayAmount'] as double;
          _tomorrowBookingsCount = bookingsData['tomorrowCount'] as int;
          _tomorrowBookingsAmount = bookingsData['tomorrowAmount'] as double;
          _weekBookingsCount = bookingsData['weekCount'] as int;
          _weekBookingsAmount = bookingsData['weekAmount'] as double;
        });
      }
    } catch (e) {
      debugPrint('Error loading secondary data: $e');
    }
  }
  
  DateTime _startOfWeekSunday(DateTime date) {
    final weekday = date.weekday;
    final daysFromSunday = weekday % 7;
    return date.subtract(Duration(days: daysFromSunday));
  }
  
  Future<Map<String, dynamic>> _loadBookingsData(
    DateTime todayStartUtc,
    DateTime todayEndUtc,
    DateTime tomorrowStartUtc,
    DateTime tomorrowEndUtc,
    DateTime weekStartUtc,
    DateTime weekEndUtc,
  ) async {
    try {
      final allBookings = await _bookingsRepo.listBookingsCached(limit: 200);
      
      int todayCount = 0;
      double todayAmount = 0;
      int tomorrowCount = 0;
      double tomorrowAmount = 0;
      int weekCount = 0;
      double weekAmount = 0;
      
      for (final booking in allBookings) {
        if (booking.status.toLowerCase() == 'completed' ||
            booking.status.toLowerCase() == 'cancelled') {
          continue;
        }
        
        try {
          final deliveryDate = DateTime.parse(booking.deliveryDate);
          final deliveryDateUtc = deliveryDate.toUtc();
          final totalAmount = booking.totalAmount ?? 0.0;
          
          // Today
          if (deliveryDateUtc.isAfter(todayStartUtc) && deliveryDateUtc.isBefore(todayEndUtc)) {
            todayCount++;
            todayAmount += totalAmount;
          }
          
          // Tomorrow
          if (deliveryDateUtc.isAfter(tomorrowStartUtc) && deliveryDateUtc.isBefore(tomorrowEndUtc)) {
            tomorrowCount++;
            tomorrowAmount += totalAmount;
          }
          
          // This week
          if (deliveryDateUtc.isAfter(weekStartUtc) && deliveryDateUtc.isBefore(weekEndUtc)) {
            weekCount++;
            weekAmount += totalAmount;
          }
        } catch (e) {
          // Skip invalid dates
          continue;
        }
      }
      
      return {
        'todayCount': todayCount,
        'todayAmount': todayAmount,
        'tomorrowCount': tomorrowCount,
        'tomorrowAmount': tomorrowAmount,
        'weekCount': weekCount,
        'weekAmount': weekAmount,
      };
    } catch (e) {
      debugPrint('Error loading bookings data: $e');
      return {
        'todayCount': 0,
        'todayAmount': 0.0,
        'tomorrowCount': 0,
        'tomorrowAmount': 0.0,
        'weekCount': 0,
        'weekAmount': 0.0,
      };
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
      body: _hasError
          ? _buildErrorView()
          : _loading
              ? _buildSkeletonView()
              : RefreshIndicator(
                  onRefresh: _loadAllData,
                  color: AppColors.primary,
                  child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
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

                  // Subscription Expiring Alert
                  if (_subscription != null && _subscription!.isExpiringSoon)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSubscriptionAlert(),
                      ),
                    ),

                  if (_subscription != null && _subscription!.isExpiringSoon)
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Alert Bar (collapsible)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const AlertBarV3(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Tab Navigation
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RepaintBoundary(
                        child: DashboardTabsV3(
                          selectedIndex: _selectedTabIndex,
                          onTabSelected: (index) {
                            // Immediate response for better UX
                            setState(() => _selectedTabIndex = index);
                          },
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Tab Content - Instant switch (no animation for better performance)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RepaintBoundary(
                        child: IndexedStack(
                          index: _selectedTabIndex,
                          children: [
                            _buildTabContent(0),
                            _buildTabContent(1),
                            _buildTabContent(2),
                            _buildTabContent(3),
                          ],
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

  Widget _buildTabContent([int? index]) {
    final tabIndex = index ?? _selectedTabIndex;
    switch (tabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabRingkasanV3(
              data: _v2Data,
              onViewAllProducts: () => Navigator.pushNamed(context, '/finished-products'),
            ),
            const SizedBox(height: 16),
            // Planner Today Card
            PlannerTodayCard(
              onViewAll: () => Navigator.pushNamed(context, '/planner'),
            ),
            const SizedBox(height: 16),
            // Finished Products Alerts
            FinishedProductsAlertsV2(
              onViewAll: () => Navigator.pushNamed(context, '/finished-products'),
            ),
          ],
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
  
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Ralat memuatkan data',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Cuba Lagi'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubscriptionAlert() {
    final days = _subscription!.daysRemaining;
    final isTrial = _subscription!.isOnTrial;

    return Container(
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
