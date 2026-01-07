import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/consignment_claims_repository_supabase.dart';
import '../../../data/repositories/consignment_payments_repository_supabase.dart';
import '../../../data/models/consignment_claim.dart';
import 'record_payment_page.dart';
import '../../../core/utils/pdf_generator.dart' as pdf_gen;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../data/models/business_profile.dart';
import '../../drive_sync/utils/drive_sync_helper.dart';
import '../../../core/services/document_storage_service.dart';

/// Claim Detail Page
/// Shows full details of a claim with all features
class ClaimDetailPage extends StatefulWidget {
  final String claimId;

  const ClaimDetailPage({
    super.key,
    required this.claimId,
  });

  @override
  State<ClaimDetailPage> createState() => _ClaimDetailPageState();
}

class _ClaimDetailPageState extends State<ClaimDetailPage> {
  final _claimsRepo = ConsignmentClaimsRepositorySupabase();
  final _paymentsRepo = ConsignmentPaymentsRepositorySupabase();
  final _businessProfileRepo = BusinessProfileRepository();
  
  ConsignmentClaim? _claim;
  BusinessProfile? _businessProfile;
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadClaim();
  }

  Future<void> _loadClaim() async {
    setState(() => _isLoading = true);
    try {
      // Load claim and business profile in parallel
      final results = await Future.wait([
        _claimsRepo.getClaimById(widget.claimId),
        _businessProfileRepo.getBusinessProfile(),
      ]);
      final claim = results[0] as ConsignmentClaim;
      final businessProfile = results[1] as BusinessProfile?;

      // Load payments for this claim
      final payments = await _paymentsRepo.getPaymentsByClaim(claim.id);

      if (mounted) {
        setState(() {
          _claim = claim;
          _businessProfile = businessProfile;
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuatkan tuntutan: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _generateAndSharePDF() async {
    if (_claim == null) return;

    setState(() => _isGeneratingPdf = true);
    try {
      // Convert claim items to ClaimItem format
      final claimItems = _claim!.items?.map((item) => pdf_gen.ClaimItem(
        productName: item.productName ?? 'Unknown Product',
        quantitySold: item.quantitySold,
        unitPrice: item.unitPrice,
        grossAmount: item.grossAmount,
        commissionAmount: item.commissionAmount,
        netAmount: item.netAmount,
      )).toList() ?? [];

      // Determine commission type: if rate is 0 and amount > 0, it's price_range
      final commissionType = (_claim!.commissionRate == 0.0 && _claim!.commissionAmount > 0)
          ? 'price_range'
          : 'percentage';

      final pdfBytes = await pdf_gen.PDFGenerator.generateClaimInvoice(
        claimNumber: _claim!.claimNumber,
        vendorName: _claim!.vendorName ?? 'Unknown Vendor',
        vendorPhone: '', // TODO: Get from vendor
        claimDate: _claim!.claimDate,
        grossAmount: _claim!.grossAmount,
        commissionRate: _claim!.commissionRate,
        commissionAmount: _claim!.commissionAmount,
        netAmount: _claim!.netAmount,
        paidAmount: _claim!.paidAmount,
        balanceAmount: _claim!.balanceAmount,
        items: claimItems,
        notes: _claim!.notes,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
        commissionType: commissionType,
      );
      
      // For web, use different approach
      if (kIsWeb) {
        // Web: Use share_plus with bytes
        await Share.shareXFiles(
          [XFile.fromData(pdfBytes, mimeType: 'application/pdf', name: 'claim_${_claim!.claimNumber}.pdf')],
          text: 'Invois Tuntutan: ${_claim!.claimNumber}',
        );
      } else {
        // Mobile: Save to temp directory first
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/claim_${_claim!.claimNumber}.pdf');
        await file.writeAsBytes(pdfBytes);

        // Share via WhatsApp or other apps
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Invois Tuntutan: ${_claim!.claimNumber}',
        );
      }

      // Auto-backup to Supabase Storage (non-blocking)
      final fileName = 'Claim_${_claim!.claimNumber}_${DateFormat('yyyyMMdd').format(_claim!.claimDate)}.pdf';
      DocumentStorageService.uploadDocumentSilently(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: 'claim_statement',
        relatedEntityType: 'claim',
        relatedEntityId: _claim!.id,
        vendorName: _claim!.vendorName,
      );

      // Auto-sync to Google Drive (non-blocking, optional)
      DriveSyncHelper.syncDocumentSilently(
        pdfData: pdfBytes,
        fileName: fileName,
        fileType: 'claim_statement',
        relatedEntityType: 'claim',
        relatedEntityId: _claim!.id,
        vendorName: _claim!.vendorName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF berjaya dijana dan sedia untuk dikongsi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat menjana PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  Future<void> _printPDF() async {
    if (_claim == null) return;

    setState(() => _isGeneratingPdf = true);
    try {
      // Convert claim items to ClaimItem format
      final claimItems = _claim!.items?.map((item) => pdf_gen.ClaimItem(
        productName: item.productName ?? 'Unknown Product',
        quantitySold: item.quantitySold,
        unitPrice: item.unitPrice,
        grossAmount: item.grossAmount,
        commissionAmount: item.commissionAmount,
        netAmount: item.netAmount,
      )).toList() ?? [];

      // Determine commission type: if rate is 0 and amount > 0, it's price_range
      final commissionType = (_claim!.commissionRate == 0.0 && _claim!.commissionAmount > 0)
          ? 'price_range'
          : 'percentage';

      final pdfBytes = await pdf_gen.PDFGenerator.generateClaimInvoice(
        claimNumber: _claim!.claimNumber,
        vendorName: _claim!.vendorName ?? 'Unknown Vendor',
        vendorPhone: '', // TODO: Get from vendor
        claimDate: _claim!.claimDate,
        grossAmount: _claim!.grossAmount,
        commissionRate: _claim!.commissionRate,
        commissionAmount: _claim!.commissionAmount,
        netAmount: _claim!.netAmount,
        paidAmount: _claim!.paidAmount,
        balanceAmount: _claim!.balanceAmount,
        items: claimItems,
        notes: _claim!.notes,
        businessName: _businessProfile?.businessName,
        businessAddress: _businessProfile?.address,
        businessPhone: _businessProfile?.phone,
        commissionType: commissionType,
      );
      
      // Use printing package to print
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
      );

      // Auto-backup to Supabase Storage (non-blocking)
      final fileName = 'Claim_${_claim!.claimNumber}_${DateFormat('yyyyMMdd').format(_claim!.claimDate)}.pdf';
      DocumentStorageService.uploadDocumentSilently(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: 'claim_statement',
        relatedEntityType: 'claim',
        relatedEntityId: _claim!.id,
        vendorName: _claim!.vendorName,
      );

      // Auto-sync to Google Drive (non-blocking, optional)
      DriveSyncHelper.syncDocumentSilently(
        pdfData: pdfBytes,
        fileName: fileName,
        fileType: 'claim_statement',
        relatedEntityType: 'claim',
        relatedEntityId: _claim!.id,
        vendorName: _claim!.vendorName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF sedia untuk dicetak'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat mencetak PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_claim?.claimNumber ?? 'Butiran Tuntutan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClaim,
            tooltip: 'Muat Semula',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _claim == null
              ? const Center(child: Text('Tuntutan tidak ditemui'))
              : RefreshIndicator(
                  onRefresh: _loadClaim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        _buildHeaderCard(),
                        const SizedBox(height: 16),

                        // Summary Card
                        _buildSummaryCard(),
                        const SizedBox(height: 16),

                        // Items List
                        if (_claim!.items != null && _claim!.items!.isNotEmpty) ...[
                          _buildItemsCard(),
                          const SizedBox(height: 16),
                        ],

                        // Payments history
                        _buildPaymentsCard(),
                        const SizedBox(height: 16),

                        // Actions Card
                        _buildActionsCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
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
                        _claim!.claimNumber,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _claim!.vendorName ?? 'Unknown Vendor',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow('Tarikh Tuntutan', DateFormat('dd MMMM yyyy', 'ms_MY').format(_claim!.claimDate)),
            if (_claim!.dueDate != null)
              _buildInfoRow('Tarikh Tempat', DateFormat('dd MMMM yyyy', 'ms_MY').format(_claim!.dueDate!)),
            if (_claim!.notes != null && _claim!.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nota:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _claim!.notes!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;
    IconData icon;

    switch (_claim!.status) {
      case ClaimStatus.draft:
        color = Colors.grey;
        label = 'Draf';
        icon = Icons.edit;
        break;
      case ClaimStatus.submitted:
        color = Colors.blue;
        label = 'Dihantar';
        icon = Icons.send;
        break;
      case ClaimStatus.approved:
        color = Colors.green;
        label = 'Diluluskan';
        icon = Icons.check_circle;
        break;
      case ClaimStatus.rejected:
        color = Colors.red;
        label = 'Ditolak';
        icon = Icons.cancel;
        break;
      case ClaimStatus.settled:
        color = AppColors.success;
        label = 'Selesai';
        icon = Icons.done_all;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Jumlah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Commission already deducted in delivery, so gross = net = claim amount
            _buildSummaryRow('Jumlah Tuntutan', _claim!.netAmount, isBold: true),
            // Only show commission info for backward compatibility with old claims
            if (_claim!.commissionAmount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nota: Komisyen sudah ditolak dalam invois penghantaran',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildSummaryRow('Telah Dibayar', _claim!.paidAmount),
            const Divider(),
            _buildSummaryRow(
              'Baki Tertunggak',
              _claim!.balanceAmount,
              isBold: true,
              isOutstanding: _claim!.balanceAmount > 0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, bool isDeduction = false, bool isOutstanding = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isOutstanding ? Colors.orange[900] : Colors.grey[700],
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}RM ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isOutstanding 
                  ? Colors.orange[900]
                  : isDeduction
                      ? Colors.red[700]
                      : isBold
                          ? Colors.blue[900]
                          : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Senarai Produk',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._claim!.items!.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.grey[50],
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
                              item.productName ?? 'Unknown Product',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (item.deliveryNumber != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.deliveryNumber!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Terjual: ${item.quantitySold.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'Harga Unit: RM ${item.unitPrice.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jumlah:',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            'RM ${item.grossAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tindakan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_claim!.balanceAmount > 0 && 
                (_claim!.status == ClaimStatus.approved || _claim!.status == ClaimStatus.submitted)) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      '/payments/record',
                      arguments: {
                        'vendorId': _claim!.vendorId,
                        'claimId': _claim!.id,
                      },
                    );
                    if (result == true) {
                      _loadClaim();
                    }
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Rekod Bayaran'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _generateAndSharePDF,
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share),
                    label: const Text('Kongsi PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingPdf ? null : _printPDF,
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    label: const Text('Cetak'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sejarah Bayaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_payments.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Belum ada bayaran direkodkan untuk tuntutan ini'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _payments.map((p) {
                  final date = DateTime.parse(p['payment_date'] as String);
                  final paymentNumber = p['payment_number'] as String? ?? '-';
                  final paymentMethod = p['payment_method'] as String? ?? '';
                  final paymentRef = p['payment_reference'] as String?;
                  final notes = p['notes'] as String?;
                  final allocated = (p['allocated_amount'] as num?)?.toDouble() ?? 0.0;
                  final total = (p['total_amount'] as num?)?.toDouble() ?? 0.0;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          paymentNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(date)),
                            Text('Kaedah: ${paymentMethod.replaceAll('_', ' ')}'),
                            Text('Jumlah Bayaran: RM ${total.toStringAsFixed(2)}'),
                            Text(
                              'Diperuntuk ke tuntutan ini: RM ${allocated.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (paymentRef != null && paymentRef.isNotEmpty)
                              Text('Rujukan: $paymentRef'),
                            if (notes != null && notes.isNotEmpty)
                              Text('Nota: $notes'),
                          ],
                        ),
                        leading: const Icon(Icons.payments),
                      ),
                      const Divider(),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

