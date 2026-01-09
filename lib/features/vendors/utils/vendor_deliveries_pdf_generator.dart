import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../../data/models/delivery.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/business_profile.dart';

/// PDF Generator for Vendor Deliveries Summary
class VendorDeliveriesPDFGenerator {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'ms_MY');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm', 'ms_MY');

  /// Generate Vendor Deliveries Summary PDF
  static Future<Uint8List> generateSummaryPDF({
    required Vendor vendor,
    required List<Delivery> deliveries,
    BusinessProfile? businessProfile,
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(
      locale: 'ms_MY',
      symbol: 'RM ',
      decimalDigits: 2,
    );

    // Calculate overall totals
    double totalAmount = 0.0;
    double totalDelivered = 0.0;
    double totalSold = 0.0;
    double totalRejected = 0.0;
    double totalExpired = 0.0;
    double totalDamaged = 0.0;
    double totalUnsold = 0.0;

    for (var delivery in deliveries) {
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          _buildHeader(vendor, businessProfile),
          pw.SizedBox(height: 20),

          // Executive Summary
          _buildExecutiveSummary(
            totalDeliveries: deliveries.length,
            totalAmount: totalAmount,
            totalDelivered: totalDelivered,
            totalSold: totalSold,
            totalUnsold: totalUnsold,
            totalRejected: totalRejected,
            totalExpired: totalExpired,
            totalDamaged: totalDamaged,
            currencyFormat: currencyFormat,
          ),
          pw.SizedBox(height: 20),

          // Deliveries List
          _buildDeliveriesSection(deliveries, currencyFormat),
          pw.SizedBox(height: 20),

          // Footer
          _buildFooter(),
        ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildHeader(Vendor vendor, BusinessProfile? businessProfile) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ringkasan Penghantaran Vendor',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          vendor.name,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        if (vendor.vendorNumber != null && vendor.vendorNumber!.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Nombor Vendor: ${vendor.vendorNumber}',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
        ],
        if (businessProfile != null) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            businessProfile.businessName,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          if (businessProfile.address != null && businessProfile.address!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              businessProfile.address!,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
          if (businessProfile.phone != null && businessProfile.phone!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Tel: ${businessProfile.phone}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          'Dijana pada: ${_dateTimeFormat.format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildExecutiveSummary({
    required int totalDeliveries,
    required double totalAmount,
    required double totalDelivered,
    required double totalSold,
    required double totalUnsold,
    required double totalRejected,
    required double totalExpired,
    required double totalDamaged,
    required NumberFormat currencyFormat,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Ringkasan Eksekutif',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _buildSummaryMetric('Jumlah Penghantaran', totalDeliveries.toString(), ''),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildSummaryMetric('Jumlah Nilai', currencyFormat.format(totalAmount), ''),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _buildSummaryMetric('Dihantar', totalDelivered.toStringAsFixed(0), ''),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildSummaryMetric('Terjual', totalSold.toStringAsFixed(0), ''),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _buildSummaryMetric('Tidak Terjual', totalUnsold.toStringAsFixed(0), ''),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildSummaryMetric('Ditolak', totalRejected.toStringAsFixed(0), ''),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _buildSummaryMetric('Luput', totalExpired.toStringAsFixed(0), ''),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildSummaryMetric('Rosak', totalDamaged.toStringAsFixed(0), ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryMetric(String label, String value, String unit) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$value$unit',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDeliveriesSection(List<Delivery> deliveries, NumberFormat currencyFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Senarai Penghantaran',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        ...deliveries.map((delivery) => _buildDeliveryCard(delivery, currencyFormat)),
      ],
    );
  }

  static pw.Widget _buildDeliveryCard(Delivery delivery, NumberFormat currencyFormat) {
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

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Delivery Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      delivery.invoiceNumber ?? 'Tanpa No. Invois',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarikh: ${_dateFormat.format(delivery.deliveryDate)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    currencyFormat.format(delivery.totalAmount),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: _getStatusColor(delivery.status),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      _getStatusLabel(delivery.status),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 12),

          // Summary Metrics
          pw.Text(
            'Ringkasan Kuantiti',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                children: [
                  _buildTableCell('Dihantar', isHeader: true),
                  _buildTableCell(totalDelivered.toStringAsFixed(0), isHeader: true),
                  _buildTableCell('Terjual', isHeader: true),
                  _buildTableCell(totalSold.toStringAsFixed(0), isHeader: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('Tidak Terjual', isHeader: false),
                  _buildTableCell(totalUnsold.toStringAsFixed(0), isHeader: false),
                  _buildTableCell('Ditolak', isHeader: false),
                  _buildTableCell(totalRejected.toStringAsFixed(0), isHeader: false),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('Luput', isHeader: false),
                  _buildTableCell(totalExpired.toStringAsFixed(0), isHeader: false),
                  _buildTableCell('Rosak', isHeader: false),
                  _buildTableCell(totalDamaged.toStringAsFixed(0), isHeader: false),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 12),

          // Items Table
          pw.Text(
            'Butiran Produk',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
            },
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Produk', isHeader: true),
                  _buildTableCell('Dihantar', isHeader: true),
                  _buildTableCell('Terjual', isHeader: true),
                  _buildTableCell('Tidak Terjual', isHeader: true),
                  _buildTableCell('Ditolak', isHeader: true),
                  _buildTableCell('Jumlah (RM)', isHeader: true),
                ],
              ),
              // Data Rows
              ...delivery.items.map((item) {
                return pw.TableRow(
                  children: [
                    _buildTableCell(item.productName, isHeader: false),
                    _buildTableCell(item.quantity.toStringAsFixed(0), isHeader: false),
                    _buildTableCell((item.quantitySold ?? 0.0).toStringAsFixed(0), isHeader: false),
                    _buildTableCell((item.quantityUnsold ?? 0.0).toStringAsFixed(0), isHeader: false),
                    _buildTableCell(item.rejectedQty.toStringAsFixed(0), isHeader: false),
                    _buildTableCell(currencyFormat.format(item.totalPrice), isHeader: false),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {required bool isHeader}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey900 : PdfColors.grey700,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        children: [
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Nota Penting:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Laporan ini dijana secara automatik oleh PocketBizz. Untuk tujuan perakaunan rasmi, sila rujuk dengan akauntan bertauliah.',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Laporan ini dijana oleh PocketBizz',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'www.pocketbizz.my',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return PdfColors.green;
      case 'pending':
        return PdfColors.orange;
      case 'claimed':
        return PdfColors.blue;
      case 'rejected':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  static String _getStatusLabel(String status) {
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
}
