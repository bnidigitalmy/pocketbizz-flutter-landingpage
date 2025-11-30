import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/models/delivery.dart';

/// Edit Rejection Dialog
/// Allows editing rejection quantities and reasons for delivery items
class EditRejectionDialog extends StatefulWidget {
  final Delivery delivery;
  final DeliveriesRepositorySupabase deliveriesRepo;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const EditRejectionDialog({
    super.key,
    required this.delivery,
    required this.deliveriesRepo,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<EditRejectionDialog> createState() => _EditRejectionDialogState();
}

class _EditRejectionDialogState extends State<EditRejectionDialog> {
  final Map<String, TextEditingController> _rejectedQtyControllers = {};
  final Map<String, TextEditingController> _rejectionReasonControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.delivery.items) {
      _rejectedQtyControllers[item.id] = TextEditingController(
        text: item.rejectedQty.toStringAsFixed(1),
      );
      _rejectionReasonControllers[item.id] = TextEditingController(
        text: item.rejectionReason ?? '',
      );
    }
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

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      for (var item in widget.delivery.items) {
        final rejectedQtyController = _rejectedQtyControllers[item.id];
        final rejectionReasonController = _rejectionReasonControllers[item.id];
        
        if (rejectedQtyController != null && rejectionReasonController != null) {
          final rejectedQty = double.tryParse(rejectedQtyController.text) ?? 0.0;
          final rejectionReason = rejectionReasonController.text.trim().isEmpty 
              ? null 
              : rejectionReasonController.text.trim();

          await widget.deliveriesRepo.updateDeliveryItemRejection(
            itemId: item.id,
            rejectedQty: rejectedQty,
            rejectionReason: rejectionReason,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tolakan telah dikemaskini. Tuntutan akan dikira semula.'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Tolakan Penghantaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kemaskini kuantiti dan sebab tolakan untuk produk yang expired/rosak selepas penghantaran.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.delivery.vendorName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.delivery.invoiceNumber ?? 'N/A'} - ${widget.delivery.deliveryDate.toString().split(' ')[0]}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...widget.delivery.items.map((item) => _buildItemCard(item)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () {
            widget.onCancel();
            Navigator.pop(context);
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Simpan Perubahan'),
        ),
      ],
    );
  }

  Widget _buildItemCard(DeliveryItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
            const SizedBox(height: 4),
            Text(
              'Kuantiti dihantar: ${item.quantity.toStringAsFixed(1)} unit @ RM ${item.unitPrice.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rejectedQtyControllers[item.id],
                    decoration: const InputDecoration(
                      labelText: 'Kuantiti Ditolak',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final qty = double.tryParse(value ?? '0') ?? 0;
                      if (qty < 0 || qty > item.quantity) {
                        return '0 - ${item.quantity.toStringAsFixed(1)}';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rejectionReasonControllers[item.id],
                    decoration: const InputDecoration(
                      labelText: 'Sebab Tolakan',
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Cth: Expired, Rosak',
                    ),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

