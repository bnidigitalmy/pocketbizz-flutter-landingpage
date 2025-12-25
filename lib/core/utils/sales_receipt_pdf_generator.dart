import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/repositories/sales_repository_supabase.dart';
import '../../data/models/business_profile.dart';
import 'date_time_helper.dart';

/**
 * 🔒 POCKETBIZZ CORE ENGINE (STABLE)
 * ❌ DO NOT MODIFY
 * ❌ DO NOT REFACTOR
 * ❌ DO NOT OPTIMIZE
 * This logic is production-tested.
 * New features must EXTEND, not change.
 */
/// PDF Generator for Sales Receipts
class SalesReceiptPDFGenerator {
  /// Generate Sales Receipt PDF
  static Future<Uint8List> generateSalesReceipt(
    Sale sale, {
    BusinessProfile? businessProfile,
    String? receiptNumber,
  }) async {
    final pdf = pw.Document();
    
    // Generate receipt number if not provided (use first 8 chars of sale ID)
    final receiptNum = receiptNumber ?? sale.id.substring(0, 8).toUpperCase();
    
    // Convert sale date to local timezone
    final saleDate = DateTimeHelper.toLocalTime(sale.createdAt);
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm', 'ms_MY').format(saleDate);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header with Business Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessProfile?.businessName ?? 'Resit Jualan',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      if (businessProfile?.tagline != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          businessProfile!.tagline!,
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColors.grey700,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                      if (businessProfile?.address != null) ...[
                        pw.SizedBox(height: 8),
                        pw.Text(
                          businessProfile!.address!,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                      if (businessProfile?.phone != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Tel: ${businessProfile!.phone}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                      if (businessProfile?.email != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Email: ${businessProfile!.email}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                      if (businessProfile?.registrationNumber != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'No. Pendaftaran: ${businessProfile!.registrationNumber}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'RESIT JUALAN',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'No: #$receiptNum',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      dateStr,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 20),
            
            // Customer Info
            if (sale.customerName != null) ...[
              pw.Row(
                children: [
                  pw.Text(
                    'Pelanggan: ',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    sale.customerName!,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
            
            // Channel
            pw.Row(
              children: [
                pw.Text(
                  'Saluran: ',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  _getChannelLabel(sale.channel),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            
            // Delivery Address (for online and delivery channels)
            if ((sale.channel == 'online' || sale.channel == 'delivery') && 
                sale.deliveryAddress != null && 
                sale.deliveryAddress!.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Alamat Penghantaran: ',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      sale.deliveryAddress!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
            
            pw.SizedBox(height: 20),
            
            // Items Table
            if (sale.items != null && sale.items!.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('No', isHeader: true),
                      _buildTableCell('Produk', isHeader: true),
                      _buildTableCell('Kuantiti', isHeader: true),
                      _buildTableCell('Harga', isHeader: true),
                      _buildTableCell('Jumlah', isHeader: true),
                    ],
                  ),
                  // Item Rows
                  ...sale.items!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return pw.TableRow(
                      children: [
                        _buildTableCell('${index + 1}'),
                        _buildTableCell(item.productName),
                        _buildTableCell(item.quantity.toStringAsFixed(1)),
                        _buildTableCell('RM${item.unitPrice.toStringAsFixed(2)}'),
                        _buildTableCell('RM${item.subtotal.toStringAsFixed(2)}'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
            
            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Ringkasan',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildReceiptRow('Jumlah Awal', 'RM${sale.totalAmount.toStringAsFixed(2)}'),
                  if (sale.discountAmount != null && sale.discountAmount! > 0) ...[
                    pw.SizedBox(height: 8),
                    _buildReceiptRow(
                      'Diskaun',
                      '-RM${sale.discountAmount!.toStringAsFixed(2)}',
                      color: PdfColors.orange,
                    ),
                  ],
                  pw.Divider(),
                  _buildReceiptRow(
                    'Jumlah Akhir',
                    'RM${sale.finalAmount.toStringAsFixed(2)}',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            
            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Nota:',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      sale.notes!,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
            
            pw.SizedBox(height: 30),
            
            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Terima kasih atas pembelian anda!',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Sila simpan resit ini sebagai rekod pembelian.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Helper methods
  static pw.Widget _buildTableCell(String text, {bool isHeader = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildReceiptRow(
    String label,
    String value, {
    bool isHighlight = false,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: isHighlight ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isHighlight ? 16 : 12,
            fontWeight: pw.FontWeight.bold,
            color: color ?? (isHighlight ? PdfColors.green700 : null),
          ),
        ),
      ],
    );
  }

  static String _getChannelLabel(String channel) {
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
}

