import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/claims_repository_supabase.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/models/claim.dart';
import '../../../data/models/vendor.dart';

/// Claim Details Dialog
/// Shows detailed product view with summary and individual invoice breakdown
class ClaimDetailsDialog extends StatefulWidget {
  final String vendorId;
  final ClaimsRepositorySupabase claimsRepo;
  final DeliveriesRepositorySupabase deliveriesRepo;
  final List<Vendor> vendors;
  final Function({required String itemId, required double rejectedQty, required String? rejectionReason}) onUpdateRejection;
  final Function(String deliveryId, String paymentStatus) onUpdatePaymentStatus;
  final VoidCallback onClose;

  const ClaimDetailsDialog({
    super.key,
    required this.vendorId,
    required this.claimsRepo,
    required this.deliveriesRepo,
    required this.vendors,
    required this.onUpdateRejection,
    required this.onUpdatePaymentStatus,
    required this.onClose,
  });

  @override
  State<ClaimDetailsDialog> createState() => _ClaimDetailsDialogState();
}

class _ClaimDetailsDialogState extends State<ClaimDetailsDialog> {
  ClaimDetails? _claimDetails;
  bool _isLoading = true;
  String _viewMode = 'summary'; // 'summary' or 'individual'
  final Map<String, TextEditingController> _rejectedQtyControllers = {};
  final Map<String, TextEditingController> _rejectionReasonControllers = {};

  @override
  void initState() {
    super.initState();
    _loadClaimDetails();
  }

