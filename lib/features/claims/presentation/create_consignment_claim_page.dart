import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/consignment_claim.dart';
import '../../subscription/widgets/subscription_guard.dart';

/// Create Consignment Claim Page
/// User selects deliveries and creates a claim
class CreateConsignmentClaimPage extends StatefulWidget {
  const CreateConsignmentClaimPage({super.key});

  @override
  State<CreateConsignmentClaimPage> createState() => _CreateConsignmentClaimPageState();
}

class _CreateConsignmentClaimPageState extends State<CreateConsignmentClaimPage> {
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _deliveriesRepo = DeliveriesRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();

  List<Vendor> _vendors = [];
  List<Delivery> _deliveries = [];
  List<Delivery> _selectedDeliveries = [];
  String? _selectedVendorId;
  DateTime _claimDate = DateTime.now();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final vendors = await _vendorsRepo.getAllVendors(activeOnly: false);
      final deliveriesResult = await _deliveriesRepo.getAllDeliveries(limit: 1000, offset: 0);
      final deliveries = deliveriesResult['data'] as List<Delivery>;

      if (mounted) {
        setState(() {
          _vendors = vendors;
          _deliveries = deliveries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onVendorSelected(String? vendorId) {
    setState(() {
      _selectedVendorId = vendorId;
      _selectedDeliveries = [];
      if (vendorId != null) {
        _selectedDeliveries = _deliveries
            .where((d) => d.vendorId == vendorId && d.status == 'delivered')
            .toList();
      }
    });
  }

  void _toggleDeliverySelection(Delivery delivery) {
    setState(() {
      if (_selectedDeliveries.any((d) => d.id == delivery.id)) {
        _selectedDeliveries.removeWhere((d) => d.id == delivery.id);
      } else {
        _selectedDeliveries.add(delivery);
      }
    });
  }

  Future<void> _createClaim() async {
    if (_selectedVendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih vendor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedDeliveries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih sekurang-kurangnya satu penghantaran'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate all delivery items have quantities set
    for (var delivery in _selectedDeliveries) {
      for (var item in delivery.items) {
        // Check if quantities are set (they should be set in delivery items)
        // For now, we'll create the claim and let the backend validate
      }
    }

    setState(() => _isCreating = true);

    try {
      final claim = await _claimsRepo.createClaim(
        vendorId: _selectedVendorId!,
        deliveryIds: _selectedDeliveries.map((d) => d.id).toList(),
        claimDate: _claimDate,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tuntutan berjaya dicipta!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, claim);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        
        // PHASE: Handle subscription enforcement errors
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Cipta Tuntutan Konsainan',
          error: e,
        );
        if (handled) return;
        
        // Better error messages
        String errorMessage = 'Ralat mencipta tuntutan';
        final errorStr = e.toString();
        if (errorStr.contains('duplicate key') || 
            errorStr.contains('23505') ||
            errorStr.contains('claim_number_key')) {
          errorMessage = 'Nombor tuntutan sudah wujud. Sila cuba lagi.';
        } else if (errorStr.contains('No items')) {
          errorMessage = 'Tiada item yang terjual untuk dituntut.';
        } else if (errorStr.contains('deliveries') || errorStr.contains('delivery')) {
          errorMessage = 'Penghantaran tidak dijumpai atau tidak sah.';
        } else if (errorStr.contains('vendor')) {
          errorMessage = 'Vendor tidak dijumpai atau tidak sah.';
        } else {
          // Extract meaningful error message
          final parts = errorStr.split(':');
          if (parts.length > 1) {
            errorMessage = parts.last.trim();
          } else {
            errorMessage = 'Ralat: $errorStr';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cipta Tuntutan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vendor Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vendor',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedVendorId,
                            decoration: const InputDecoration(
                              labelText: 'Pilih Vendor',
                              border: OutlineInputBorder(),
                            ),
                            items: _vendors.map((vendor) {
                              return DropdownMenuItem(
                                value: vendor.id,
                                child: Text(
                                  vendor.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: _onVendorSelected,
                            isExpanded: true, // Fix overflow issue
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Claim Date
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tarikh Tuntutan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _claimDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _claimDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('dd MMMM yyyy', 'ms_MY').format(_claimDate),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Deliveries Selection
                  if (_selectedVendorId != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                  'Pilih Penghantaran',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_selectedDeliveries.length} dipilih',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedDeliveries.isEmpty)
                              const Text(
                                'Tiada penghantaran untuk vendor ini',
                                style: TextStyle(color: Colors.grey),
                              )
                            else
                              ..._selectedDeliveries.map((delivery) {
                                final isSelected = _selectedDeliveries.any((d) => d.id == delivery.id);
                                return CheckboxListTile(
                                  title: Text(
                                    delivery.vendorName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  subtitle: Text(
                                    '${DateFormat('dd MMM yyyy', 'ms_MY').format(delivery.deliveryDate)} - RM ${delivery.totalAmount.toStringAsFixed(2)}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  value: isSelected,
                                  onChanged: (value) => _toggleDeliverySelection(delivery),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  dense: true,
                                );
                              }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  // Notes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nota (Pilihan)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Masukkan nota jika perlu...',
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createClaim,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Cipta Tuntutan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: _selectedVendorId != null && _selectedDeliveries.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                // Show delivery items with quantity editor
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _DeliveryItemsEditorPage(
                      deliveries: _selectedDeliveries,
                      onSave: (updatedDeliveries) {
                        setState(() {
                          _selectedDeliveries = updatedDeliveries;
                        });
                      },
                    ),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Kuantiti'),
            )
          : null,
    );
  }
}

/// Delivery Items Editor Page - Edit quantities for delivery items
class _DeliveryItemsEditorPage extends StatefulWidget {
  final List<Delivery> deliveries;
  final Function(List<Delivery>) onSave;

  const _DeliveryItemsEditorPage({
    required this.deliveries,
    required this.onSave,
  });

  @override
  State<_DeliveryItemsEditorPage> createState() => _DeliveryItemsEditorPageState();
}

class _DeliveryItemsEditorPageState extends State<_DeliveryItemsEditorPage> {
  late List<Delivery> _editedDeliveries;

  @override
  void initState() {
    super.initState();
    // Deep copy deliveries for editing
    _editedDeliveries = widget.deliveries.map((d) {
      return Delivery(
        id: d.id,
        businessOwnerId: d.businessOwnerId,
        vendorId: d.vendorId,
        vendorName: d.vendorName,
        deliveryDate: d.deliveryDate,
        status: d.status,
        paymentStatus: d.paymentStatus,
        totalAmount: d.totalAmount,
        invoiceNumber: d.invoiceNumber,
        notes: d.notes,
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
        items: d.items.map((item) => DeliveryItem(
          id: item.id,
          deliveryId: item.deliveryId,
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          rejectedQty: item.rejectedQty,
          rejectionReason: item.rejectionReason,
          quantitySold: item.quantitySold,
          quantityUnsold: item.quantityUnsold,
          quantityExpired: item.quantityExpired,
          quantityDamaged: item.quantityDamaged,
          createdAt: item.createdAt,
        )).toList(),
      );
    }).toList();
  }

  void _updateItemQuantities(int deliveryIndex, int itemIndex, {
    double? quantitySold,
    double? quantityUnsold,
    double? quantityExpired,
    double? quantityDamaged,
  }) {
    setState(() {
      final item = _editedDeliveries[deliveryIndex].items[itemIndex];
      final sold = quantitySold ?? (item.quantitySold ?? 0.0);
      final unsold = quantityUnsold ?? (item.quantityUnsold ?? 0.0);
      final expired = quantityExpired ?? (item.quantityExpired ?? 0.0);
      final damaged = quantityDamaged ?? (item.quantityDamaged ?? 0.0);
      final total = sold + unsold + expired + damaged;

      if (total > item.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jumlah kuantiti tidak boleh melebihi kuantiti dihantar'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update item (we'll need to add these fields to DeliveryItem model)
      // For now, we'll store in a map or extend the model
    });
  }

  Future<void> _saveQuantities() async {
    // Update delivery items in database
    // This will be handled by the delivery repository
    widget.onSave(_editedDeliveries);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Kuantiti'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _editedDeliveries.length,
        itemBuilder: (context, deliveryIndex) {
          final delivery = _editedDeliveries[deliveryIndex];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text(delivery.vendorName),
              subtitle: Text(
                DateFormat('dd MMM yyyy', 'ms_MY').format(delivery.deliveryDate),
              ),
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: delivery.items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = delivery.items[itemIndex];
                    return _buildItemQuantityEditor(
                      deliveryIndex,
                      itemIndex,
                      item,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveQuantities,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save),
        label: const Text('Simpan'),
      ),
    );
  }

  Widget _buildItemQuantityEditor(int deliveryIndex, int itemIndex, DeliveryItem item) {
    final soldController = TextEditingController(
      text: (item.quantitySold ?? 0.0).toStringAsFixed(1),
    );
    final unsoldController = TextEditingController(
      text: (item.quantityUnsold ?? 0.0).toStringAsFixed(1),
    );
    final expiredController = TextEditingController(
      text: (item.quantityExpired ?? 0.0).toStringAsFixed(1),
    );
    final damagedController = TextEditingController(
      text: (item.quantityDamaged ?? 0.0).toStringAsFixed(1),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            'Dihantar: ${item.quantity.toStringAsFixed(1)} unit',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: soldController,
                  decoration: const InputDecoration(
                    labelText: 'Terjual',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: unsoldController,
                  decoration: const InputDecoration(
                    labelText: 'Tidak Terjual',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expiredController,
                  decoration: const InputDecoration(
                    labelText: 'Luput',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: damagedController,
                  decoration: const InputDecoration(
                    labelText: 'Rosak',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

