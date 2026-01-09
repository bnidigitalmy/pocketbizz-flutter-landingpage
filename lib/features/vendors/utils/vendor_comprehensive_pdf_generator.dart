import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../../data/models/business_profile.dart';

/// PDF Generator for Vendor Comprehensive Table
class VendorComprehensivePDFGenerator {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'ms_MY');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm', 'ms_MY');

  /// Generate Comprehensive Vendor Table PDF
  static Future<Uint8List> generateTablePDF({
    required List<Map<String, dynamic>> vendorData,
    BusinessProfile? businessProfile,
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(
      locale: 'ms_MY',
      symbol: 'RM ',
      decimalDigits: 2,
    );

    // Calculate totals
    double totalDeliveryAmount = 0.0;
    int totalDeliveries = 0;
    int totalClaims = 0;
    double totalNetAmount = 0.0;
    double totalCommission = 0.0;
    double totalPaidFromClaims = 0.0;
    int totalPayments = 0;
    double totalPaymentAmount = 0.0;
    double totalBalance = 0.0;

    for (var vendor in vendorData) {
      totalDeliveries += vendor['total_deliveries'] as int? ?? 0;
      totalDeliveryAmount += (vendor['total_delivery_amount'] as num?)?.toDouble() ?? 0.0;
      totalClaims += vendor['total_claims'] as int? ?? 0;
      totalNetAmount += (vendor['total_net_amount'] as num?)?.toDouble() ?? 0.0;
      totalCommission += (vendor['total_commission'] as num?)?.toDouble() ?? 0.0;
      totalPaidFromClaims += (vendor['total_paid_from_claims'] as num?)?.toDouble() ?? 0.0;
      totalPayments += vendor['total_payments'] as int? ?? 0;
      totalPaymentAmount += (vendor['total_payment_amount'] as num?)?.toDouble() ?? 0.0;
      totalBalance += (vendor['total_balance'] as num?)?.toDouble() ?? 0.0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => [
          // Header
          _buildHeader(businessProfile, currencyFormat),
          pw.SizedBox(height: 20),

          // Summary
          _buildSummary(
            totalVendors: vendorData.length,
            totalDeliveries: totalDeliveries,
            totalDeliveryAmount: totalDeliveryAmount,
            totalClaims: totalClaims,
            totalNetAmount: totalNetAmount,
            totalCommission: totalCommission,
            totalPaidFromClaims: totalPaidFromClaims,
            totalPayments: totalPayments,
            totalPaymentAmount: totalPaymentAmount,
            totalBalance: totalBalance,
            currencyFormat: currencyFormat,
          ),
          pw.SizedBox(height: 20),

          // Table
          _buildTable(vendorData, currencyFormat),
          pw.SizedBox(height: 20),

          // Footer
          _buildFooter(),
        ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildHeader(BusinessProfile? businessProfile, NumberFormat currencyFormat) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ringkasan Vendor - Jadual Lengkap',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        if (businessProfile != null) ...[
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
            fontSize: 9,
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummary({
    required int totalVendors,
    required int totalDeliveries,
    required double totalDeliveryAmount,
    required int totalClaims,
    required double totalNetAmount,
    required double totalCommission,
    required double totalPaidFromClaims,
    required int totalPayments,
    required double totalPaymentAmount,
    required double totalBalance,
    required NumberFormat currencyFormat,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            children: [
              _buildSummaryCell('Jumlah Vendor', totalVendors.toString(), true),
              _buildSummaryCell('Jumlah Penghantaran', totalDeliveries.toString(), true),
              _buildSummaryCell('Jumlah Nilai Penghantaran', currencyFormat.format(totalDeliveryAmount), true),
              _buildSummaryCell('Jumlah Tuntutan', totalClaims.toString(), true),
              _buildSummaryCell('Jumlah Tuntutan (Bersih)', currencyFormat.format(totalNetAmount), true),
            ],
          ),
          pw.TableRow(
            children: [
              _buildSummaryCell('Jumlah Komisyen', currencyFormat.format(totalCommission), false),
              _buildSummaryCell('Dibayar (Tuntutan)', currencyFormat.format(totalPaidFromClaims), false),
              _buildSummaryCell('Jumlah Bayaran', totalPayments.toString(), false),
              _buildSummaryCell('Jumlah Bayaran (Total)', currencyFormat.format(totalPaymentAmount), false),
              _buildSummaryCell('Baki Tertunggak', currencyFormat.format(totalBalance), false, isBalance: true),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCell(String label, String value, bool isHeader, {bool isBalance = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: isBalance 
                  ? (double.tryParse(value.replaceAll('RM ', '').replaceAll(',', '')) ?? 0.0) > 0
                      ? PdfColors.red700
                      : PdfColors.green700
                  : PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTable(List<Map<String, dynamic>> vendorData, NumberFormat currencyFormat) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),  // Vendor Name
        1: const pw.FlexColumnWidth(1),  // No. Vendor
        2: const pw.FlexColumnWidth(1),  // Jumlah Penghantaran
        3: const pw.FlexColumnWidth(1.2), // Jumlah Nilai Penghantaran
        4: const pw.FlexColumnWidth(1),  // Jumlah Tuntutan
        5: const pw.FlexColumnWidth(1.2), // Jumlah Tuntutan (Bersih)
        6: const pw.FlexColumnWidth(1.1), // Jumlah Komisyen
        7: const pw.FlexColumnWidth(1.2), // Dibayar (Tuntutan)
        8: const pw.FlexColumnWidth(1),  // Jumlah Bayaran
        9: const pw.FlexColumnWidth(1.2), // Jumlah Bayaran (Total)
        10: const pw.FlexColumnWidth(1.2), // Baki Tertunggak
        11: const pw.FlexColumnWidth(0.8), // Status
      },
      children: [
          // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell('Vendor', isHeader: true, alignment: pw.Alignment.centerLeft),
            _buildTableCell('No. Vendor', isHeader: true, alignment: pw.Alignment.center),
            _buildTableCell('Jumlah\nPenghantaran', isHeader: true, alignment: pw.Alignment.center),
            _buildTableCell('Jumlah Nilai\nPenghantaran', isHeader: true, alignment: pw.Alignment.centerRight),
            _buildTableCell('Jumlah\nTuntutan', isHeader: true, alignment: pw.Alignment.center),
            _buildTableCell('Jumlah Tuntutan\n(Bersih)', isHeader: true, alignment: pw.Alignment.centerRight),
            _buildTableCell('Jumlah\nKomisyen', isHeader: true, alignment: pw.Alignment.centerRight),
            _buildTableCell('Dibayar\n(Tuntutan)', isHeader: true, alignment: pw.Alignment.centerRight),
            _buildTableCell('Jumlah\nBayaran', isHeader: true, alignment: pw.Alignment.center),
            _buildTableCell('Jumlah Bayaran\n(Total)', isHeader: true, alignment: pw.Alignment.centerRight),
            _buildTableCell('Baki\nTertunggak', isHeader: true, alignment: pw.Alignment.centerRight),
            _buildTableCell('Status', isHeader: true, alignment: pw.Alignment.center),
          ],
        ),
        // Data Rows
        ...vendorData.map((vendor) {
          final isActive = vendor['is_active'] as bool? ?? true;
          final totalBalance = (vendor['total_balance'] as num?)?.toDouble() ?? 0.0;
          
          return pw.TableRow(
            children: [
              _buildTableCell(
                '${vendor['vendor_name'] ?? '-'}\n${vendor['phone'] != null ? "Tel: ${vendor['phone']}" : ""}',
                isHeader: false,
                alignment: pw.Alignment.centerLeft,
              ),
              _buildTableCell(vendor['vendor_number'] ?? '-', isHeader: false, alignment: pw.Alignment.center),
              _buildTableCell('${vendor['total_deliveries'] ?? 0}', isHeader: false, alignment: pw.Alignment.center),
              _buildTableCell(
                currencyFormat.format((vendor['total_delivery_amount'] as num?)?.toDouble() ?? 0.0),
                isHeader: false,
                alignment: pw.Alignment.centerRight,
              ),
              _buildTableCell('${vendor['total_claims'] ?? 0}', isHeader: false, alignment: pw.Alignment.center),
              _buildTableCell(
                currencyFormat.format((vendor['total_net_amount'] as num?)?.toDouble() ?? 0.0),
                isHeader: false,
                alignment: pw.Alignment.centerRight,
              ),
              _buildTableCell(
                currencyFormat.format((vendor['total_commission'] as num?)?.toDouble() ?? 0.0),
                isHeader: false,
                alignment: pw.Alignment.centerRight,
              ),
              _buildTableCell(
                currencyFormat.format((vendor['total_paid_from_claims'] as num?)?.toDouble() ?? 0.0),
                isHeader: false,
                alignment: pw.Alignment.centerRight,
              ),
              _buildTableCell('${vendor['total_payments'] ?? 0}', isHeader: false, alignment: pw.Alignment.center),
              _buildTableCell(
                currencyFormat.format((vendor['total_payment_amount'] as num?)?.toDouble() ?? 0.0),
                isHeader: false,
                alignment: pw.Alignment.centerRight,
              ),
              _buildTableCell(
                currencyFormat.format(totalBalance),
                isHeader: false,
                alignment: pw.Alignment.centerRight,
                textColor: totalBalance > 0 ? PdfColors.red700 : PdfColors.green700,
                fontWeight: pw.FontWeight.bold,
              ),
              _buildTableCell(
                isActive ? 'Aktif' : 'Tidak Aktif',
                isHeader: false,
                alignment: pw.Alignment.center,
                textColor: isActive ? PdfColors.green700 : PdfColors.grey700,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    required bool isHeader,
    pw.Alignment? alignment,
    PdfColor? textColor,
    pw.FontWeight? fontWeight,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: alignment ?? pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: fontWeight ?? (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
          color: textColor ?? (isHeader ? PdfColors.grey900 : PdfColors.grey700),
        ),
        textAlign: alignment == pw.Alignment.centerLeft
            ? pw.TextAlign.left
            : alignment == pw.Alignment.centerRight
                ? pw.TextAlign.right
                : pw.TextAlign.center,
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
}
