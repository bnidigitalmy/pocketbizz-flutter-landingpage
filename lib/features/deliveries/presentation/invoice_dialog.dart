import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../../data/models/delivery.dart';
import '../../../data/repositories/business_profile_repository_supabase.dart';
import '../../../core/utils/delivery_invoice_pdf_generator.dart';
import '../../drive_sync/utils/drive_sync_helper.dart';
import '../../../core/services/document_storage_service.dart';

/// Invoice Dialog
/// Shows delivery invoice and allows PDF generation
class InvoiceDialog extends StatefulWidget {
  final Delivery delivery;
  final VoidCallback onClose;

  const InvoiceDialog({
    super.key,
    required this.delivery,
    required this.onClose,
  });

  @override
  State<InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<InvoiceDialog> {
  bool _isGeneratingPDF = false;
  final _businessProfileRepo = BusinessProfileRepository();

  Future<void> _downloadPdfWeb(Uint8List pdfBytes) async {
    final fileName =
        'invois-${widget.delivery.invoiceNumber ?? widget.delivery.id}.pdf';

    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  Future<void> _generatePDF(String format) async {
    setState(() => _isGeneratingPDF = true);
    try {
      // Load business profile
      final businessProfile = await _businessProfileRepo.getBusinessProfile();

      // Generate PDF
      final pdfBytes = await DeliveryInvoicePDFGenerator.generateDeliveryInvoice(
        widget.delivery,
        businessProfile: businessProfile,
        format: format,
      );

      if (kIsWeb) {
        // On web, use browser download instead of printing plugin
        await _downloadPdfWeb(pdfBytes);
      } else {
        // Mobile / desktop: use printing plugin
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
        );
      }

      // Auto-backup to Supabase Storage (non-blocking)
      final fileName = 'Invois_${widget.delivery.invoiceNumber ?? widget.delivery.id}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final documentType = format == 'thermal' ? 'thermal_invoice' : format == 'mini' ? 'receipt_a5' : 'invoice';
      
      DocumentStorageService.uploadDocumentSilently(
        pdfBytes: pdfBytes,
        fileName: fileName,
        documentType: documentType,
        relatedEntityType: 'delivery',
        relatedEntityId: widget.delivery.id,
        vendorName: widget.delivery.vendorName,
      );

      // Auto-sync to Google Drive (non-blocking, optional)
      final fileType = format == 'thermal' ? 'thermal_invoice' : format == 'mini' ? 'receipt_a5' : 'invoice';
      DriveSyncHelper.syncDocumentSilently(
        pdfData: pdfBytes,
        fileName: fileName,
        fileType: fileType,
        relatedEntityType: 'delivery',
        relatedEntityId: widget.delivery.id,
        vendorName: widget.delivery.vendorName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF berjaya dijana'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPDF = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pilih Cara Hantar Invois'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Penghantaran telah direkod. Pilih cara untuk hantar invois kepada vendor.',
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
                    'Vendor: ${widget.delivery.vendorName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tarikh: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(widget.delivery.deliveryDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jumlah: RM ${widget.delivery.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih format invois:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // PDF options
            OutlinedButton.icon(
              onPressed: _isGeneratingPDF ? null : () => _generatePDF('normal'),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Invois Standard (PDF)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isGeneratingPDF ? null : () => _generatePDF('mini'),
              icon: const Icon(Icons.receipt),
              label: const Text('Resit A5 (PDF)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isGeneratingPDF ? null : () => _generatePDF('thermal'),
              icon: const Icon(Icons.print),
              label: const Text('Thermal 58mm (PDF)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onClose();
            Navigator.pop(context);
          },
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

