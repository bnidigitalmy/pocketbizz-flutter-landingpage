import 'package:flutter/material.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../core/utils/sales_receipt_pdf_generator.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../data/repositories/sales_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';

/**
 * 🔒 POCKETBIZZ CORE ENGINE (STABLE)
 * ❌ DO NOT MODIFY
 * ❌ DO NOT REFACTOR
 * ❌ DO NOT OPTIMIZE
 * This logic is production-tested.
 * New features must EXTEND, not change.
 */
/// Sale Details Dialog
/// Shows complete sale information with items
class SaleDetailsDialog extends StatelessWidget {
  final Sale sale;

  const SaleDetailsDialog({
    super.key,
    required this.sale,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Butiran Jualan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${sale.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Info
                    _buildInfoRow(
                      'Pelanggan',
                      sale.customerName ?? 'Pelanggan Tanpa Nama',
                      Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Saluran',
                      _getChannelLabel(sale.channel),
                      _getChannelIcon(sale.channel),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Tarikh & Masa',
                      DateTimeHelper.formatDateTime(DateTimeHelper.toLocalTime(sale.createdAt), pattern: 'dd MMM yyyy, HH:mm'),
                      Icons.access_time,
                    ),
                    // Show delivery address for online and delivery channels
                    if ((sale.channel == 'online' || sale.channel == 'delivery') && 
                        sale.deliveryAddress != null && 
                        sale.deliveryAddress!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Alamat Penghantaran',
                        sale.deliveryAddress!,
                        Icons.location_on,
                      ),
                    ],
                    if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Nota',
                        sale.notes!,
                        Icons.note,
                      ),
                    ],

                    const Divider(height: 32),

                    // Items
                    const Text(
                      'Item Jualan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (sale.items != null && sale.items!.isNotEmpty)
                      ...sale.items!.map((item) => _buildItemCard(item))
                    else
                      const Text('Tiada item'),

                    const Divider(height: 32),

                    // Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            'Jumlah',
                            'RM${sale.totalAmount.toStringAsFixed(2)}',
                            isBold: false,
                          ),
                          if (sale.discountAmount != null && sale.discountAmount! > 0) ...[
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Diskaun',
                              '-RM${sale.discountAmount!.toStringAsFixed(2)}',
                              isBold: false,
                              color: Colors.orange,
                            ),
                          ],
                          const Divider(height: 24),
                          _buildSummaryRow(
                            'Jumlah Akhir',
                            'RM${sale.finalAmount.toStringAsFixed(2)}',
                            isBold: true,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _printReceipt(context),
                      icon: const Icon(Icons.print),
                      label: const Text('Cetak'),
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(SaleItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity.toStringAsFixed(1)} ├ù RM${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'RM${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: color ?? (isBold ? Colors.green : null),
          ),
        ),
      ],
    );
  }

  IconData _getChannelIcon(String channel) {
    switch (channel) {
      case 'walk-in':
        return Icons.store;
      case 'online':
        return Icons.shopping_cart;
      case 'delivery':
        return Icons.delivery_dining;
      default:
        return Icons.receipt;
    }
  }

  String _getChannelLabel(String channel) {
    switch (channel) {
      case 'walk-in':
        return 'Walk-in';
      case 'online':
        return 'Online';
      case 'delivery':
        return 'Penghantaran';
      default:
        return channel.toUpperCase();
    }
  }

  Future<void> _printReceipt(BuildContext context) async {
    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Menyediakan resit...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Get business profile
      final businessProfileRepo = BusinessProfileRepository();
      BusinessProfile? businessProfile;
      try {
        businessProfile = await businessProfileRepo.getBusinessProfile();
      } catch (e) {
        // Business profile is optional, continue without it
        debugPrint('Could not load business profile: $e');
      }

      // Generate PDF
      final pdfBytes = await SalesReceiptPDFGenerator.generateSalesReceipt(
        sale,
        businessProfile: businessProfile,
      );

      // Print PDF
      await PDFGenerator.printPDF(pdfBytes, name: 'Resit Jualan #${sale.id.substring(0, 8).toUpperCase()}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Resit berjaya dicetak'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat mencetak resit: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

