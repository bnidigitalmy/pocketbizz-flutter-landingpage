import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/supabase/supabase_client.dart' show supabase;
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../../data/models/consignment_claim.dart';
import '../../../../data/models/delivery.dart';
import '../../../../core/services/user_preferences_service.dart';

/// Claim Alerts Widget for Dashboard
/// Shows:
/// 1. Deliveries ready for claim (has sales, not yet claimed)
/// 2. Outstanding claims (balance > 0)
/// 3. Overdue claims (outstanding > 7 days)
/// With real-time updates via Supabase subscriptions
class ClaimAlertsWidget extends StatefulWidget {
  const ClaimAlertsWidget({super.key});

  @override
  State<ClaimAlertsWidget> createState() => _ClaimAlertsWidgetState();
}

class _ClaimAlertsWidgetState extends State<ClaimAlertsWidget> {
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _deliveriesRepo = DeliveriesRepositorySupabase();
  final _preferencesService = UserPreferencesService();

  List<Delivery> _readyDeliveries = [];
  List<ConsignmentClaim> _outstandingClaims = [];
  List<ConsignmentClaim> _overdueClaims = [];
  bool _isLoading = true;
  int _gracePeriodDays = 7; // Default, will be loaded from preferences

  // Real-time subscriptions
  StreamSubscription? _claimsSubscription;
  StreamSubscription? _deliveriesSubscription;
  StreamSubscription? _deliveryItemsSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAlerts();
    _setupRealtimeSubscriptions();
  }

  Future<void> _loadPreferences() async {
    try {
      final gracePeriod = await _preferencesService.getClaimGracePeriodDays();
      if (mounted) {
        setState(() {
          _gracePeriodDays = gracePeriod;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  @override
  void dispose() {
    _claimsSubscription?.cancel();
    _deliveriesSubscription?.cancel();
    _deliveryItemsSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Setup real-time subscriptions for claims and deliveries
  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to claims changes
      _claimsSubscription = supabase
          .from('consignment_claims')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to deliveries changes
      _deliveriesSubscription = supabase
          .from('vendor_deliveries')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      // Subscribe to delivery items changes (for quantity_sold updates)
      // Note: vendor_delivery_items doesn't have business_owner_id directly,
      // but RLS policies will filter automatically. When delivery items change,
      // we refresh to check for deliveries ready for claim.
      _deliveryItemsSubscription = supabase
          .from('vendor_delivery_items')
          .stream(primaryKey: ['id'])
          .listen((data) {
            if (mounted) {
              _debouncedRefresh();
            }
          });

      debugPrint('✅ Claim Alerts real-time subscriptions setup complete');
    } catch (e) {
      debugPrint('⚠️ Error setting up claim alerts real-time subscriptions: $e');
    }
  }

  /// Debounced refresh to avoid excessive updates
  void _debouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadAlerts();
      }
    });
  }

  Future<void> _loadAlerts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Load all claims
      final allClaims = await _claimsRepo.getAll(limit: 200);
      
      // Load all deliveries
      final deliveriesResult = await _deliveriesRepo.getAllDeliveries(limit: 200, offset: 0);
      final allDeliveries = deliveriesResult['data'] as List<Delivery>;

      // Get claimed delivery IDs for all vendors
      // Query all claims first, then get their delivery IDs
      final claimedDeliveryIds = <String>{};
      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          // Get all claims (any status that blocks new claims)
          final claimsResponse = await supabase
              .from('consignment_claims')
              .select('id')
              .eq('business_owner_id', userId)
              .inFilter('status', ['draft', 'submitted', 'approved', 'settled', 'rejected']);
          
          final claims = (claimsResponse as List).cast<Map<String, dynamic>>();
          if (claims.isNotEmpty) {
            final claimIds = claims.map((c) => c['id'] as String).toList();
            
            // Get delivery IDs from claim items
            final itemsResponse = await supabase
                .from('consignment_claim_items')
                .select('delivery_id')
                .inFilter('claim_id', claimIds);
            
            final items = (itemsResponse as List).cast<Map<String, dynamic>>();
            for (final item in items) {
              final deliveryId = item['delivery_id'] as String?;
              if (deliveryId != null && deliveryId.isNotEmpty) {
                claimedDeliveryIds.add(deliveryId);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading claimed delivery IDs: $e');
      }

      // Filter deliveries ready for claim
      // Alert appears X days after delivery date as reminder to check with vendor
      // User will update quantities (sold/unsold/expired/damaged) based on info from vendor
      final readyDeliveries = <Delivery>[];
      final now = DateTime.now(); // Use single now for all calculations
      
      // Grace period: Alert appears X days after delivery date (from user preferences)
      // This reminds user to check stock status with vendor and create claim
      for (final delivery in allDeliveries) {
        // Skip if already claimed
        if (claimedDeliveryIds.contains(delivery.id)) continue;
        
        // Check grace period: show alert after X days from delivery date
        // This serves as reminder to check with vendor about stock status
        final daysSinceDelivery = now.difference(delivery.deliveryDate).inDays;
        if (daysSinceDelivery >= _gracePeriodDays) {
          readyDeliveries.add(delivery);
        }
      }

      // Filter outstanding claims (balance > 0)
      final outstanding = <ConsignmentClaim>[];
      final overdue = <ConsignmentClaim>[];

      for (final claim in allClaims) {
        final balance = claim.balanceAmount;
        if (balance > 0) {
          outstanding.add(claim);
          
          // Check if overdue (> 7 days from claim date)
          final daysSinceClaim = now.difference(claim.claimDate).inDays;
          if (daysSinceClaim > 7) {
            overdue.add(claim);
          }
        }
      }

      // Sort by priority: overdue first, then by date
      overdue.sort((a, b) {
        final daysA = now.difference(a.claimDate).inDays;
        final daysB = now.difference(b.claimDate).inDays;
        return daysB.compareTo(daysA); // Most overdue first
      });

      outstanding.sort((a, b) {
        final daysA = now.difference(a.claimDate).inDays;
        final daysB = now.difference(b.claimDate).inDays;
        return daysB.compareTo(daysA); // Oldest first
      });

      readyDeliveries.sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));

      if (mounted) {
        setState(() {
          _readyDeliveries = readyDeliveries;
          _outstandingClaims = outstanding;
          _overdueClaims = overdue;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading claim alerts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _totalAlerts => 
      _readyDeliveries.length + _outstandingClaims.length + _overdueClaims.length;

  double get _totalOutstandingBalance =>
      _outstandingClaims.fold(0.0, (sum, claim) => sum + claim.balanceAmount);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_totalAlerts == 0) {
      return const SizedBox.shrink(); // Hide if no alerts
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _overdueClaims.isNotEmpty 
              ? Colors.red.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _overdueClaims.isNotEmpty
                  ? Colors.red.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _overdueClaims.isNotEmpty
                        ? Colors.red.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: _overdueClaims.isNotEmpty
                        ? Colors.red
                        : AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alert Tuntutan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_totalOutstandingBalance > 0)
                        Text(
                          'Baki tertunggak: RM ${_totalOutstandingBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _overdueClaims.isNotEmpty
                        ? Colors.red
                        : AppColors.primary,
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
              ],
            ),
          ),

          const Divider(height: 1),

          // Overdue Claims (Priority 1)
          if (_overdueClaims.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Lewat Bayar (${_overdueClaims.length})',
              color: Colors.red,
            ),
            ..._overdueClaims.take(3).map((claim) => _buildClaimItem(claim, isOverdue: true)),
            if (_overdueClaims.length > 3)
              _buildViewAllButton(
                count: _overdueClaims.length - 3,
                label: '${_overdueClaims.length - 3} lagi lewat bayar',
              ),
          ],

          // Deliveries Ready for Claim (Priority 2)
          if (_readyDeliveries.isNotEmpty) ...[
            if (_overdueClaims.isNotEmpty) const Divider(height: 1),
            _buildSectionHeader(
              icon: Icons.inventory_2,
              title: 'Sedia untuk Tuntutan (${_readyDeliveries.length})',
              color: Colors.orange,
            ),
            ..._readyDeliveries.take(3).map((delivery) => _buildDeliveryItem(delivery)),
            if (_readyDeliveries.length > 3)
              _buildViewAllButton(
                count: _readyDeliveries.length - 3,
                label: '${_readyDeliveries.length - 3} delivery lagi',
                onTap: () => Navigator.of(context).pushNamed('/claims/create'),
              ),
          ],

          // Outstanding Claims (Priority 3)
          if (_outstandingClaims.isNotEmpty && _overdueClaims.length < _outstandingClaims.length) ...[
            if (_readyDeliveries.isNotEmpty || _overdueClaims.isNotEmpty) const Divider(height: 1),
            _buildSectionHeader(
              icon: Icons.pending_actions,
              title: 'Belum Selesai (${_outstandingClaims.length})',
              color: Colors.blue,
            ),
            ..._outstandingClaims
                .where((c) => !_overdueClaims.contains(c))
                .take(3)
                .map((claim) => _buildClaimItem(claim)),
            if (_outstandingClaims.length > _overdueClaims.length + 3)
              _buildViewAllButton(
                count: _outstandingClaims.length - _overdueClaims.length - 3,
                label: '${_outstandingClaims.length - _overdueClaims.length - 3} tuntutan lagi',
              ),
          ],

          // Footer with action button
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/claims'),
                  icon: const Icon(Icons.list, size: 18),
                  label: const Text('Lihat Semua'),
                ),
                if (_readyDeliveries.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/claims/create'),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Buat Tuntutan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withOpacity(0.05),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimItem(ConsignmentClaim claim, {bool isOverdue = false}) {
    final daysOverdue = isOverdue
        ? DateTime.now().difference(claim.claimDate).inDays
        : 0;

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(
        '/claims/detail',
        arguments: claim.id,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claim.claimNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy', 'ms_MY').format(claim.claimDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (isOverdue && daysOverdue > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          '$daysOverdue hari lewat',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM ${claim.balanceAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOverdue ? Colors.red : AppColors.primary,
                  ),
                ),
                if (claim.paidAmount > 0)
                  Text(
                    'Dibayar: RM ${claim.paidAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryItem(Delivery delivery) {
    final daysSinceDelivery = DateTime.now().difference(delivery.deliveryDate).inDays;
    final totalValue = delivery.items.fold<double>(
      0.0,
      (sum, item) => sum + item.quantity * item.unitPrice,
    );

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(
        '/claims/create',
        arguments: {'vendorId': delivery.vendorId},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    delivery.vendorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy', 'ms_MY').format(delivery.deliveryDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$daysSinceDelivery hari lepas',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${delivery.items.length} produk',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM ${totalValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Text(
                  'Perlu check',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewAllButton({
    required int count,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => Navigator.of(context).pushNamed('/claims'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
