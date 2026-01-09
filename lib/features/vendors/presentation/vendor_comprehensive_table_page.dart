import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../utils/vendor_comprehensive_pdf_generator.dart';

/// Vendor Comprehensive Table Page
/// Shows all vendors with deliveries, claims, and payments in table format (Excel-like)
class VendorComprehensiveTablePage extends StatefulWidget {
  const VendorComprehensiveTablePage({super.key});

  @override
  State<VendorComprehensiveTablePage> createState() => _VendorComprehensiveTablePageState();
}

class _VendorComprehensiveTablePageState extends State<VendorComprehensiveTablePage> {
  final _vendorsRepo = VendorsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();
  
  List<Map<String, dynamic>> _vendorData = [];
  BusinessProfile? _businessProfile;
  bool _isLoading = true;
  String _sortColumn = 'vendor_name';
  bool _sortAscending = true;

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
      final dataFuture = _vendorsRepo.getAllVendorsComprehensiveData();
      final profileFuture = _businessProfileRepo.getBusinessProfile();

      final data = await dataFuture;
      final profile = await profileFuture;

      if (mounted) {
        setState(() {
          _vendorData = data;
          _businessProfile = profile;
          _isLoading = false;
          _sortData();
        });
      }
    } catch (e) {
      debugPrint('Error loading vendor data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuatkan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _vendorData = [];
          _isLoading = false;
        });
      }
    }
  }

  void _sortData() {
    _vendorData.sort((a, b) {
      dynamic aValue = a[_sortColumn];
      dynamic bValue = b[_sortColumn];

      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return 1;
      if (bValue == null) return -1;

      if (aValue is String && bValue is String) {
        return _sortAscending 
            ? aValue.toLowerCase().compareTo(bValue.toLowerCase())
            : bValue.toLowerCase().compareTo(aValue.toLowerCase());
      }

      if (aValue is num && bValue is num) {
        return _sortAscending 
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }

      return 0;
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _sortData();
    });
  }

  Future<void> _exportPDF() async {
    if (_vendorData.isEmpty) {
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
      final pdfBytes = await VendorComprehensivePDFGenerator.generateTablePDF(
        vendorData: _vendorData,
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
        title: const Text('Ringkasan Vendor (Jadual)'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_vendorData.isNotEmpty)
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
          : _vendorData.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildTable(),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_chart, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tiada Data Vendor',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada vendor untuk dipaparkan',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: DataTable(
          headingRowHeight: 56,
          dataRowHeight: 64,
          headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
          sortColumnIndex: _getSortColumnIndex(),
          sortAscending: _sortAscending,
          columns: [
            _buildDataColumn('vendor_name', 'Vendor', 150),
            _buildDataColumn('vendor_number', 'No. Vendor', 100),
            // Deliveries
            _buildDataColumn('total_deliveries', 'Jumlah\nPenghantaran', 100),
            _buildDataColumn('total_delivery_amount', 'Jumlah Nilai\nPenghantaran', 130),
            // Claims
            _buildDataColumn('total_claims', 'Jumlah\nTuntutan', 90),
            _buildDataColumn('total_net_amount', 'Jumlah Tuntutan\n(Bersih)', 120),
            _buildDataColumn('total_commission', 'Jumlah\nKomisyen', 110),
            _buildDataColumn('total_paid_from_claims', 'Dibayar\n(Tuntutan)', 110),
            // Payments
            _buildDataColumn('total_payments', 'Jumlah\nBayaran', 90),
            _buildDataColumn('total_payment_amount', 'Jumlah Bayaran\n(Total)', 120),
            // Balance
            _buildDataColumn('total_balance', 'Baki\nTertunggak', 110),
            // Status
            _buildStatusColumn(),
          ],
          rows: _vendorData.map((vendor) => _buildDataRow(vendor)).toList(),
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String column, String label, double width) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      onSort: (columnIndex, ascending) => _onSort(column),
    );
  }

  DataColumn _buildStatusColumn() {
    return const DataColumn(
      label: SizedBox(
        width: 80,
        child: Text(
          'Status',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  int? _getSortColumnIndex() {
    final columns = [
      'vendor_name',
      'vendor_number',
      'total_deliveries',
      'total_delivery_amount',
      'total_claims',
      'total_net_amount',
      'total_commission',
      'total_paid_from_claims',
      'total_payments',
      'total_payment_amount',
      'total_balance',
    ];
    final index = columns.indexOf(_sortColumn);
    return index >= 0 ? index : null;
  }

  DataRow _buildDataRow(Map<String, dynamic> vendor) {
    final isActive = vendor['is_active'] as bool? ?? true;
    final totalBalance = (vendor['total_balance'] as num?)?.toDouble() ?? 0.0;

    return DataRow(
      cells: [
        // Vendor Name
        DataCell(
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor['vendor_name'] as String? ?? '-',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
                if (vendor['phone'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    vendor['phone'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Vendor Number
        DataCell(
          SizedBox(
            width: 100,
            child: Text(
              vendor['vendor_number'] as String? ?? '-',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ),
        ),
        // Total Deliveries
        DataCell(
          SizedBox(
            width: 100,
            child: Text(
              '${vendor['total_deliveries'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        // Total Delivery Amount
        DataCell(
          SizedBox(
            width: 130,
            child: Text(
              _currencyFormat.format((vendor['total_delivery_amount'] as num?)?.toDouble() ?? 0.0),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        // Total Claims
        DataCell(
          SizedBox(
            width: 90,
            child: Text(
              '${vendor['total_claims'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        // Total Net Amount (Claims)
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              _currencyFormat.format((vendor['total_net_amount'] as num?)?.toDouble() ?? 0.0),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.blue[700],
              ),
            ),
          ),
        ),
        // Total Commission
        DataCell(
          SizedBox(
            width: 110,
            child: Text(
              _currencyFormat.format((vendor['total_commission'] as num?)?.toDouble() ?? 0.0),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.orange[700],
              ),
            ),
          ),
        ),
        // Total Paid from Claims
        DataCell(
          SizedBox(
            width: 110,
            child: Text(
              _currencyFormat.format((vendor['total_paid_from_claims'] as num?)?.toDouble() ?? 0.0),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
          ),
        ),
        // Total Payments
        DataCell(
          SizedBox(
            width: 90,
            child: Text(
              '${vendor['total_payments'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        // Total Payment Amount
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              _currencyFormat.format((vendor['total_payment_amount'] as num?)?.toDouble() ?? 0.0),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
          ),
        ),
        // Total Balance
        DataCell(
          SizedBox(
            width: 110,
            child: Text(
              _currencyFormat.format(totalBalance),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: totalBalance > 0 ? Colors.red[700] : Colors.green[700],
              ),
            ),
          ),
        ),
        // Status
        DataCell(
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? Colors.green : Colors.grey,
                  width: 1,
                ),
              ),
              child: Text(
                isActive ? 'Aktif' : 'Tidak Aktif',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.green[700] : Colors.grey[700],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
