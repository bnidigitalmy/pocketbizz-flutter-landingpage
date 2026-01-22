import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../../data/models/business_profile.dart';

/// PDF Generator for Vendor Detail Table
class VendorDetailPDFGenerator {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'ms_MY');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm', 'ms_MY');

  /// Generate Detailed Vendor Table PDF
  static Future<Uint8List> generateDetailPDF({
    required Map<String, dynamic> vendorData,
    BusinessProfile? businessProfile,
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat.currency(
      locale: 'ms_MY',
      symbol: 'RM ',
      decimalDigits: 2,
    );

    final vendor = vendorData['vendor'] as Map<String, dynamic>;
    final vendorName = vendor['name'] as String? ?? 'Vendor';
    final vendorNumber = vendor['vendor_number'] as String?;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        build: (context) => [
          // Header
          _buildHeader(vendorName, vendorNumber, businessProfile),
          pw.SizedBox(height: 10),

          // Summary
          _buildSummary(vendorData, currencyFormat),
          pw.SizedBox(height: 10),

          // Deliveries & Products Table
          _buildDeliveriesTable(vendorData, currencyFormat),
          pw.SizedBox(height: 10),

          // Claims Table
          _buildClaimsTable(vendorData, currencyFormat),
          pw.SizedBox(height: 10),

          // Payments Table
          _buildPaymentsTable(vendorData, currencyFormat),
          pw.SizedBox(height: 10),

          // Footer
          _buildFooter(),
        ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildHeader(String vendorName, String? vendorNumber, BusinessProfile? businessProfile) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Ringkasan Terperinci Vendor',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          vendorName,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        if (vendorNumber != null && vendorNumber.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'No. Vendor: $vendorNumber',
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey600,
            ),
          ),
        ],
        if (businessProfile != null) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            businessProfile.businessName,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          if (businessProfile.address != null && businessProfile.address!.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              businessProfile.address!,
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ],
        pw.SizedBox(height: 6),
        pw.Text(
          'Dijana pada: ${_dateTimeFormat.format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummary(Map<String, dynamic> vendorData, NumberFormat currencyFormat) {
    final deliveries = vendorData['deliveries'] as List<dynamic>? ?? [];
    final claims = vendorData['claims'] as List<dynamic>? ?? [];
    final payments = vendorData['payments'] as List<dynamic>? ?? [];

    // Calculate totals
    double totalDeliveryAmount = 0.0;
    double totalSold = 0.0;
    double totalExpired = 0.0;
    double totalCarryForward = 0.0; // From delivery items (unsold)
    double totalNetClaims = 0.0;
    double totalPaid = 0.0;
    double totalBalance = 0.0;
    
    // Calculate C/F items info
    final cfItems = vendorData['carry_forward_items'] as List<dynamic>? ?? [];
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

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border.all(color: PdfColors.blue200),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Table(
        columnWidths: {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            children: [
              _buildSummaryCell('Jumlah Penghantaran', deliveries.length.toString()),
              _buildSummaryCell('Jumlah Nilai Dihantar', currencyFormat.format(totalDeliveryAmount)),
              _buildSummaryCell('Jumlah Terjual', totalSold.toStringAsFixed(0)),
              _buildSummaryCell('Jumlah Luput', totalExpired.toStringAsFixed(0)),
              _buildSummaryCell('Belum Terjual', totalCarryForward.toStringAsFixed(0)),
            ],
          ),
          pw.TableRow(
            children: [
              _buildSummaryCell('C/F Available', '${totalAvailableCF.toStringAsFixed(0)} ($availableCFCount)'),
              _buildSummaryCell('C/F Used', '${totalUsedCF.toStringAsFixed(0)} ($usedCFCount)'),
              _buildSummaryCell('Jumlah Tuntutan', currencyFormat.format(totalNetClaims)),
              _buildSummaryCell('Jumlah Dibayar', currencyFormat.format(totalPaid)),
              _buildSummaryCell('Baki Tertunggak', currencyFormat.format(totalBalance), isBalance: true),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCell(String label, String value, {bool isBalance = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
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

  static pw.Widget _buildDeliveriesTable(Map<String, dynamic> vendorData, NumberFormat currencyFormat) {
    final deliveries = vendorData['deliveries'] as List<dynamic>? ?? [];

    if (deliveries.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        child: pw.Text(
          'Tiada penghantaran',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Penghantaran & Produk',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(0.8),
            4: const pw.FlexColumnWidth(0.8),
            5: const pw.FlexColumnWidth(0.8),
            6: const pw.FlexColumnWidth(0.8),
            7: const pw.FlexColumnWidth(0.8),
            8: const pw.FlexColumnWidth(1),
            9: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Tarikh', isHeader: true),
                _buildTableCell('No. Invois', isHeader: true),
                _buildTableCell('Produk', isHeader: true),
                _buildTableCell('Dihantar', isHeader: true),
                _buildTableCell('Terjual', isHeader: true),
                _buildTableCell('Luput', isHeader: true),
                _buildTableCell('Carry Forward', isHeader: true),
                _buildTableCell('Ditolak', isHeader: true),
                _buildTableCell('Harga Unit', isHeader: true),
                _buildTableCell('Jumlah (RM)', isHeader: true),
              ],
            ),
            // Data rows
            ..._buildDeliveryTableRows(deliveries, currencyFormat),
          ],
        ),
      ],
    );
  }

  static List<pw.TableRow> _buildDeliveryTableRows(List<dynamic> deliveries, NumberFormat currencyFormat) {
    final List<pw.TableRow> rows = [];

    // Calculate totals
    double totalDelivered = 0.0;
    double totalSold = 0.0;
    double totalExpired = 0.0;
    double totalUnsold = 0.0;
    double totalRejected = 0.0;
    double totalAmount = 0.0;

    for (var delivery in deliveries) {
      final deliveryDate = delivery['delivery_date'] as String?;
      final invoiceNumber = delivery['invoice_number'] as String?;
      final items = delivery['vendor_delivery_items'] as List<dynamic>? ?? [];

      if (items.isEmpty) {
        rows.add(pw.TableRow(
          children: [
            _buildTableCell(_formatDate(deliveryDate), isHeader: false),
            _buildTableCell(invoiceNumber ?? '-', isHeader: false),
            _buildTableCell('-', isHeader: false),
            _buildTableCell('-', isHeader: false),
            _buildTableCell('-', isHeader: false),
            _buildTableCell('-', isHeader: false),
            _buildTableCell('-', isHeader: false),
            _buildTableCell('-', isHeader: false),
            _buildTableCell('-', isHeader: false),
            _buildTableCell('-', isHeader: false),
          ],
        ));
      } else {
        for (var item in items) {
          final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          final quantitySold = (item['quantity_sold'] as num?)?.toDouble() ?? 0.0;
          final quantityExpired = (item['quantity_expired'] as num?)?.toDouble() ?? 0.0;
          final quantityUnsold = (item['quantity_unsold'] as num?)?.toDouble() ?? 0.0;
          final rejectedQty = (item['rejected_qty'] as num?)?.toDouble() ?? 0.0;
          final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;

          totalDelivered += quantity;
          totalSold += quantitySold;
          totalExpired += quantityExpired;
          totalUnsold += quantityUnsold;
          totalRejected += rejectedQty;
          totalAmount += totalPrice;

          rows.add(pw.TableRow(
            children: [
              _buildTableCell(_formatDate(deliveryDate), isHeader: false),
              _buildTableCell(invoiceNumber ?? '-', isHeader: false),
              _buildTableCell(item['product_name'] ?? '-', isHeader: false),
              _buildTableCell(quantity.toStringAsFixed(0), isHeader: false),
              _buildTableCell(quantitySold.toStringAsFixed(0), isHeader: false),
              _buildTableCell(quantityExpired.toStringAsFixed(0), isHeader: false),
              _buildTableCell(quantityUnsold.toStringAsFixed(0), isHeader: false),
              _buildTableCell(rejectedQty.toStringAsFixed(0), isHeader: false),
              _buildTableCell(currencyFormat.format((item['unit_price'] as num?)?.toDouble() ?? 0.0), isHeader: false),
              _buildTableCell(currencyFormat.format(totalPrice), isHeader: false),
            ],
          ));
        }
      }
    }

    // Add total row
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _buildTableCell('JUMLAH', isHeader: true),
          _buildTableCell('', isHeader: false),
          _buildTableCell('', isHeader: false),
          _buildTableCell(totalDelivered.toStringAsFixed(0), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(totalSold.toStringAsFixed(0), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(totalExpired.toStringAsFixed(0), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(totalUnsold.toStringAsFixed(0), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(totalRejected.toStringAsFixed(0), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell('', isHeader: false),
          _buildTableCell(currencyFormat.format(totalAmount), isHeader: true, fontWeight: pw.FontWeight.bold),
        ],
      ),
    );

    return rows;
  }

  static pw.Widget _buildClaimsTable(Map<String, dynamic> vendorData, NumberFormat currencyFormat) {
    final claims = vendorData['claims'] as List<dynamic>? ?? [];

    if (claims.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        child: pw.Text(
          'Tiada tuntutan',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Tuntutan',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1),
            6: const pw.FlexColumnWidth(1),
            7: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('No. Tuntutan', isHeader: true),
                _buildTableCell('Tarikh', isHeader: true),
                _buildTableCell('Status', isHeader: true),
                _buildTableCell('Jumlah Kasar', isHeader: true),
                _buildTableCell('Komisyen', isHeader: true),
                _buildTableCell('Jumlah Bersih', isHeader: true),
                _buildTableCell('Dibayar', isHeader: true),
                _buildTableCell('Baki', isHeader: true),
              ],
            ),
            // Data rows
            ..._buildClaimTableRows(claims, currencyFormat),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentsTable(Map<String, dynamic> vendorData, NumberFormat currencyFormat) {
    final payments = vendorData['payments'] as List<dynamic>? ?? [];

    if (payments.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        child: pw.Text(
          'Tiada bayaran',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Bayaran',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Tarikh', isHeader: true),
                _buildTableCell('Kaedah', isHeader: true),
                _buildTableCell('Rujukan', isHeader: true),
                _buildTableCell('Jumlah (RM)', isHeader: true),
              ],
            ),
            // Data rows
            ..._buildPaymentTableRows(payments, currencyFormat),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    required bool isHeader,
    PdfColor? textColor,
    pw.FontWeight? fontWeight,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 6.5 : 6,
          fontWeight: fontWeight ?? (isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
          color: textColor ?? (isHeader ? PdfColors.grey900 : PdfColors.grey700),
        ),
        textAlign: pw.TextAlign.center,
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
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

  static String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return _dateFormat.format(date);
    } catch (e) {
      return dateString;
    }
  }

  static String _formatStatus(String status) {
    switch (status) {
      case 'draft':
        return 'Draf';
      case 'submitted':
        return 'Dihantar';
      case 'approved':
        return 'Diluluskan';
      case 'rejected':
        return 'Ditolak';
      case 'settled':
        return 'Selesai';
      default:
        return status;
    }
  }

  static String _formatPaymentMethod(String? method) {
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

  static List<pw.TableRow> _buildClaimTableRows(List<dynamic> claims, NumberFormat currencyFormat) {
    final List<pw.TableRow> rows = [];

    // Calculate totals
    double totalGross = 0.0;
    double totalCommission = 0.0;
    double totalNet = 0.0;
    double totalPaid = 0.0;
    double totalBalance = 0.0;

    for (var claim in claims) {
      final status = claim['status'] as String? ?? 'draft';
      final gross = (claim['gross_amount'] as num?)?.toDouble() ?? 0.0;
      final commission = (claim['commission_amount'] as num?)?.toDouble() ?? 0.0;
      final net = (claim['net_amount'] as num?)?.toDouble() ?? 0.0;
      final paid = (claim['paid_amount'] as num?)?.toDouble() ?? 0.0;
      final balance = (claim['balance_amount'] as num?)?.toDouble() ?? 0.0;

      totalGross += gross;
      totalCommission += commission;
      totalNet += net;
      totalPaid += paid;
      totalBalance += balance;

      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell(claim['claim_number'] ?? '-', isHeader: false),
            _buildTableCell(_formatDate(claim['claim_date']), isHeader: false),
            _buildTableCell(_formatStatus(status), isHeader: false),
            _buildTableCell(currencyFormat.format(gross), isHeader: false),
            _buildTableCell(currencyFormat.format(commission), isHeader: false),
            _buildTableCell(currencyFormat.format(net), isHeader: false),
            _buildTableCell(currencyFormat.format(paid), isHeader: false),
            _buildTableCell(
              currencyFormat.format(balance),
              isHeader: false,
              textColor: balance > 0 ? PdfColors.red700 : PdfColors.green700,
              fontWeight: pw.FontWeight.bold,
            ),
          ],
        ),
      );
    }

    // Add total row
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _buildTableCell('JUMLAH', isHeader: true),
          _buildTableCell('', isHeader: false),
          _buildTableCell('', isHeader: false),
          _buildTableCell(currencyFormat.format(totalGross), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(currencyFormat.format(totalCommission), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(currencyFormat.format(totalNet), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(currencyFormat.format(totalPaid), isHeader: true, fontWeight: pw.FontWeight.bold),
          _buildTableCell(
            currencyFormat.format(totalBalance),
            isHeader: true,
            textColor: totalBalance > 0 ? PdfColors.red700 : PdfColors.green700,
            fontWeight: pw.FontWeight.bold,
          ),
        ],
      ),
    );

    return rows;
  }

  static List<pw.TableRow> _buildPaymentTableRows(List<dynamic> payments, NumberFormat currencyFormat) {
    final List<pw.TableRow> rows = [];

    // Calculate total
    double totalAmount = 0.0;

    for (var payment in payments) {
      final amount = (payment['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalAmount += amount;

      rows.add(
        pw.TableRow(
          children: [
            _buildTableCell(_formatDate(payment['payment_date']), isHeader: false),
            _buildTableCell(_formatPaymentMethod(payment['payment_method']), isHeader: false),
            _buildTableCell(payment['payment_reference'] ?? '-', isHeader: false),
            _buildTableCell(
              currencyFormat.format(amount),
              isHeader: false,
              textColor: PdfColors.green700,
              fontWeight: pw.FontWeight.bold,
            ),
          ],
        ),
      );
    }

    // Add total row
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _buildTableCell('JUMLAH', isHeader: true),
          _buildTableCell('', isHeader: false),
          _buildTableCell('', isHeader: false),
          _buildTableCell(
            currencyFormat.format(totalAmount),
            isHeader: true,
            textColor: PdfColors.green700,
            fontWeight: pw.FontWeight.bold,
          ),
        ],
      ),
    );

    return rows;
  }
}
