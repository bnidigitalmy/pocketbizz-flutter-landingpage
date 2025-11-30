import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/claims_repository_supabase.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/claim.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import 'phone_input_dialog.dart';
import 'claim_details_dialog.dart';

/// Claims Page - Vendor Payment Tracking
/// Optimized based on React code with all features
class ClaimsPage extends StatefulWidget {
  const ClaimsPage({super.key});

  @override
  State<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends State<ClaimsPage> {
  final _claimsRepo = ClaimsRepositorySupabase();
  final _deliveriesRepo = DeliveriesRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();

  List<Claim> _claims = [];
  List<Delivery> _deliveries = [];
  List<Vendor> _vendors = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  // Filter states
  String _filterVendor = 'all';
  String _filterPaymentStatus = 'all';
  bool _showFilters = false;

  // Dialog states
  bool _phoneDialogOpen = false;
  bool _claimDetailsDialogOpen = false;
  String? _selectedVendorId;
  String? _phoneInput = '';
  VoidCallback? _pendingWhatsAppAction;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadClaims(reset: true),
        _loadDeliveries(),
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
    }

    setState(() => _isLoadingMore = true);
    try {
      final result = await _claimsRepo.getAllClaims(
        limit: 20,
        offset: _currentOffset,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _claims = result['data'] as List<Claim>;
          } else {
            _claims.addAll(result['data'] as List<Claim>);
          }
          _hasMore = result['hasMore'] as bool;
          _currentOffset = _claims.length;
          _isLoadingMore = false;
        });
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
      final result = await _deliveriesRepo.getAllDeliveries(limit: 1000, offset: 0);
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

  Future<void> _handleUpdateRejection({
    required String itemId,
    required double rejectedQty,
    required String? rejectionReason,
  }) async {
    try {
      await _claimsRepo.updateItemRejection(
        itemId: itemId,
        rejectedQty: rejectedQty,
        rejectionReason: rejectionReason,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Expired/rosak dikemaskini. Invoice auto-adjust.'),
            backgroundColor: AppColors.success,
          ),
        );
        // Refresh claim details if dialog is open
        if (_selectedVendorId != null) {
          setState(() {
            // Force refresh by closing and reopening
            _claimDetailsDialogOpen = false;
          });
          await Future.delayed(const Duration(milliseconds: 100));
          setState(() {
            _claimDetailsDialogOpen = true;
          });
        }
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

  Future<void> _shareClaimViaWhatsApp(Claim claim) async {
    _handleWhatsAppWithPhone(claim.vendorId, claim.vendorName, (phone) async {
      final message = '*ManisBizz - Invois Tuntutan*\n\n' +
          'Vendor: *${claim.vendorName}*\n' +
          'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.now())}\n' +
          'Jumlah: RM ${claim.totalAmount.toStringAsFixed(2)}\n' +
          'Belum Bayar: RM ${claim.pendingAmount.toStringAsFixed(2)}\n' +
          'Selesai: RM ${claim.settledAmount.toStringAsFixed(2)}\n\n' +
          'Sila lihat penyata lengkap untuk butiran.';

      final whatsappUrl = 'https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}?text=${Uri.encodeComponent(message)}';
      
      try {
        await launchUrl(Uri.parse(whatsappUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ WhatsApp dibuka untuk ${claim.vendorName}'),
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

  Future<void> _sendPaymentReminder(Claim claim) async {
    _handleWhatsAppWithPhone(claim.vendorId, claim.vendorName, (phone) async {
      final outstandingAmount = claim.pendingAmount + claim.partialAmount;
      final message = '*Peringatan Bayaran - ManisBizz*\n\n' +
          'Kepada: *${claim.vendorName}*\n\n' +
          'Baki tertunggak: RM ${outstandingAmount.toStringAsFixed(2)}\n' +
          'Hari lewat: ${claim.daysOverdue} hari\n\n' +
          'Sila selesaikan pembayaran segera. Terima kasih!';

      final whatsappUrl = 'https://wa.me/${phone.replaceAll(RegExp(r'[^\d]'), '')}?text=${Uri.encodeComponent(message)}';
      
      try {
        await launchUrl(Uri.parse(whatsappUrl));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Peringatan bayaran dihantar kepada ${claim.vendorName}'),
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

  Future<void> _exportCSV() async {
    // TODO: Implement CSV export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export CSV functionality akan ditambah kemudian'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  List<Claim> get _filteredClaims {
    return _claims.where((claim) {
      // Filter by vendor
      if (_filterVendor != 'all' && claim.vendorId != _filterVendor) {
        return false;
      }

      // Filter by payment status
      if (_filterPaymentStatus != 'all') {
        final vendorDeliveries = _deliveries.where((d) => d.vendorId == claim.vendorId).toList();
        final hasMatchingStatus = vendorDeliveries.any((d) => d.paymentStatus == _filterPaymentStatus);
        if (!hasMatchingStatus) {
          return false;
        }
      }

      return true;
    }).toList();
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
      if (_claimDetailsDialogOpen && _selectedVendorId != null) {
        showDialog(
          context: context,
          builder: (context) => ClaimDetailsDialog(
            vendorId: _selectedVendorId!,
            claimsRepo: _claimsRepo,
            deliveriesRepo: _deliveriesRepo,
            vendors: _vendors,
            onUpdateRejection: _handleUpdateRejection,
            onUpdatePaymentStatus: _handleUpdatePaymentStatus,
            onClose: () {
              if (mounted) {
                setState(() {
                  _claimDetailsDialogOpen = false;
                  _selectedVendorId = null;
                });
                _loadClaims(reset: true);
              }
            },
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _claimDetailsDialogOpen = false;
              _selectedVendorId = null;
            });
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bayaran Vendor'),
            Text(
              'Track payment invoice vendor & update expired/rosak',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
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

        // Deliveries list
        SliverToBoxAdapter(
          child: _buildDeliveriesList(),
        ),
      ],
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
                  value: _filterVendor,
                  decoration: const InputDecoration(
                    labelText: 'Vendor',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Semua Vendor')),
                    ..._claims.map((claim) => DropdownMenuItem(
                          value: claim.vendorId,
                          child: Text(claim.vendorName),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _filterVendor = value ?? 'all');
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _filterPaymentStatus,
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

  Widget _buildClaimCard(Claim claim) {
    final hasOutstanding = claim.pendingAmount > 0 || claim.partialAmount > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          claim.vendorName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (hasOutstanding && claim.daysOverdue > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getOverdueBadgeColor(claim.daysOverdue).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getOverdueBadgeColor(claim.daysOverdue).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${claim.daysOverdue} hari',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getOverdueBadgeColor(claim.daysOverdue),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.attach_money, size: 20, color: Colors.grey[600]),
              ],
            ),
            const SizedBox(height: 12),
            // Total amount
            Text(
              'RM ${claim.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '${claim.totalDeliveries} penghantaran',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            // Amount breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Belum Bayar:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'RM ${claim.pendingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (claim.partialAmount > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Separa:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        'RM ${claim.partialAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Selesai:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      'RM ${claim.settledAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedVendorId = claim.vendorId;
                        _claimDetailsDialogOpen = true;
                      });
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Lihat Detail Produk'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _generateClaimStatement(claim.vendorId, claim.vendorName),
                        icon: const Icon(Icons.description, size: 16),
                        label: const Text('Penyata'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _generateThermalClaimStatement(claim.vendorId, claim.vendorName),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Thermal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareClaimViaWhatsApp(claim),
                        icon: const Icon(Icons.message, size: 16, color: Colors.green),
                        label: const Text('WhatsApp', style: TextStyle(color: Colors.green)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                    ),
                    if (hasOutstanding) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _sendPaymentReminder(claim),
                          icon: const Icon(Icons.notifications, size: 16),
                          label: const Text('Ingatkan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: claim.daysOverdue > 14 ? Colors.red : AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
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
                Column(
                  children: [
                    _buildPaymentStatusBadge(delivery.paymentStatus ?? 'pending'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: delivery.paymentStatus ?? 'pending',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Belum Bayar')),
                        DropdownMenuItem(value: 'partial', child: Text('Bayar Separa')),
                        DropdownMenuItem(value: 'settled', child: Text('Selesai')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _handleUpdatePaymentStatus(delivery.id, value);
                        }
                      },
                    ),
                  ],
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