  @override
  void dispose() {
    for (var controller in _rejectedQtyControllers.values) {
      controller.dispose();
    }
    for (var controller in _rejectionReasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadClaimDetails() async {
    setState(() => _isLoading = true);
    try {
      final details = await widget.claimsRepo.getClaimDetails(widget.vendorId);
      
      // Initialize controllers for all items
      for (var delivery in details.deliveries) {
        for (var item in delivery.items) {
          if (!_rejectedQtyControllers.containsKey(item.id)) {
            _rejectedQtyControllers[item.id] = TextEditingController(
              text: item.rejectedQty.toStringAsFixed(1),
            );
          }
          if (!_rejectionReasonControllers.containsKey(item.id)) {
            _rejectionReasonControllers[item.id] = TextEditingController(
              text: item.rejectionReason ?? '',
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _claimDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading claim details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleRejectedQtyChange(String itemId, String value) {
    final rejectedQty = double.tryParse(value) ?? 0.0;
    final item = _findItem(itemId);
    if (item != null && rejectedQty != item.rejectedQty) {
      widget.onUpdateRejection(
        itemId: itemId,
        rejectedQty: rejectedQty,
        rejectionReason: _rejectionReasonControllers[itemId]?.text ?? '',
      );
      // Reload after update
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadClaimDetails();
      });
    }
  }

  void _handleRejectionReasonChange(String itemId, String value) {
    final item = _findItem(itemId);
    if (item != null && value != (item.rejectionReason ?? '')) {
      widget.onUpdateRejection(
        itemId: itemId,
        rejectedQty: item.rejectedQty,
        rejectionReason: value.isEmpty ? null : value,
      );
      // Reload after update
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadClaimDetails();
      });
    }
  }

  DeliveryItemWithClaimData? _findItem(String itemId) {
    for (var delivery in _claimDetails?.deliveries ?? []) {
      for (var item in delivery.items) {
        if (item.id == itemId) {
          return item;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.inventory_2, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Detail Produk - ${_claimDetails?.vendorName ?? 'Loading...'}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _claimDetails == null
                ? const Center(child: Text('Tiada data'))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Senarai lengkap produk untuk semua invois vendor ini',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        // Summary Card
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        // View Mode Toggle
                        _buildViewModeToggle(),
                        const SizedBox(height: 16),
                        // Content based on view mode
                        _viewMode == 'summary'
                            ? _buildSummaryView()
                            : _buildIndividualView(),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onClose,
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    'RM ${_claimDetails!.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text('Jumlah', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'RM ${_claimDetails!.pendingAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text('Belum Bayar', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'RM ${_claimDetails!.partialAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text('Separa', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'RM ${_claimDetails!.settledAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text('Selesai', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _viewMode == 'summary'
                ? null
                : () => setState(() => _viewMode = 'summary'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _viewMode == 'summary' ? AppColors.primary : null,
              foregroundColor: _viewMode == 'summary' ? Colors.white : null,
            ),
            child: const Text('Ringkasan'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: _viewMode == 'individual'
                ? null
                : () => setState(() => _viewMode = 'individual'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _viewMode == 'individual' ? AppColors.primary : null,
              foregroundColor: _viewMode == 'individual' ? Colors.white : null,
            ),
            child: const Text('Per Invois'),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryView() {
    // Group all products from all deliveries
    final productSummary = <String, Map<String, dynamic>>{};

    for (var delivery in _claimDetails!.deliveries) {
      for (var item in delivery.items) {
        if (!productSummary.containsKey(item.productName)) {
          productSummary[item.productName] = {
            'quantity': 0.0,
            'totalPrice': 0.0,
            'unitPrice': item.unitPrice,
          };
        }
        final summary = productSummary[item.productName]!;
        summary['quantity'] = (summary['quantity'] as double) + item.quantity;
        summary['totalPrice'] = (summary['totalPrice'] as double) + item.totalPrice;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Produk (${_claimDetails!.totalDeliveries} invois)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...productSummary.entries.map((entry) {
              final name = entry.key;
              final data = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('@ RM ${data['unitPrice'].toStringAsFixed(2)} per unit'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${data['quantity'].toStringAsFixed(1)} unit',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'RM ${data['totalPrice'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualView() {
    return Column(
      children: _claimDetails!.deliveries.map((delivery) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            delivery.invoiceNumber ?? 'Invois #${_claimDetails!.deliveries.indexOf(delivery) + 1}',
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
                          Text(
                            '${delivery.items.length} jenis produk',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    _buildPaymentStatusBadge(delivery.paymentStatus ?? 'pending'),
                  ],
                ),
              ),
              // Items
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: delivery.items.map((item) => _buildItemCard(item, delivery)).toList(),
                ),
              ),
              // Invoice summary
              _buildInvoiceSummary(delivery),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemCard(DeliveryItemWithClaimData item, DeliveryWithClaimData delivery) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity.toStringAsFixed(1)}x @ RM ${item.unitPrice.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Rejection input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expired/Rosak/Return',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rejectedQtyControllers[item.id],
                          decoration: InputDecoration(
                            labelText: 'Kuantiti',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixText: 'Max: ${item.quantity.toStringAsFixed(1)}',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => _handleRejectedQtyChange(item.id, value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _rejectionReasonControllers[item.id],
                          decoration: const InputDecoration(
                            labelText: 'Sebab (optional)',
                            hintText: 'Expired, rosak, etc',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) => _handleRejectionReasonChange(item.id, value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Commission breakdown
            if (item.itemGross != null) ...[
              _buildCommissionBreakdown(item),
            ] else ...[
              // Fallback
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jumlah:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'RM ${item.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionBreakdown(DeliveryItemWithClaimData item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jumlah Kasar:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                'RM ${item.itemGross!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (item.itemRejected != null && item.itemRejected! > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tolakan (${item.rejectedQty.toStringAsFixed(1)} unit):',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
                Text(
                  '- RM ${item.itemRejected!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jumlah Bersih:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(
                'RM ${item.itemNet!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          // Commission already deducted in delivery, so no need to show as deduction
          // Only show as info for backward compatibility with old claims
          if (item.itemCommission != null && item.itemCommission! > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Nota: Komisyen sudah ditolak dalam invois penghantaran',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Boleh Dituntut:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                'RM ${item.itemClaimable!.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummary(DeliveryWithClaimData delivery) {
    // Calculate totals
    double grossTotal = 0.0;
    double rejectedTotal = 0.0;
    double commissionTotal = 0.0;
    double claimableTotal = 0.0;

    for (var item in delivery.items) {
      grossTotal += item.itemGross ?? item.totalPrice;
      rejectedTotal += item.itemRejected ?? 0.0;
      commissionTotal += item.itemCommission ?? 0.0;
      claimableTotal += item.itemClaimable ?? item.totalPrice;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'RINGKASAN INVOIS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jumlah Kasar:', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              Text(
                'RM ${grossTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (rejectedTotal > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tolak Expired/Rosak:',
                  style: TextStyle(fontSize: 13, color: Colors.orange[700]),
                ),
                Text(
                  '- RM ${rejectedTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[700],
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Jumlah Bersih:', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              Text(
                'RM ${(grossTotal - rejectedTotal).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          // Commission already deducted in delivery, so no need to show as deduction
          // Only show as info for backward compatibility with old claims
          if (commissionTotal > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nota: Komisyen sudah ditolak dalam invois penghantaran. Harga unit yang digunakan adalah harga selepas tolak komisyen.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(thickness: 2),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'JUMLAH KESELURUHAN:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'RM ${claimableTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
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

