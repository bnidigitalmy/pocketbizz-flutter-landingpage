import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/deliveries_repository_supabase.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/business_profile.dart';
import '../utils/vendor_deliveries_pdf_generator.dart';

/// Vendor Deliveries Summary Page
/// Shows all deliveries for a vendor with detailed breakdown (sold, reject, expired, etc.)
class VendorDeliveriesSummaryPage extends StatefulWidget {
  final String vendorId;

  const VendorDeliveriesSummaryPage({super.key, required this.vendorId});

  @override
  State<VendorDeliveriesSummaryPage> createState() => _VendorDeliveriesSummaryPageState();
}

class _VendorDeliveriesSummaryPageState extends State<VendorDeliveriesSummaryPage> {
  final _deliveriesRepo = DeliveriesRepositorySupabase();
  final _vendorsRepo = VendorsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();
  
  Vendor? _vendor;
  List<Delivery> _deliveries = [];
  BusinessProfile? _businessProfile;
  bool _isLoading = true;

  final _currencyFormat = NumberFormat.currency(
    locale: 'ms_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  final _dateFormat = DateFormat('dd MMM yyyy', 'ms_MY');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load vendor, deliveries, and business profile in parallel
      final vendorFuture = _vendorsRepo.getVendorById(widget.vendorId);
      final deliveriesFuture = _deliveriesRepo.getAllDeliveriesForVendor(widget.vendorId);
      final businessProfileFuture = _businessProfileRepo.getBusinessProfile();

      final vendor = await vendorFuture;
      final deliveries = await deliveriesFuture;
      final businessProfile = await businessProfileFuture;

      if (mounted) {
        setState(() {
          _vendor = vendor;
          _deliveries = deliveries;
          _businessProfile = businessProfile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor deliveries: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuatkan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _vendor = null;
          _deliveries = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPDF() async {
    if (_vendor == null || _deliveries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiada data untuk dieksport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate PDF
      final pdfBytes = await VendorDeliveriesPDFGenerator.generateSummaryPDF(
        vendor: _vendor!,
        deliveries: _deliveries,
        businessProfile: _businessProfile,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show print/share dialog
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat menjana PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_vendor?.name ?? 'Ringkasan Penghantaran'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_deliveries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Muat turun PDF',
              onPressed: _exportPDF,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deliveries.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary Cards
                      _buildSummaryCards(),
                      
                      const SizedBox(height: 20),
                      
                      // Deliveries List
                      _buildDeliveriesList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tiada Penghantaran',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada penghantaran untuk vendor ini',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    // Calculate totals
    double totalDelivered = 0.0;
    double totalSold = 0.0;
    double totalRejected = 0.0;
    double totalExpired = 0.0;
    double totalDamaged = 0.0;
    double totalUnsold = 0.0;
    double totalAmount = 0.0;

    for (var delivery in _deliveries) {
      totalAmount += delivery.totalAmount;
      for (var item in delivery.items) {
        totalDelivered += item.quantity;
        totalRejected += item.rejectedQty;
        totalSold += item.quantitySold ?? 0.0;
        totalUnsold += item.quantityUnsold ?? 0.0;
        totalExpired += item.quantityExpired ?? 0.0;
        totalDamaged += item.quantityDamaged ?? 0.0;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Keseluruhan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Jumlah Penghantaran',
                _deliveries.length.toString(),
                Icons.list_alt,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Jumlah Nilai',
                _currencyFormat.format(totalAmount),
                Icons.attach_money,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Dihantar',
                totalDelivered.toStringAsFixed(0),
                Icons.local_shipping,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Terjual',
                totalSold.toStringAsFixed(0),
                Icons.shopping_cart,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Tidak Terjual',
                totalUnsold.toStringAsFixed(0),
                Icons.inventory_2,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Ditolak',
                totalRejected.toStringAsFixed(0),
                Icons.cancel,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Luput',
                totalExpired.toStringAsFixed(0),
                Icons.event_busy,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Rosak',
                totalDamaged.toStringAsFixed(0),
                Icons.warning,
                Colors.red[700]!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Senarai Penghantaran',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._deliveries.map((delivery) => _buildDeliveryCard(delivery)),
      ],
    );
  }

  Widget _buildDeliveryCard(Delivery delivery) {
    // Calculate totals for this delivery
    double totalDelivered = 0.0;
    double totalSold = 0.0;
    double totalRejected = 0.0;
    double totalExpired = 0.0;
    double totalDamaged = 0.0;
    double totalUnsold = 0.0;

    for (var item in delivery.items) {
      totalDelivered += item.quantity;
      totalRejected += item.rejectedQty;
      totalSold += item.quantitySold ?? 0.0;
      totalUnsold += item.quantityUnsold ?? 0.0;
      totalExpired += item.quantityExpired ?? 0.0;
      totalDamaged += item.quantityDamaged ?? 0.0;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        leading: Icon(
          _getStatusIcon(delivery.status),
          color: _getStatusColor(delivery.status),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              delivery.invoiceNumber ?? 'Tanpa No. Invois',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _dateFormat.format(delivery.deliveryDate),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _currencyFormat.format(delivery.totalAmount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        children: [
          // Status Badge
          _buildStatusBadge(delivery.status, delivery.paymentStatus),
          const SizedBox(height: 12),
          
          // Summary Metrics
          _buildDeliveryMetrics(
            totalDelivered: totalDelivered,
            totalSold: totalSold,
            totalUnsold: totalUnsold,
            totalRejected: totalRejected,
            totalExpired: totalExpired,
            totalDamaged: totalDamaged,
          ),
          
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          
          // Items List
          const Text(
            'Butiran Produk',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...delivery.items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, String? paymentStatus) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getStatusColor(status)),
          ),
          child: Text(
            _getStatusLabel(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getStatusColor(status),
            ),
          ),
        ),
        if (paymentStatus != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getPaymentStatusColor(paymentStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getPaymentStatusColor(paymentStatus)),
            ),
            child: Text(
              _getPaymentStatusLabel(paymentStatus),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getPaymentStatusColor(paymentStatus),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryMetrics({
    required double totalDelivered,
    required double totalSold,
    required double totalUnsold,
    required double totalRejected,
    required double totalExpired,
    required double totalDamaged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricItem('Dihantar', totalDelivered.toStringAsFixed(0), Icons.local_shipping, AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricItem('Terjual', totalSold.toStringAsFixed(0), Icons.shopping_cart, Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem('Tidak Terjual', totalUnsold.toStringAsFixed(0), Icons.inventory_2, Colors.orange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricItem('Ditolak', totalRejected.toStringAsFixed(0), Icons.cancel, Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem('Luput', totalExpired.toStringAsFixed(0), Icons.event_busy, Colors.purple),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricItem('Rosak', totalDamaged.toStringAsFixed(0), Icons.warning, Colors.red[700]!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
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
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _currencyFormat.format(item.totalPrice),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildItemMetric('Dihantar', item.quantity.toStringAsFixed(0), AppColors.primary),
              ),
              Expanded(
                child: _buildItemMetric('Terjual', (item.quantitySold ?? 0.0).toStringAsFixed(0), Colors.green),
              ),
              Expanded(
                child: _buildItemMetric('Tidak Terjual', (item.quantityUnsold ?? 0.0).toStringAsFixed(0), Colors.orange),
              ),
            ],
          ),
          if (item.rejectedQty > 0 || (item.quantityExpired ?? 0.0) > 0 || (item.quantityDamaged ?? 0.0) > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (item.rejectedQty > 0)
                  Expanded(
                    child: _buildItemMetric('Ditolak', item.rejectedQty.toStringAsFixed(0), Colors.red),
                  ),
                if ((item.quantityExpired ?? 0.0) > 0)
                  Expanded(
                    child: _buildItemMetric('Luput', item.quantityExpired!.toStringAsFixed(0), Colors.purple),
                  ),
                if ((item.quantityDamaged ?? 0.0) > 0)
                  Expanded(
                    child: _buildItemMetric('Rosak', item.quantityDamaged!.toStringAsFixed(0), Colors.red[700]!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'claimed':
        return Icons.receipt_long;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'claimed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'delivered':
        return 'Dihantar';
      case 'pending':
        return 'Menunggu';
      case 'claimed':
        return 'Dituntut';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  Color _getPaymentStatusColor(String paymentStatus) {
    switch (paymentStatus) {
      case 'settled':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'pending':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPaymentStatusLabel(String paymentStatus) {
    switch (paymentStatus) {
      case 'settled':
        return 'Selesai';
      case 'partial':
        return 'Separa';
      case 'pending':
        return 'Menunggu';
      default:
        return paymentStatus;
    }
  }
}
