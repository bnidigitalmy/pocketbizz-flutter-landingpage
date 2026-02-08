import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import '../../../../../core/supabase/supabase_client.dart' show supabase;
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/repositories/bookings_repository_supabase.dart' show Booking;
import '../../../../../data/repositories/bookings_repository_supabase_cached.dart';
import '../../../../../data/repositories/stock_repository_supabase.dart';
import '../../../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../../../data/models/stock_item.dart';
import '../../../../../data/models/consignment_claim.dart' show ConsignmentClaim, ClaimStatus;

/// Alert severity levels
enum AlertSeverity { urgent, warning, info }

/// Single alert item
class AlertItem {
  final String id;
  final String title;
  final String subtitle;
  final AlertSeverity severity;
  final String actionLabel;
  final String routeName;
  final IconData icon;

  AlertItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.actionLabel,
    required this.routeName,
    required this.icon,
  });
}

/// Consolidated Alert Bar V3
/// Shows all urgent items in one collapsible bar
class AlertBarV3 extends StatefulWidget {
  final VoidCallback? onExpanded;

  const AlertBarV3({super.key, this.onExpanded});

  @override
  State<AlertBarV3> createState() => _AlertBarV3State();
}

class _AlertBarV3State extends State<AlertBarV3> with SingleTickerProviderStateMixin {
  final _bookingsRepo = BookingsRepositorySupabaseCached();
  late final StockRepository _stockRepo;
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();

  bool _isExpanded = false;
  bool _isLoading = true;

  List<AlertItem> _urgentAlerts = [];
  List<AlertItem> _warningAlerts = [];
  List<AlertItem> _infoAlerts = [];

