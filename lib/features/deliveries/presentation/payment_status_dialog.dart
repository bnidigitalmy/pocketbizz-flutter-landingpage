import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/delivery.dart';

/// Payment Status Dialog
/// Allows setting payment status for claimed deliveries
class PaymentStatusDialog extends StatefulWidget {
  final Delivery delivery;
  final Function(String) onSave;
  final VoidCallback onCancel;

  const PaymentStatusDialog({
    super.key,
    required this.delivery,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<PaymentStatusDialog> {
  String _selectedStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.delivery.paymentStatus ?? 'pending';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tetapkan Status Bayaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Penghantaran telah ditandakan sebagai "Dituntut". Sila tetapkan status bayaran untuk rekod tuntutan yang lebih teratur.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status Bayaran',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Belum Bayar'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'partial',
                child: Row(
                  children: [
                    Icon(Icons.payment, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Sebahagian'),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'settled',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Selesai'),
                  ],
                ),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedStatus = value);
              }
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Status bayaran ini akan kelihatan dalam halaman Tuntutan untuk memudahkan tracking pembayaran daripada vendor.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onCancel();
            Navigator.pop(context);
          },
          child: const Text('Nanti'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_selectedStatus);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan Status'),
        ),
      ],
    );
  }
}

