import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/models/delivery.dart';
import '../../data/models/business_profile.dart';

/// PDF Generator for Delivery Invoices
/// Supports 3 formats: Standard (A4), A5 Receipt, Thermal 58mm
class DeliveryInvoicePDFGenerator {
  /// Generate PDF Invoice for Delivery
  /// 
  /// [format] can be: 'standard', 'a5', or 'thermal'
  static Future<Uint8List> generateDeliveryInvoice(
    Delivery delivery, {
    BusinessProfile? businessProfile,
    String format = 'standard',
  }) async {
    switch (format.toLowerCase()) {
      case 'a5':
      case 'mini':
        return _generateA5Invoice(delivery, businessProfile);
      case 'thermal':
        return _generateThermalInvoice(delivery, businessProfile);
      case 'standard':
      case 'normal':
      default:
        return _generateStandardInvoice(delivery, businessProfile);
    }
  }

  /// Generate Standard A4 Invoice
  static Future<Uint8List> _generateStandardInvoice(
    Delivery delivery,
    BusinessProfile? businessProfile,
  ) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.now());
    final deliveryDate = DateFormat('dd MMMM yyyy', 'ms_MY').format(delivery.deliveryDate);

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
                        businessProfile?.businessName ?? 'Invois Penghantaran',
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
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blueGrey800,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'INVOIS PENGHANTARAN',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            delivery.invoiceNumber ?? 'N/A',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: pw.BoxDecoration(
                        color: _getStatusColor(delivery.status),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        _getStatusLabel(delivery.status),
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Delivery Details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Tarikh Invoice: $date',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarikh Penghantaran: $deliveryDate',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Vendor Details
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'VENDOR:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    delivery.vendorName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Items Table
            if (delivery.items.isNotEmpty) ...[
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.5),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.0),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('No', isHeader: true),
                      _buildTableCell('Produk', isHeader: true),
                      _buildTableCell('Kuantiti', isHeader: true),
                      _buildTableCell('Harga (RM)', isHeader: true),
                      _buildTableCell('Jumlah (RM)', isHeader: true),
                    ],
                  ),
                  // Item Rows
                  ...delivery.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final acceptedQty = item.quantity - item.rejectedQty;

                    return pw.TableRow(
                      children: [
                        _buildTableCell('${index + 1}'),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.productName,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                              if (item.rejectedQty > 0) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Ditolak: ${item.rejectedQty.toStringAsFixed(1)} (${item.rejectionReason ?? 'Tiada sebab'})',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.red700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _buildTableCell(acceptedQty.toStringAsFixed(1)),
                        _buildTableCell(item.unitPrice.toStringAsFixed(2)),
                        // Calculate total based on accepted quantity (not stored totalPrice which might be wrong)
                        _buildTableCell((acceptedQty * item.unitPrice).toStringAsFixed(2)),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'JUMLAH:',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            // Recalculate total based on accepted quantities
                            'RM${delivery.items.fold<double>(0.0, (sum, item) {
                              final acceptedQty = item.quantity - item.rejectedQty;
                              return sum + (acceptedQty * item.unitPrice);
                            }).toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            pw.SizedBox(height: 24),

            // Payment Details
            if (businessProfile?.accountNumber != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MAKLUMAT PEMBAYARAN:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    if (businessProfile!.bankName != null)
                      pw.Text(
                        'Bank: ${businessProfile.bankName}',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    pw.Text(
                      'No. Akaun: ${businessProfile.accountNumber}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      'Nama: ${businessProfile.accountName ?? businessProfile.businessName}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Notes
            if (delivery.notes != null && delivery.notes!.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Nota:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      delivery.notes!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
            ],

            // Footer
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Terima kasih!',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate A5 Receipt Format
  static Future<Uint8List> _generateA5Invoice(
    Delivery delivery,
    BusinessProfile? businessProfile,
  ) async {
    final pdf = pw.Document();
    final deliveryDate = DateFormat('dd MMMM yyyy', 'ms_MY').format(delivery.deliveryDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessProfile?.businessName ?? 'INVOIS PENGHANTARAN',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      delivery.invoiceNumber ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 12),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Vendor
              pw.Text(
                'Vendor: ${delivery.vendorName}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Tarikh: $deliveryDate',
                style: const pw.TextStyle(fontSize: 10),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Items
              ...delivery.items.map((item) {
                final acceptedQty = item.quantity - item.rejectedQty;
                final lineTotal = acceptedQty * item.unitPrice;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.Text(
                            'RM${lineTotal.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.Text(
                        '${acceptedQty.toStringAsFixed(1)} x RM${item.unitPrice.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                      if (item.rejectedQty > 0)
                        pw.Text(
                          'Ditolak: ${item.rejectedQty.toStringAsFixed(1)}',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.red700),
                        ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'JUMLAH:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    // Recalculate total based on accepted quantities
                    'RM${delivery.items.fold<double>(0.0, (sum, item) {
                      final acceptedQty = item.quantity - item.rejectedQty;
                      return sum + (acceptedQty * item.unitPrice);
                    }).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Divider(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Terima kasih!',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Thermal 58mm Format
  static Future<Uint8List> _generateThermalInvoice(
    Delivery delivery,
    BusinessProfile? businessProfile,
  ) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final deliveryDate = DateFormat('dd/MM/yyyy').format(delivery.deliveryDate);
    
    // Thermal printer width: 58mm = ~219 points at 72 DPI
    const thermalWidth = 219.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(thermalWidth, double.infinity, marginAll: 5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessProfile?.businessName ?? 'INVOIS',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      delivery.invoiceNumber ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Vendor
              pw.Text(
                'Vendor: ${delivery.vendorName}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Tarikh: $deliveryDate',
                style: const pw.TextStyle(fontSize: 7),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Items
              ...delivery.items.map((item) {
                final acceptedQty = item.quantity - item.rejectedQty;
                final lineTotal = acceptedQty * item.unitPrice;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.productName,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${acceptedQty.toStringAsFixed(1)} x RM${item.unitPrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                          pw.Text(
                            'RM${lineTotal.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      if (item.rejectedQty > 0)
                        pw.Text(
                          'Ditolak: ${item.rejectedQty.toStringAsFixed(1)}',
                          style: pw.TextStyle(fontSize: 6, color: PdfColors.red700),
                        ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'JUMLAH:',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    // Recalculate total based on accepted quantities
                    'RM${delivery.items.fold<double>(0.0, (sum, item) {
                      final acceptedQty = item.quantity - item.rejectedQty;
                      return sum + (acceptedQty * item.unitPrice);
                    }).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Divider(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Terima kasih!',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    double fontSize = 11,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blueGrey800 : PdfColors.black,
        ),
      ),
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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
    switch (status.toLowerCase()) {
      case 'delivered':
        return 'DIHANTAR';
      case 'pending':
        return 'MENUNGGU';
      case 'claimed':
        return 'DITUNTUT';
      case 'rejected':
        return 'DITOLAK';
      default:
        return status.toUpperCase();
    }
  }
}