  // Real-time subscriptions
  StreamSubscription? _bookingsSubscription;
  StreamSubscription? _stockSubscription;
  StreamSubscription? _claimsSubscription;
  Timer? _debounceTimer;

  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _stockRepo = StockRepository(supabase);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _loadAlerts();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _stockSubscription?.cancel();
    _claimsSubscription?.cancel();
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      _bookingsSubscription = supabase
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      _stockSubscription = supabase
          .from('stock_items')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      _claimsSubscription = supabase
          .from('consignment_claims')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) => _debouncedRefresh());

      debugPrint('AlertBarV3 real-time subscriptions setup complete');
    } catch (e) {
      debugPrint('Error setting up AlertBarV3 subscriptions: $e');
    }
  }

  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _loadAlerts();
    });
  }

  Future<void> _loadAlerts() async {
    if (!mounted) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final threeDaysFromNow = today.add(const Duration(days: 3));

      // Load all data in parallel
      final results = await Future.wait([
        _bookingsRepo.listBookingsCached(limit: 100),
        _stockRepo.getLowStockItems(),
        _claimsRepo.listClaims(status: ClaimStatus.submitted).then((result) => (result['data'] as List).cast<ConsignmentClaim>()),
      ]);

      final allBookings = results[0] as List<Booking>;
      final lowStockItems = results[1] as List<StockItem>;
      final pendingClaims = results[2] as List<ConsignmentClaim>;

      final urgent = <AlertItem>[];
      final warning = <AlertItem>[];
      final info = <AlertItem>[];

      // Process bookings
      for (final booking in allBookings) {
        if (booking.status.toLowerCase() == 'completed' ||
            booking.status.toLowerCase() == 'cancelled') {
          continue;
        }

        try {
          final deliveryDate = DateTime.parse(booking.deliveryDate);
          final deliveryDateOnly = DateTime(
            deliveryDate.year,
            deliveryDate.month,
            deliveryDate.day,
          );

          // Overdue bookings
          if (deliveryDateOnly.isBefore(today)) {
            urgent.add(AlertItem(
              id: 'booking_overdue_${booking.id}',
              title: 'Tempahan Tertunggak',
              subtitle: '${booking.bookingNumber} - ${booking.customerName}',
              severity: AlertSeverity.urgent,
              actionLabel: 'Lihat',
              routeName: '/bookings',
              icon: Icons.warning_amber_rounded,
            ));
          }
          // Upcoming in 3 days
          else if (deliveryDateOnly.isBefore(threeDaysFromNow) ||
                   deliveryDateOnly.isAtSameMomentAs(today)) {
            warning.add(AlertItem(
              id: 'booking_upcoming_${booking.id}',
              title: 'Tempahan Akan Datang',
              subtitle: '${booking.bookingNumber} - ${_formatDaysUntil(deliveryDateOnly, today)}',
              severity: AlertSeverity.warning,
              actionLabel: 'Lihat',
              routeName: '/bookings',
              icon: Icons.schedule_rounded,
            ));
          }
        } catch (_) {}

        // Pending confirmation
        if (booking.status.toLowerCase() == 'pending') {
          info.add(AlertItem(
            id: 'booking_pending_${booking.id}',
            title: 'Menunggu Pengesahan',
            subtitle: booking.bookingNumber,
            severity: AlertSeverity.info,
            actionLabel: 'Sahkan',
            routeName: '/bookings',
            icon: Icons.pending_actions_rounded,
          ));
        }
      }

      // Process low stock items
      for (final item in lowStockItems) {
        if (item.currentQuantity <= 0) {
          urgent.add(AlertItem(
            id: 'stock_out_${item.id}',
            title: 'Stok Habis',
            subtitle: item.name,
            severity: AlertSeverity.urgent,
            actionLabel: 'Restock',
            routeName: '/stock',
            icon: Icons.error_outline_rounded,
          ));
        } else {
          warning.add(AlertItem(
            id: 'stock_low_${item.id}',
            title: 'Stok Rendah',
            subtitle: '${item.name} (${item.stockLevelPercentage.toStringAsFixed(0)}%)',
            severity: AlertSeverity.warning,
            actionLabel: 'Lihat',
            routeName: '/stock',
            icon: Icons.inventory_2_outlined,
          ));
        }
      }

      // Process pending claims
      for (final claim in pendingClaims.take(5)) {
        info.add(AlertItem(
          id: 'claim_pending_${claim.id}',
          title: 'Tuntutan Pending',
          subtitle: claim.vendorName ?? 'Unknown Vendor',
          severity: AlertSeverity.info,
          actionLabel: 'Proses',
          routeName: '/claims',
          icon: Icons.receipt_long_rounded,
        ));
      }

      if (mounted) {
        setState(() {
          _urgentAlerts = urgent.take(5).toList();
          _warningAlerts = warning.take(5).toList();
          _infoAlerts = info.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading alerts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDaysUntil(DateTime target, DateTime today) {
    final diff = target.difference(today).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Esok';
    return '$diff hari lagi';
  }

  int get _totalAlerts => _urgentAlerts.length + _warningAlerts.length + _infoAlerts.length;

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
        widget.onExpanded?.call();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildCollapsedBar(isLoading: true);
    }

    if (_totalAlerts == 0) {
      return _buildAllClearBar();
    }

    return Column(
      children: [
        // Collapsed/Header bar
        GestureDetector(
          onTap: _toggleExpanded,
          child: _buildCollapsedBar(),
        ),
        // Expanded content
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: _buildExpandedContent(),
        ),
      ],
    );
  }

  Widget _buildCollapsedBar({bool isLoading = false}) {
    final hasUrgent = _urgentAlerts.isNotEmpty;
    final barColor = hasUrgent ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: barColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasUrgent ? Icons.warning_amber_rounded : Icons.notifications_active_rounded,
              color: barColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? Text(
                    'Memuatkan alerts...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalAlerts Perlu Tindakan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: barColor.shade700,
                        ),
                      ),
                      if (_urgentAlerts.isNotEmpty)
                        Text(
                          '${_urgentAlerts.length} urgent',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
          ),
          if (!isLoading) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_totalAlerts',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: barColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllClearBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semua Terkawal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                Text(
                  'Tiada tindakan diperlukan',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.thumb_up,
            color: Colors.green.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Urgent Section
          if (_urgentAlerts.isNotEmpty) ...[
            _buildSectionHeader(
              'URGENT',
              Colors.red,
              Icons.error_outline,
              _urgentAlerts.length,
            ),
            ..._urgentAlerts.asMap().entries.map((e) => _buildAlertItem(e.value, index: e.key)),
            if (_warningAlerts.isNotEmpty || _infoAlerts.isNotEmpty)
              const Divider(height: 24),
          ],

          // Warning Section
          if (_warningAlerts.isNotEmpty) ...[
            _buildSectionHeader(
              'PERHATIAN',
              Colors.orange,
              Icons.warning_amber_outlined,
              _warningAlerts.length,
            ),
            ..._warningAlerts.asMap().entries.map((e) => _buildAlertItem(e.value, index: e.key + _urgentAlerts.length)),
            if (_infoAlerts.isNotEmpty) const Divider(height: 24),
          ],

          // Info Section
          if (_infoAlerts.isNotEmpty) ...[
            _buildSectionHeader(
              'INFO',
              Colors.blue,
              Icons.info_outline,
              _infoAlerts.length,
            ),
            ..._infoAlerts.asMap().entries.map((e) => _buildAlertItem(e.value, index: e.key + _urgentAlerts.length + _warningAlerts.length)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(AlertItem alert, {int index = 0}) {
    final color = switch (alert.severity) {
      AlertSeverity.urgent => Colors.red,
      AlertSeverity.warning => Colors.orange,
      AlertSeverity.info => Colors.blue,
    };

    // Stagger animation for each item
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pushNamed(alert.routeName);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Icon(alert.icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    alert.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                alert.actionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
