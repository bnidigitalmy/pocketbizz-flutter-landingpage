import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../subscription/widgets/subscription_guard.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/repositories/consignment_payments_repository_supabase.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/consignment_claim.dart';
import '../../../data/models/consignment_payment.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import 'phone_input_dialog.dart';
// import 'claim_details_dialog.dart'; // Commented out - will create later if needed
import 'create_consignment_claim_page.dart';
import 'create_consignment_payment_page.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

/// Claims Page - Consignment System
/// User (Consignor) buat tuntutan bayaran dari Vendor (Consignee)
/// 
/// Flow:
/// 1. Vendor jual produk kepada customer
/// 2. Vendor update sales dan balance unsold/expired/rosak kepada user
/// 3. User buat tuntutan bayaran based on product sold only
/// 4. Vendor buat payment kepada user dengan jumlah selepas tolak komisyen
/// 
/// Payment Formula: (Sold Products Value) - (Commission Rate %)
/// Note: Unsold/expired/rosak products tidak termasuk dalam payment
class ClaimsPage extends StatefulWidget {
  const ClaimsPage({super.key});

  @override
  State<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends State<ClaimsPage> {
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _paymentsRepo = ConsignmentPaymentsRepositorySupabase();
  final _deliveriesRepo = DeliveriesRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();

  List<ConsignmentClaim> _claims = [];
  List<ConsignmentPayment> _payments = [];
  List<Delivery> _deliveries = [];
  List<Vendor> _vendors = [];
  final Map<String, GlobalKey> _claimKeys = {};
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  // Filter states
  String _filterVendor = 'all';
  String _filterPaymentStatus = 'all';
  String _statusTab = 'all'; // all | outstanding | settled
  bool _showFilters = false;

  // Dialog states
  bool _phoneDialogOpen = false;
  bool _claimDetailsDialogOpen = false;
  String? _selectedVendorId;
  String? _phoneInput = '';
  VoidCallback? _pendingWhatsAppAction;
  String? _highlightClaimId;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _claims.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.claims,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.claims : TooltipContent.claimsEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setHighlight(String claimId) {
    setState(() => _highlightClaimId = claimId);
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _highlightClaimId == claimId) {
        setState(() => _highlightClaimId = null);
      }
    });
  }

  void _scrollToClaim(String claimId) {
    final key = _claimKeys[claimId];
    if (key == null) return;
    Future.delayed(const Duration(milliseconds: 80), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadClaims(reset: true),
        _loadVendors(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadClaims({bool reset = false}) async {
    if (reset) {
      _currentOffset = 0;
      _claims = [];
      _claimKeys.clear();
    }

    setState(() => _isLoadingMore = true);
    try {
      final claims = await _claimsRepo.getAll(limit: 100);
      final payments = await _paymentsRepo.getAll(limit: 100);

      if (mounted) {
        setState(() {
          _claims = claims;
          _payments = payments;
          _hasMore = false; // For now, load all claims at once
          _isLoadingMore = false;
        });
        if (_highlightClaimId != null) {
          Future.delayed(const Duration(milliseconds: 120), () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToClaim(_highlightClaimId!);
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading claims: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadDeliveries() async {
    try {
      // Optimized: Only load recent deliveries (last 100)
      final result = await _deliveriesRepo.getAllDeliveries(limit: 100, offset: 0);
      if (mounted) {
        setState(() => _deliveries = result['data'] as List<Delivery>);
      }
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
    }
  }

  Future<void> _loadVendors() async {
    try {
      final vendors = await _vendorsRepo.getAllVendors(activeOnly: false);
      if (mounted) {
        setState(() => _vendors = vendors);
      }
    } catch (e) {
      debugPrint('Error loading vendors: $e');
    }
  }

  Future<void> _handleUpdatePaymentStatus(String deliveryId, String paymentStatus) async {
    try {
      await _deliveriesRepo.updateDeliveryPaymentStatus(deliveryId, paymentStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Status bayaran telah dikemaskini'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadClaims(reset: true);
        await _loadDeliveries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Removed - no longer needed with new consignment system

  String? _getVendorPhone(String vendorId) {
    final vendor = _vendors.firstWhere(
      (v) => v.id == vendorId,
      orElse: () => Vendor(
        id: '',
        businessOwnerId: '',
        name: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return vendor.phone;
  }

  void _handleWhatsAppWithPhone(String vendorId, String vendorName, Function(String) action) {
    final phone = _getVendorPhone(vendorId);
    
    if (phone == null || phone.isEmpty) {
      setState(() {
        _pendingWhatsAppAction = () {
          if (_phoneInput != null && _phoneInput!.trim().isNotEmpty) {
            action(_phoneInput!);
            setState(() {
              _phoneDialogOpen = false;
              _phoneInput = '';
              _pendingWhatsAppAction = null;
            });
          }
        };
        _phoneDialogOpen = true;
      });
    } else {
      action(phone);
    }
  }

  Future<void> _shareClaimViaWhatsApp(ConsignmentClaim claim) async {
    final vendor = _vendors.firstWhere(
      (v) => v.id == claim.vendorId,
      orElse: () => Vendor(
        id: '',
        businessOwnerId: '',
        name: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    _handleWhatsAppWithPhone(claim.vendorId, vendor.name, (phone) async {
      final balanceAmount = claim.netAmount - claim.paidAmount;
      final message = '*PocketBizz - Invois Tuntutan*\n\n' +
          'No. Tuntutan: *${claim.claimNumber}*\n' +
          'Vendor: *${vendor.name}*\n' +
          'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(claim.claimDate)}\n' +
          'Jumlah Kasar: RM ${claim.grossAmount.toStringAsFixed(2)}\n' +
          'Komisyen (${claim.commissionRate}%): RM ${claim.commissionAmount.toStringAsFixed(2)}\n' +
          'Jumlah Bersih: RM ${claim.netAmount.toStringAsFixed(2)}\n' +
          'Dibayar: RM ${claim.paidAmount.toStringAsFixed(2)}\n' +
          'Baki: RM ${balanceAmount.toStringAsFixed(2)}\n\n' +
          'Status: ${claim.status == 'paid' ? '✅ Selesai' : claim.paidAmount > 0 ? '⏳ Separa Bayar' : '⏰ Belum Bayar'}\n\n' +
          'Sila lihat penyata lengkap untuk butiran.';

      final whatsappUrl = 'https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}?text=${Uri.encodeComponent(message)}';
      
      try {
        await launchUrl(Uri.parse(whatsappUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ WhatsApp dibuka untuk ${vendor.name}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<void> _sendPaymentReminder(ConsignmentClaim claim) async {
    final vendor = _vendors.firstWhere(
      (v) => v.id == claim.vendorId,
      orElse: () => Vendor(
        id: '',
        businessOwnerId: '',
        name: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    _handleWhatsAppWithPhone(claim.vendorId, vendor.name, (phone) async {
      final balanceAmount = claim.netAmount - claim.paidAmount;
      final daysOverdue = DateTime.now().difference(claim.claimDate).inDays;
      final message = '*Peringatan Bayaran - PocketBizz*\n\n' +
          'Kepada: *${vendor.name}*\n\n' +
          'No. Tuntutan: ${claim.claimNumber}\n' +
          'Baki tertunggak: RM ${balanceAmount.toStringAsFixed(2)}\n' +
          'Hari lewat: ${daysOverdue} hari\n\n' +
          'Sila selesaikan pembayaran segera. Terima kasih!';

      final whatsappUrl = 'https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}?text=${Uri.encodeComponent(message)}';
      
      try {
        await launchUrl(Uri.parse(whatsappUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Peringatan bayaran dihantar kepada ${vendor.name}'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Future<void> _generateClaimStatement(String vendorId, String vendorName) async {
    // TODO: Implement PDF generation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF generation untuk $vendorName akan ditambah kemudian'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _generateThermalClaimStatement(String vendorId, String vendorName) async {
    // TODO: Implement thermal PDF generation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('PDF thermal generation untuk $vendorName akan ditambah kemudian'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Color _statusColor(ClaimStatus status) {
    switch (status) {
      case ClaimStatus.submitted:
        return Colors.blue;
      case ClaimStatus.approved:
        return Colors.teal;
      case ClaimStatus.settled:
        return Colors.green;
      case ClaimStatus.rejected:
        return Colors.red;
      case ClaimStatus.draft:
      default:
        return Colors.grey;
    }
  }

  Future<void> _exportCSV() async {
    // TODO: Implement CSV export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export CSV functionality akan ditambah kemudian'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  List<ConsignmentClaim> get _filteredClaims {
    return _claims.where((claim) {
      // Filter by vendor
      if (_filterVendor != 'all' && claim.vendorId != _filterVendor) {
        return false;
      }

      // Filter by tab (outstanding/settled)
      if (_statusTab == 'outstanding' && claim.balanceAmount <= 0) {
        return false;
      }
      if (_statusTab == 'settled' && claim.balanceAmount > 0) {
        return false;
      }

      // Filter by payment status
      if (_filterPaymentStatus != 'all') {
        if (_filterPaymentStatus == 'pending') {
          // Pending = balance > 0 and status approved/submitted
          if (claim.balanceAmount <= 0 || 
              (claim.status != ClaimStatus.approved && claim.status != ClaimStatus.submitted)) {
            return false;
          }
        }
        if (_filterPaymentStatus == 'partial') {
          // Partial = paid > 0 but balance > 0
          if (claim.paidAmount <= 0 || claim.balanceAmount <= 0) return false;
        }
        if (_filterPaymentStatus == 'settled') {
          // Settled = balance = 0 or status = settled
          if (claim.balanceAmount > 0 && claim.status != ClaimStatus.settled) return false;
        }
      }

      return true;
    }).toList();
  }

  // Calculate summary totals
  Map<String, double> get _summaryTotals {
    final filtered = _filteredClaims;
    double totalGross = 0.0;
    double totalCommission = 0.0;
    double totalNet = 0.0;
    double totalPaid = 0.0;
    double totalBalance = 0.0;

    for (var claim in filtered) {
      totalGross += claim.grossAmount;
      totalCommission += claim.commissionAmount;
      totalNet += claim.netAmount;
      totalPaid += claim.paidAmount;
      totalBalance += claim.balanceAmount;
    }

    return {
      'gross': totalGross,
      'commission': totalCommission,
      'net': totalNet,
      'paid': totalPaid,
      'balance': totalBalance,
    };
  }

  Color _getOverdueBadgeColor(int days) {
    if (days > 30) return Colors.red;
    if (days > 14) return Colors.orange;
    if (days > 7) return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    // Show dialogs when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_phoneDialogOpen) {
        showDialog(
          context: context,
          builder: (context) => PhoneInputDialog(
            phoneInput: _phoneInput ?? '',
            onPhoneChanged: (phone) {
              setState(() => _phoneInput = phone);
            },
            onConfirm: () {
              _pendingWhatsAppAction?.call();
            },
            onCancel: () {
              setState(() {
                _phoneDialogOpen = false;
                _phoneInput = '';
                _pendingWhatsAppAction = null;
              });
            },
          ),
        ).then((_) {
          if (mounted) {
            setState(() => _phoneDialogOpen = false);
          }
        });
      }
      // Claim details dialog removed - using navigation instead
    });

    return SubscriptionGuard(
      featureName: 'Sistem Konsinyemen',
      allowTrial: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tuntutan & Bayaran'),
              Text(
                'Track payment invoice vendor & update expired/rosak',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        actions: [
            IconButton(
              icon: const Icon(Icons.payment),
              tooltip: 'Rekod Bayaran',
              onPressed: () {
                Navigator.pushNamed(context, '/payments/record').then((_) {
                  _loadClaims(reset: true);
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Cipta Tuntutan',
            onPressed: () {
              Navigator.pushNamed(context, '/claims/create').then((_) {
                _loadClaims(reset: true);
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat data...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadClaims(reset: true),
              child: _buildContent(),
            ),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Header with export button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportCSV,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
          ),
        ),

        // Summary Card
        if (_claims.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildSummaryCard(),
          ),

        // Status tabs
        if (_claims.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _statusChip('all', 'Semua'),
                  const SizedBox(width: 8),
                  _statusChip('outstanding', 'Outstanding'),
                  const SizedBox(width: 8),
                  _statusChip('settled', 'Selesai'),
                ],
              ),
            ),
          ),

        // Filters
        if (_claims.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildFilters(),
          ),

        // Claims list or empty state
        if (_claims.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else if (_filteredClaims.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildNoResultsState(),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _filteredClaims.length) {
                  return _buildClaimCard(_filteredClaims[index]);
                } else if (index == _filteredClaims.length && _hasMore) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _isLoadingMore
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: () => _loadClaims(),
                              child: const Text('Muatkan Lagi'),
                            ),
                    ),
                  );
                }
                return null;
              },
              childCount: _filteredClaims.length + (_hasMore ? 1 : 0),
            ),
          ),

      ],
    );
  }

  Widget _buildSummaryCard() {
    final summary = _summaryTotals;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Ringkasan Tuntutan (${_filteredClaims.length} tuntutan)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Jumlah Kasar',
                    summary['gross']!,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryItem(
                    'Komisyen',
                    summary['commission']!,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Jumlah Bersih',
                    summary['net']!,
                    Colors.green,
                    isBold: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryItem(
                    'Telah Dibayar',
                    summary['paid']!,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: summary['balance']! > 0 
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: summary['balance']! > 0 
                      ? Colors.orange
                      : Colors.green,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Baki Tertunggak:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: summary['balance']! > 0 
                          ? Colors.orange[900]
                          : Colors.green[900],
                    ),
                  ),
                  Text(
                    'RM ${summary['balance']!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: summary['balance']! > 0 
                          ? Colors.orange[900]
                          : Colors.green[900],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Color.fromRGBO(
                (color.red * 0.7).round(),
                (color.green * 0.7).round(),
                (color.blue * 0.7).round(),
                1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.filter_list, size: 20),
            const SizedBox(width: 8),
            const Text('Tapis'),
            if (_filterVendor != 'all' || _filterPaymentStatus != 'all') ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Aktif',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        initiallyExpanded: _showFilters,
        onExpansionChanged: (expanded) {
          setState(() => _showFilters = expanded);
        },
        trailing: (_filterVendor != 'all' || _filterPaymentStatus != 'all')
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  setState(() {
                    _filterVendor = 'all';
                    _filterPaymentStatus = 'all';
                  });
                },
                tooltip: 'Reset',
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _filterVendor == 'all' ? null : _filterVendor,
                  decoration: const InputDecoration(
                    labelText: 'Vendor',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Semua Vendor')),
                    ..._vendors.map((vendor) => DropdownMenuItem(
                          value: vendor.id,
                          child: Text(vendor.name),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _filterVendor = value ?? 'all');
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _filterPaymentStatus == 'all' ? null : _filterPaymentStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status Bayaran',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Belum Bayar')),
                    DropdownMenuItem(value: 'partial', child: Text('Bayar Separa')),
                    DropdownMenuItem(value: 'settled', child: Text('Selesai')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterPaymentStatus = value ?? 'all');
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '${_filteredClaims.length} daripada ${_claims.length} vendor',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.payment,
                  size: 32,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tiada Tuntutan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tiada rekod tuntutan vendor',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.filter_list,
                  size: 32,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tiada Tuntutan Ditemui',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuba reset penapis untuk melihat semua',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _filterVendor = 'all';
                    _filterPaymentStatus = 'all';
                  });
                },
                child: const Text('Reset Penapis'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimCard(ConsignmentClaim claim) {
    final vendor = _vendors.firstWhere(
      (v) => v.id == claim.vendorId,
      orElse: () => Vendor(
        id: '',
        businessOwnerId: '',
        name: 'Unknown',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    final balanceAmount = claim.netAmount - claim.paidAmount;
    final hasOutstanding = balanceAmount > 0;
    final daysOverdue = hasOutstanding ? DateTime.now().difference(claim.claimDate).inDays : 0;
    final isHighlighted = _highlightClaimId == claim.id;
    final cardKey = _claimKeys.putIfAbsent(claim.id, () => GlobalKey());

    return Card(
      key: cardKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isHighlighted ? AppColors.primary.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(
        side: isHighlighted
            ? BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1.2)
            : BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              claim.claimNumber,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(claim.status).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              claim.status.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(claim.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendor.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasOutstanding && daysOverdue > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: _getOverdueBadgeColor(daysOverdue)),
                              const SizedBox(width: 4),
                              Text(
                                '$daysOverdue hari tertunggak',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getOverdueBadgeColor(daysOverdue),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.receipt_long, size: 20, color: Colors.grey[600]),
              ],
            ),
            const SizedBox(height: 12),
            // Amounts
            Text(
              'RM ${claim.netAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _amountTile(
                    label: 'Dibayar',
                    value: claim.paidAmount,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _amountTile(
                    label: 'Baki',
                    value: balanceAmount,
                    color: balanceAmount > 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions (simplified)
            Column(
              children: [
                if (hasOutstanding) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Pastikan claim kekal kelihatan: reset tab & filter sebelum reload
                        setState(() {
                          _statusTab = 'all';
                          _filterVendor = 'all';
                          _filterPaymentStatus = 'all';
                          _showFilters = false;
                        });
                        final result = await Navigator.pushNamed(
                          context,
                          '/payments/record',
                          arguments: {
                            'vendorId': claim.vendorId,
                            'claimId': claim.id,
                          },
                        );
                        if (result == true) {
                          await _loadClaims(reset: true);
                          _setHighlight(claim.id);
                          _scrollToClaim(claim.id);
                        }
                      },
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Rekod Bayaran'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to claim details page
                      Navigator.pushNamed(
                        context,
                        '/claims/detail',
                        arguments: claim.id,
                      ).then((_) {
                        _loadClaims(reset: true);
                      });
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Lihat Detail Produk'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountTile({required String label, required double value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          const SizedBox(height: 4),
          Text(
            'RM ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String key, String label) {
    final bool selected = _statusTab == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusTab = key;
          // Keep payment filter unchanged; tab handles outstanding/settled
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildDeliveriesList() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Senarai Penghantaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (_deliveries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Tiada penghantaran'),
              ),
            )
          else
            ..._deliveries.map((delivery) => _buildDeliveryCard(delivery)),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(Delivery delivery) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.vendorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMMM yyyy', 'ms_MY').format(delivery.deliveryDate),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${delivery.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    children: [
                      _buildPaymentStatusBadge(delivery.paymentStatus ?? 'pending'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: delivery.paymentStatus ?? 'pending',
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Belum Bayar', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'partial', child: Text('Bayar Separa', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'settled', child: Text('Selesai', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _handleUpdatePaymentStatus(delivery.id, value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (delivery.items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...delivery.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.productName,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                        ),
                        Text(
                          '${item.quantity.toStringAsFixed(1)}x RM ${item.unitPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final phone = _getVendorPhone(delivery.vendorId);
                  if (phone != null && phone.isNotEmpty) {
                    final message = '*ManisBizz - Penghantaran*\n\n' +
                        'Vendor: *${delivery.vendorName}*\n' +
                        'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(delivery.deliveryDate)}\n' +
                        'Jumlah: RM ${delivery.totalAmount.toStringAsFixed(2)}\n\n' +
                        '*Senarai Produk:*\n' +
                        delivery.items.map((item) => 
                          '• ${item.productName}: ${item.quantity.toStringAsFixed(1)}x @ RM ${item.unitPrice.toStringAsFixed(2)} = RM ${item.totalPrice.toStringAsFixed(2)}'
                        ).join('\n');

                    final whatsappUrl = 'https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}?text=${Uri.encodeComponent(message)}';
                    await launchUrl(Uri.parse(whatsappUrl));
                  } else {
                    _handleWhatsAppWithPhone(delivery.vendorId, delivery.vendorName, (phone) async {
                      final message = '*ManisBizz - Penghantaran*\n\n' +
                          'Vendor: *${delivery.vendorName}*\n' +
                          'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(delivery.deliveryDate)}\n' +
                          'Jumlah: RM ${delivery.totalAmount.toStringAsFixed(2)}';

                      final whatsappUrl = 'https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}?text=${Uri.encodeComponent(message)}';
                      await launchUrl(Uri.parse(whatsappUrl));
                    });
                  }
                },
                icon: const Icon(Icons.message, size: 16, color: Colors.green),
                label: const Text('Hantar WhatsApp', style: TextStyle(color: Colors.green)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    IconData icon;
    Color color;
    String label;

    switch (status) {
      case 'settled':
        icon = Icons.check_circle;
        color = Colors.green;
        label = 'Selesai';
        break;
      case 'partial':
        icon = Icons.payment;
        color = Colors.blue;
        label = 'Bayar Separa';
        break;
      default:
        icon = Icons.pending;
        color = Colors.orange;
        label = 'Belum Bayar';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

