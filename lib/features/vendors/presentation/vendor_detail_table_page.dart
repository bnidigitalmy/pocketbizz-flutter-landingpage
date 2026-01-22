import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../utils/vendor_detail_pdf_generator.dart';

/// Vendor Detail Table Page
/// Shows detailed breakdown for a specific vendor: deliveries, products, sold, expired, carry forward, claims, payments
class VendorDetailTablePage extends StatefulWidget {
  final String vendorId;

  const VendorDetailTablePage({super.key, required this.vendorId});

  @override
  State<VendorDetailTablePage> createState() => _VendorDetailTablePageState();
}

class _VendorDetailTablePageState extends State<VendorDetailTablePage> {
  final _vendorsRepo = VendorsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();
  
  Map<String, dynamic>? _vendorData;
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
      final dataFuture = _vendorsRepo.getVendorDetailedData(widget.vendorId);
      final profileFuture = _businessProfileRepo.getBusinessProfile();

      final data = await dataFuture;
      final profile = await profileFuture;

      if (mounted) {
        // Debug: Check data structure
        debugPrint('Vendor data keys: ${data.keys.toList()}');
        final deliveries = data['deliveries'] as List<dynamic>? ?? [];
        debugPrint('Total deliveries: ${deliveries.length}');
        if (deliveries.isNotEmpty) {
          final firstDelivery = deliveries.first as Map<String, dynamic>;
          debugPrint('First delivery keys: ${firstDelivery.keys.toList()}');
          debugPrint('First delivery invoice: ${firstDelivery['invoice_number']}');
          final items = firstDelivery['vendor_delivery_items'];
          debugPrint('First delivery items type: ${items.runtimeType}');
          if (items != null) {
            if (items is List) {
              debugPrint('First delivery items count: ${items.length}');
              if (items.isNotEmpty) {
                debugPrint('First item: ${items.first}');
              }
            } else {
              debugPrint('First delivery items (not a list): $items');
            }
          } else {
            debugPrint('First delivery items is null');
          }
        }
        
        setState(() {
          _vendorData = data;
          _businessProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor detail data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuatkan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _vendorData = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportPDF() async {
    if (_vendorData == null) {
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
      final pdfBytes = await VendorDetailPDFGenerator.generateDetailPDF(
        vendorData: _vendorData!,
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
    final vendor = _vendorData?['vendor'] as Map<String, dynamic>?;
    final vendorName = vendor?['name'] as String? ?? 'Vendor Details';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(vendorName),
        backgroundColor: AppColors.primary,
        actions: [
          if (_vendorData != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Muat turun PDF',
              onPressed: _exportPDF,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat semula',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vendorData == null
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      
                      return SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary Cards
                              _buildSummaryCards(),
                              const SizedBox(height: 20),
                              
                              // Deliveries & Products Table
                              _buildDeliveriesTable(isMobile: isMobile),
                              const SizedBox(height: 20),
                              
                              // Claims Table
                              _buildClaimsTable(isMobile: isMobile),
                              const SizedBox(height: 20),
                              
                              // Payments Table
                              _buildPaymentsTable(isMobile: isMobile),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('Tiada data vendor'),
    );
  }

  Widget _buildSummaryCards() {
    final deliveries = _vendorData!['deliveries'] as List<dynamic>? ?? [];
    final claims = _vendorData!['claims'] as List<dynamic>? ?? [];
    final payments = _vendorData!['payments'] as List<dynamic>? ?? [];

    // Calculate totals
    double totalDeliveryAmount = 0.0;
    double totalSold = 0.0;
    double totalExpired = 0.0;
    double totalCarryForward = 0.0; // From delivery items (unsold)
    double totalNetClaims = 0.0;
    double totalPaid = 0.0;
    double totalBalance = 0.0;
    
    // Calculate C/F items info
    final cfItems = _vendorData?['carry_forward_items'] as List<dynamic>? ?? [];
    double totalAvailableCF = 0.0; // Available C/F items
    double totalUsedCF = 0.0; // Used C/F items
    int availableCFCount = 0;
    int usedCFCount = 0;
    
    for (var cfItem in cfItems) {
      final status = cfItem['status'] as String? ?? '';
      final quantity = (cfItem['quantity_available'] as num?)?.toDouble() ?? 0.0;
      
      if (status == 'available') {
        totalAvailableCF += quantity;
        availableCFCount++;
      } else if (status == 'used') {
        totalUsedCF += quantity;
        usedCFCount++;
      }
    }

    for (var delivery in deliveries) {
      totalDeliveryAmount += (delivery['total_amount'] as num?)?.toDouble() ?? 0.0;
      final items = delivery['vendor_delivery_items'] as List<dynamic>? ?? [];
      for (var item in items) {
        totalSold += (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
        totalExpired += (item['quantity_expired'] as num?)?.toDouble() ?? 0.0;
        totalCarryForward += (item['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
      }
    }

    for (var claim in claims) {
      totalNetClaims += (claim['net_amount'] as num?)?.toDouble() ?? 0.0;
      totalBalance += (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;
    }

    for (var payment in payments) {
      totalPaid += (payment['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 2 : 4;
        final cardWidth = isMobile 
            ? (constraints.maxWidth - 32 - 12) / 2 // 2 columns with spacing
            : 150.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isMobile ? 1.1 : 0.85,
              children: [
                _buildSummaryCard('Jumlah Penghantaran', deliveries.length.toString(), Icons.local_shipping, AppColors.primary, cardWidth),
                _buildSummaryCard('Jumlah Nilai Dihantar', _currencyFormat.format(totalDeliveryAmount), Icons.attach_money, Colors.blue, cardWidth),
                _buildSummaryCard('Jumlah Terjual', totalSold.toStringAsFixed(0), Icons.shopping_cart, Colors.green, cardWidth),
                _buildSummaryCard('Jumlah Luput', totalExpired.toStringAsFixed(0), Icons.event_busy, Colors.purple, cardWidth),
                _buildSummaryCard('Belum Terjual', totalCarryForward.toStringAsFixed(0), Icons.inventory, Colors.grey, cardWidth),
                _buildSummaryCard('C/F Available', '${totalAvailableCF.toStringAsFixed(0)}\n($availableCFCount item)', Icons.forward, Colors.orange, cardWidth),
                _buildSummaryCard('C/F Used', '${totalUsedCF.toStringAsFixed(0)}\n($usedCFCount item)', Icons.check_circle, Colors.teal, cardWidth),
                _buildSummaryCard('Jumlah Tuntutan', _currencyFormat.format(totalNetClaims), Icons.receipt_long, Colors.teal, cardWidth),
                _buildSummaryCard('Jumlah Dibayar', _currencyFormat.format(totalPaid), Icons.payment, Colors.green, cardWidth),
                _buildSummaryCard('Baki Tertunggak', _currencyFormat.format(totalBalance), Icons.pending, totalBalance > 0 ? Colors.red : Colors.green, cardWidth),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, double? width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesTable({bool isMobile = false}) {
    final deliveries = _vendorData!['deliveries'] as List<dynamic>? ?? [];

    if (deliveries.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: const Text('Tiada penghantaran'),
        ),
      );
    }

    if (isMobile) {
      // Mobile: Group by invoice number
      final Map<String, List<Map<String, dynamic>>> groupedByInvoice = {};
      
      for (var delivery in deliveries) {
        final invoiceNumber = delivery['invoice_number'] as String? ?? 'Tiada Invois';
        final deliveryDate = delivery['delivery_date'] as String?;
        
        // Handle items - could be List<dynamic> or null
        var items = delivery['vendor_delivery_items'];
        List<dynamic> itemsList = [];
        
        if (items != null) {
          if (items is List) {
            itemsList = items;
          } else if (items is Map) {
            // If it's a single item wrapped in a map, convert to list
            itemsList = [items];
          }
        }
        
        if (!groupedByInvoice.containsKey(invoiceNumber)) {
          groupedByInvoice[invoiceNumber] = [];
        }
        
        // Add delivery info with items
        groupedByInvoice[invoiceNumber]!.add({
          'delivery_date': deliveryDate,
          'invoice_number': invoiceNumber,
          'items': itemsList,
        });
      }
      
      final invoiceEntries = groupedByInvoice.entries.toList();
      
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Penghantaran & Produk',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Use ListView.builder for virtual scrolling (better performance for large lists)
              // Use shrinkWrap with NeverScrollableScrollPhysics for nested scrolling in SingleChildScrollView
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoiceEntries.length,
                itemBuilder: (context, index) {
                  final entry = invoiceEntries[index];
                  return _buildMobileInvoiceGroup(
                    invoiceNumber: entry.key,
                    deliveries: entry.value,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Desktop: Use table layout
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penghantaran & Produk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 56,
                dataRowHeight: 48,
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('Tarikh\nPenghantaran', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('No. Invois', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Produk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Dihantar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Terjual', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Luput', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Carry\nForward', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Ditolak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Harga\nUnit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Jumlah\n(RM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                rows: _buildDeliveryRows(deliveries),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileInvoiceGroup({
    required String invoiceNumber,
    required List<Map<String, dynamic>> deliveries,
  }) {
    // Calculate totals for this invoice
    double totalInvoiceAmount = 0.0;
    double totalDelivered = 0.0;
    double totalSold = 0.0;
    double totalExpired = 0.0;
    double totalUnsold = 0.0;
    double totalRejected = 0.0;
    int totalProducts = 0;
    String? latestDeliveryDate;
    
    final List<Map<String, dynamic>> allItems = [];
    
    for (var delivery in deliveries) {
      final deliveryDate = delivery['delivery_date'] as String?;
      
      if (deliveryDate != null && (latestDeliveryDate == null || deliveryDate.compareTo(latestDeliveryDate) > 0)) {
        latestDeliveryDate = deliveryDate;
      }
      
      // Handle items - in grouped data, items are stored as 'items' not 'vendor_delivery_items'
      var items = delivery['items'];
      List<dynamic> itemsList = [];
      
      if (items != null) {
        if (items is List) {
          itemsList = items;
        } else if (items is Map) {
          // If it's a single item wrapped in a map, convert to list
          itemsList = [items];
        }
      }
      
      debugPrint('Processing delivery in group - items count: ${itemsList.length}');
      
      for (var item in itemsList) {
        // Ensure item is a Map
        if (item is! Map<String, dynamic>) {
          debugPrint('Warning: Item is not a Map: $item');
          continue;
        }
        
        final productName = item['product_name'] as String?;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final quantitySold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
        final quantityExpired = (item['quantity_expired'] as num?)?.toDouble() ?? 0.0;
        final quantityUnsold = (item['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
        final rejectedQty = (item['rejected_qty'] as num?)?.toDouble() ?? 0.0;
        final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
        final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
        
        allItems.add({
          'product_name': productName,
          'quantity': quantity,
          'quantity_sold': quantitySold,
          'quantity_expired': quantityExpired,
          'quantity_unsold': quantityUnsold,
          'rejected_qty': rejectedQty,
          'unit_price': unitPrice,
          'total_price': totalPrice,
        });
        
        totalDelivered += quantity;
        totalSold += quantitySold;
        totalExpired += quantityExpired;
        totalUnsold += quantityUnsold;
        totalRejected += rejectedQty;
        totalInvoiceAmount += totalPrice;
        totalProducts++;
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invoiceNumber,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            if (latestDeliveryDate != null) ...[
              const SizedBox(height: 2),
              Text(
                _formatDate(latestDeliveryDate),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.inventory_2, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '$totalProducts jenis produk',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.attach_money, size: 12, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _currencyFormat.format(totalInvoiceAmount),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${allItems.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 18),
            ],
          ),
        ),
        children: [
          // Summary metrics
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileMetric('Dihantar', totalDelivered.toStringAsFixed(0), AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMobileMetric('Terjual', totalSold.toStringAsFixed(0), Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildMobileMetric('Luput', totalExpired.toStringAsFixed(0), Colors.purple),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMobileMetric('Carry Forward', totalUnsold.toStringAsFixed(0), Colors.orange),
                    ),
                  ],
                ),
                if (totalRejected > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMobileMetric('Ditolak', totalRejected.toStringAsFixed(0), Colors.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Products list - Use ListView.builder for virtual scrolling
          SizedBox(
            height: allItems.length > 5 ? 300 : null, // Limit height if many items
            child: ListView.builder(
              shrinkWrap: allItems.length <= 5, // Only shrinkWrap if few items
              physics: allItems.length <= 5 ? const NeverScrollableScrollPhysics() : null,
              itemCount: allItems.length,
              itemBuilder: (context, index) {
                return _buildMobileProductItem(allItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProductItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item['product_name'] as String? ?? 'Tiada Produk',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item['total_price'] != null)
                Text(
                  _currencyFormat.format((item['total_price'] as num?)?.toDouble() ?? 0.0),
                  style: TextStyle(
                    fontSize: 13,
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
                child: _buildMobileSmallMetric('Dihantar', (item['quantity'] as num?)?.toStringAsFixed(0) ?? '0', AppColors.primary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMobileSmallMetric('Terjual', (item['quantity_sold'] as num?)?.toStringAsFixed(0) ?? '0', Colors.green),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMobileSmallMetric('Luput', (item['quantity_expired'] as num?)?.toStringAsFixed(0) ?? '0', Colors.purple),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMobileSmallMetric('CF', (item['quantity_unsold'] as num?)?.toStringAsFixed(0) ?? '0', Colors.orange),
              ),
            ],
          ),
          if (((item['rejected_qty'] as num?)?.toDouble() ?? 0.0) > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildMobileSmallMetric('Ditolak', (item['rejected_qty'] as num?)?.toStringAsFixed(0) ?? '0', Colors.red),
                ),
                if (item['unit_price'] != null) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildMobileSmallMetric('Harga', _currencyFormat.format((item['unit_price'] as num?)?.toDouble() ?? 0.0), Colors.blue),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileSmallMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
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

  List<DataRow> _buildDeliveryRows(List<dynamic> deliveries) {
    final List<DataRow> rows = [];

    for (var delivery in deliveries) {
      final deliveryDate = delivery['delivery_date'] as String?;
      final invoiceNumber = delivery['invoice_number'] as String?;
      final items = delivery['vendor_delivery_items'] as List<dynamic>? ?? [];

      if (items.isEmpty) {
        rows.add(DataRow(
          cells: [
            DataCell(Text(_formatDate(deliveryDate))),
            DataCell(Text(invoiceNumber ?? '-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
            const DataCell(Text('-')),
          ],
        ));
      } else {
        for (var item in items) {
          rows.add(DataRow(
            cells: [
              DataCell(Text(_formatDate(deliveryDate))),
              DataCell(Text(invoiceNumber ?? '-')),
              DataCell(Text(item['product_name'] ?? '-')),
              DataCell(Text((item['quantity'] as num?)?.toStringAsFixed(0) ?? '0')),
              DataCell(Text((item['quantity_sold'] as num?)?.toStringAsFixed(0) ?? '0')),
              DataCell(Text((item['quantity_expired'] as num?)?.toStringAsFixed(0) ?? '0')),
              DataCell(Text((item['quantity_unsold'] as num?)?.toStringAsFixed(0) ?? '0')),
              DataCell(Text((item['rejected_qty'] as num?)?.toStringAsFixed(0) ?? '0')),
              DataCell(Text(_currencyFormat.format((item['unit_price'] as num?)?.toDouble() ?? 0.0))),
              DataCell(Text(_currencyFormat.format((item['total_price'] as num?)?.toDouble() ?? 0.0))),
            ],
          ));
        }
      }
    }

    return rows;
  }

  Widget _buildClaimsTable({bool isMobile = false}) {
    final claims = _vendorData!['claims'] as List<dynamic>? ?? [];

    if (claims.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: const Text('Tiada tuntutan'),
        ),
      );
    }

    if (isMobile) {
      // Mobile: Use card-based layout
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tuntutan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Use ListView.builder for virtual scrolling
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: claims.length,
                itemBuilder: (context, index) {
                  return _buildMobileClaimCard(claims[index]);
                },
              ),
            ],
          ),
        ),
      );
    }

    // Desktop: Use table layout
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tuntutan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 56,
                dataRowHeight: 48,
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('No. Tuntutan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Tarikh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Jumlah\nKasar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Komisyen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Jumlah\nBersih', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Dibayar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Baki', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                rows: claims.map((claim) {
                  final status = claim['status'] as String? ?? 'draft';
                  final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(claim['claim_number'] ?? '-')),
                      DataCell(Text(_formatDate(claim['claim_date']))),
                      DataCell(_buildStatusBadge(status)),
                      DataCell(Text(_currencyFormat.format((claim['gross_amount'] as num?)?.toDouble() ?? 0.0))),
                      DataCell(Text(_currencyFormat.format((claim['commission_amount'] as num?)?.toDouble() ?? 0.0))),
                      DataCell(Text(_currencyFormat.format((claim['net_amount'] as num?)?.toDouble() ?? 0.0))),
                      DataCell(Text(_currencyFormat.format((claim['paid_amount'] as num?)?.toDouble() ?? 0.0))),
                      DataCell(Text(
                        _currencyFormat.format(balance),
                        style: TextStyle(
                          color: balance > 0 ? Colors.red[700] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileClaimCard(Map<String, dynamic> claim) {
    final status = claim['status'] as String? ?? 'draft';
    final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;
    final grossAmount = (claim['gross_amount'] as num?)?.toDouble() ?? 0.0;
    final commissionAmount = (claim['commission_amount'] as num?)?.toDouble() ?? 0.0;
    final netAmount = (claim['net_amount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (claim['paid_amount'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
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
                      claim['claim_number'] ?? '-',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(claim['claim_date']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMobileMetric('Jumlah Kasar', _currencyFormat.format(grossAmount), Colors.blue),
              ),
              Expanded(
                child: _buildMobileMetric('Komisyen', _currencyFormat.format(commissionAmount), Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMobileMetric('Jumlah Bersih', _currencyFormat.format(netAmount), Colors.teal),
              ),
              Expanded(
                child: _buildMobileMetric('Dibayar', _currencyFormat.format(paidAmount), Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: balance > 0 ? Colors.red[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: balance > 0 ? Colors.red[300]! : Colors.green[300]!,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Baki Tertunggak',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currencyFormat.format(balance),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: balance > 0 ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable({bool isMobile = false}) {
    final payments = _vendorData!['payments'] as List<dynamic>? ?? [];

    if (payments.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: const Text('Tiada bayaran'),
        ),
      );
    }

    if (isMobile) {
      // Mobile: Use card-based layout
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Use ListView.builder for virtual scrolling
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  return _buildMobilePaymentCard(payments[index]);
                },
              ),
            ],
          ),
        ),
      );
    }

    // Desktop: Use table layout
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 56,
                dataRowHeight: 48,
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('Tarikh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Kaedah', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Rujukan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Jumlah\n(RM)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                ],
                rows: payments.map((payment) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_formatDate(payment['payment_date']))),
                      DataCell(Text(_formatPaymentMethod(payment['payment_method']))),
                      DataCell(Text(payment['payment_reference'] ?? '-')),
                      DataCell(Text(
                        _currencyFormat.format((payment['total_amount'] as num?)?.toDouble() ?? 0.0),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePaymentCard(Map<String, dynamic> payment) {
    final amount = (payment['total_amount'] as num?)?.toDouble() ?? 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
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
                      _formatDate(payment['payment_date']),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPaymentMethod(payment['payment_method']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (payment['payment_reference'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Rujukan: ${payment['payment_reference']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(
                  _currencyFormat.format(amount),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'draft':
        color = Colors.grey;
        label = 'Draf';
        break;
      case 'submitted':
        color = Colors.orange;
        label = 'Dihantar';
        break;
      case 'approved':
        color = Colors.blue;
        label = 'Diluluskan';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Ditolak';
        break;
      case 'settled':
        color = Colors.green;
        label = 'Selesai';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return _dateFormat.format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatPaymentMethod(String? method) {
    if (method == null) return '-';
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cek';
      default:
        return method;
    }
  }
}
