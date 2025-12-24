import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/product.dart';
import '../../../data/models/business_profile.dart';
import 'delivery_form_dialog.dart';
import 'edit_rejection_dialog.dart';
import 'payment_status_dialog.dart';
import 'invoice_dialog.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

/// Deliveries Page - Consignment System
/// Manage deliveries to Consignees (vendors)
/// 
/// User (Consignor) hantar produk ke Vendor (Consignee) untuk dijual
/// dengan sistem consignment
/// Optimized based on React code with all features
class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({super.key});

  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  final _deliveriesRepo = DeliveriesRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();
  final _productsRepo = ProductsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();

  List<Delivery> _deliveries = [];
  List<Vendor> _vendors = [];
  List<Product> _products = [];
  BusinessProfile? _businessProfile;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentOffset = 0;

  // Filter states
  String _filterVendor = 'all';
  String _filterStatus = 'all';
  String? _filterDateFrom;
  String? _filterDateTo;
  bool _showFilters = false;

  // Dialog states
  bool _addDialogOpen = false;
  bool _editRejectionDialogOpen = false;
  bool _paymentDialogOpen = false;
  bool _invoiceDialogOpen = false;
  Delivery? _selectedDelivery;
  Delivery? _createdDelivery;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _deliveries.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      TooltipKeys.deliveries,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.deliveries : TooltipContent.deliveriesEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadDeliveries(reset: true),
        _loadVendors(),
        _loadProducts(),
        _loadBusinessProfile(),
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

  Future<void> _loadBusinessProfile() async {
    try {
      final profile = await _businessProfileRepo.getBusinessProfile();
      if (mounted) {
        setState(() {
          _businessProfile = profile;
        });
      }
    } catch (e) {
      // Business profile is optional, continue without it
      debugPrint('Failed to load business profile: $e');
    }
  }

  Future<void> _loadDeliveries({bool reset = false}) async {
    if (reset) {
      _currentOffset = 0;
      _deliveries = [];
    }

    setState(() => _isLoadingMore = true);
    try {
      final result = await _deliveriesRepo.getAllDeliveries(
        limit: 20,
        offset: _currentOffset,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _deliveries = result['data'] as List<Delivery>;
          } else {
            _deliveries.addAll(result['data'] as List<Delivery>);
          }
          _hasMore = result['hasMore'] as bool;
          _currentOffset = _deliveries.length;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading deliveries: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Future<void> _loadProducts() async {
    try {
      final products = await _productsRepo.getAll(limit: 100);
      if (mounted) {
        setState(() => _products = products);
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _handleCreateDelivery(Delivery delivery) async {
    // Refresh deliveries
    await _loadDeliveries(reset: true);
    
    if (mounted) {
      setState(() {
        _createdDelivery = delivery;
        _invoiceDialogOpen = true;
      });
    }
  }

  Future<void> _handleUpdateStatus(String deliveryId, String status) async {
    try {
      await _deliveriesRepo.updateDeliveryStatus(deliveryId, status);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Status telah dikemaskini'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // If status is "claimed", open payment dialog
        if (status == 'claimed') {
          final delivery = _deliveries.firstWhere((d) => d.id == deliveryId);
          setState(() {
            _selectedDelivery = delivery;
            _paymentDialogOpen = true;
          });
        }
        
        await _loadDeliveries(reset: true);
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
        setState(() => _paymentDialogOpen = false);
        await _loadDeliveries(reset: true);
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

  Future<void> _duplicateYesterday() async {
    if (_deliveries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiada data semalam untuk disalin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    final yesterdayDelivery = _deliveries.where(
      (d) => DateFormat('yyyy-MM-dd').format(d.deliveryDate) == yesterdayStr,
    ).firstOrNull;

    if (yesterdayDelivery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiada penghantaran semalam untuk disalin'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _addDialogOpen = true);
      // Open dialog with yesterday's data
      // This will be handled in the dialog
    }
  }

  Future<void> _exportCSV() async {
    // For now, show a message - CSV export can be implemented later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export CSV functionality akan ditambah kemudian'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  List<Delivery> get _filteredDeliveries {
    return _deliveries.where((delivery) {
      // Filter by vendor
      if (_filterVendor != 'all' && delivery.vendorId != _filterVendor) {
        return false;
      }

      // Filter by status
      if (_filterStatus != 'all' && delivery.status != _filterStatus) {
        return false;
      }

      // Filter by date range
      final deliveryDateStr = DateFormat('yyyy-MM-dd').format(delivery.deliveryDate);
      if (_filterDateFrom != null && deliveryDateStr.compareTo(_filterDateFrom!) < 0) {
        return false;
      }
      if (_filterDateTo != null && deliveryDateStr.compareTo(_filterDateTo!) > 0) {
        return false;
      }

      return true;
    }).toList();
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'claimed':
        return 'Dituntut';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Dihantar';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'claimed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show dialogs when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_addDialogOpen) {
        showDialog(
          context: context,
          builder: (context) => DeliveryFormDialog(
            vendors: _vendors,
            products: _products,
            deliveriesRepo: _deliveriesRepo,
            onSuccess: _handleCreateDelivery,
            onCancel: () {
              if (mounted) {
                setState(() => _addDialogOpen = false);
              }
            },
          ),
        ).then((_) {
          if (mounted) {
            setState(() => _addDialogOpen = false);
          }
        });
      }
      if (_editRejectionDialogOpen && _selectedDelivery != null) {
        showDialog(
          context: context,
          builder: (context) => EditRejectionDialog(
            delivery: _selectedDelivery!,
            deliveriesRepo: _deliveriesRepo,
            onSuccess: () {
              if (mounted) {
                setState(() => _editRejectionDialogOpen = false);
                _loadDeliveries(reset: true);
              }
            },
            onCancel: () {
              if (mounted) {
                setState(() => _editRejectionDialogOpen = false);
              }
            },
          ),
        ).then((_) {
          if (mounted) {
            setState(() => _editRejectionDialogOpen = false);
          }
        });
      }
      if (_paymentDialogOpen && _selectedDelivery != null) {
        showDialog(
          context: context,
          builder: (context) => PaymentStatusDialog(
            delivery: _selectedDelivery!,
            onSave: (paymentStatus) {
              _handleUpdatePaymentStatus(_selectedDelivery!.id, paymentStatus);
            },
            onCancel: () {
              if (mounted) {
                setState(() => _paymentDialogOpen = false);
              }
            },
          ),
        ).then((_) {
          if (mounted) {
            setState(() => _paymentDialogOpen = false);
          }
        });
      }
      if (_invoiceDialogOpen && _createdDelivery != null) {
        showDialog(
          context: context,
          builder: (context) => InvoiceDialog(
            delivery: _createdDelivery!,
            onClose: () {
              if (mounted) {
                setState(() {
                  _invoiceDialogOpen = false;
                  _createdDelivery = null;
                });
              }
            },
          ),
        ).then((_) {
          if (mounted) {
            setState(() {
              _invoiceDialogOpen = false;
              _createdDelivery = null;
            });
          }
        });
      }
    });

    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (canPop) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Penghantaran'),
            Text(
              'Urus penghantaran ke vendor',
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
              onRefresh: () => _loadDeliveries(reset: true),
              child: _buildContent(),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() => _addDialogOpen = true);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Penghantaran'),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Header with actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportCSV,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _duplicateYesterday,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Salin Semalam'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filters
        if (_deliveries.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildFilters(),
          ),

        // Deliveries list or empty state
        if (_deliveries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else if (_filteredDeliveries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildNoResultsState(),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < _filteredDeliveries.length) {
                  return _buildDeliveryCard(_filteredDeliveries[index]);
                } else if (index == _filteredDeliveries.length && _hasMore) {
                  // Load more button
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _isLoadingMore
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: () => _loadDeliveries(),
                              child: const Text('Muatkan Lagi'),
                            ),
                    ),
                  );
                }
                return null;
              },
              childCount: _filteredDeliveries.length + (_hasMore ? 1 : 0),
            ),
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
            if (_filterVendor != 'all' ||
                _filterStatus != 'all' ||
                _filterDateFrom != null ||
                _filterDateTo != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Aktif',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        initiallyExpanded: _showFilters,
        onExpansionChanged: (expanded) {
          setState(() => _showFilters = expanded);
        },
        trailing: (_filterVendor != 'all' ||
                _filterStatus != 'all' ||
                _filterDateFrom != null ||
                _filterDateTo != null)
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  setState(() {
                    _filterVendor = 'all';
                    _filterStatus = 'all';
                    _filterDateFrom = null;
                    _filterDateTo = null;
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
                // Vendor filter
                DropdownButtonFormField<String>(
                  value: _filterVendor,
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
                // Status filter
                DropdownButtonFormField<String>(
                  value: _filterStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                    DropdownMenuItem(value: 'delivered', child: Text('Dihantar')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'claimed', child: Text('Dituntut')),
                    DropdownMenuItem(value: 'rejected', child: Text('Ditolak')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterStatus = value ?? 'all');
                  },
                ),
                const SizedBox(height: 16),
                // Date range filters
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Dari Tarikh',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        initialValue: _filterDateFrom,
                        onChanged: (value) {
                          setState(() => _filterDateFrom = value.isEmpty ? null : value);
                        },
                        keyboardType: TextInputType.datetime,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Hingga Tarikh',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        initialValue: _filterDateTo,
                        onChanged: (value) {
                          setState(() => _filterDateTo = value.isEmpty ? null : value);
                        },
                        keyboardType: TextInputType.datetime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_filteredDeliveries.length} daripada ${_deliveries.length} penghantaran',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
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
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tiada Penghantaran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rekod penghantaran pertama anda',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
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
                'Tiada Penghantaran Ditemui',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuba reset penapis untuk melihat semua',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _filterVendor = 'all';
                    _filterStatus = 'all';
                    _filterDateFrom = null;
                    _filterDateTo = null;
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

  Widget _buildDeliveryCard(Delivery delivery) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
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
                    DateFormat('dd MMM yyyy', 'ms_MY').format(DateTimeHelper.toLocalTime(delivery.deliveryDate)),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM ${delivery.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(delivery.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(delivery.status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusLabel(delivery.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(delivery.status),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: delivery.items.isNotEmpty
            ? Text('${delivery.items.length} produk')
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Items list
                if (delivery.items.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  ...delivery.items.map((item) => _buildItemRow(item)),
                  const SizedBox(height: 16),
                ],
                // Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status dropdown (full width)
                    DropdownButtonFormField<String>(
                      value: delivery.status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'delivered',
                          child: Text('Dihantar'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending'),
                        ),
                        DropdownMenuItem(
                          value: 'claimed',
                          child: Text('Dituntut'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Ditolak'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _handleUpdateStatus(delivery.id, value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Action buttons (wrap nicely on small screens)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedDelivery = delivery;
                              _editRejectionDialogOpen = true;
                            });
                          },
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit Tolakan'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _shareViaWhatsApp(delivery),
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('WhatsApp'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _createdDelivery = delivery;
                              _invoiceDialogOpen = true;
                            });
                          },
                          icon: const Icon(Icons.receipt, size: 16),
                          label: const Text('Invois'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(DeliveryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity.toStringAsFixed(1)}x @ RM ${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (item.rejectedQty > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cancel, size: 12, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          'Ditolak: ${item.rejectedQty.toStringAsFixed(1)} unit',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.rejectionReason!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          Text(
            'RM ${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareViaWhatsApp(Delivery delivery) async {
    // Ensure business profile is loaded
    if (_businessProfile == null) {
      await _loadBusinessProfile();
    }

    final statusLabels = {
      'delivered': 'Dihantar',
      'pending': 'Pending',
      'claimed': 'Dibayar',
      'rejected': 'Ditolak',
    };

    // Use business profile name or default to PocketBizz
    final businessName = _businessProfile?.businessName ?? 'PocketBizz';
    
    var message = '*$businessName - Penghantaran*\n\n';
    
    // Add business info if available
    if (_businessProfile != null) {
      if (_businessProfile!.address != null && _businessProfile!.address!.isNotEmpty) {
        message += 'Alamat: ${_businessProfile!.address}\n';
      }
      if (_businessProfile!.phone != null && _businessProfile!.phone!.isNotEmpty) {
        message += 'Tel: ${_businessProfile!.phone}\n';
      }
      message += '\n';
    }
    
    message += 'Vendor: *${delivery.vendorName}*\n' +
        'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTimeHelper.toLocalTime(delivery.deliveryDate))}\n' +
        'Status: ${statusLabels[delivery.status] ?? delivery.status}\n' +
        'Jumlah: RM ${delivery.totalAmount.toStringAsFixed(2)}\n\n' +
        '*Senarai Produk:*\n';

    for (var item in delivery.items) {
      message += '• ${item.productName}: ${item.quantity.toStringAsFixed(1)}x @ RM ${item.unitPrice.toStringAsFixed(2)} = RM ${item.totalPrice.toStringAsFixed(2)}\n';
      if (item.rejectedQty > 0) {
        message += '  Ditolak: ${item.rejectedQty.toStringAsFixed(1)} unit';
        if (item.rejectionReason != null && item.rejectionReason!.isNotEmpty) {
          message += ' (${item.rejectionReason})';
        }
        message += '\n';
      }
    }

    final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(message)}';
    
    try {
      await launchUrl(Uri.parse(whatsappUrl));
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
}

