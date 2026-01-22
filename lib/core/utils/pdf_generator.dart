import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/purchase_order.dart';

// Data Models for PDF Generation - MUST BE OUTSIDE THE CLASS
class ClaimItem {
  final String productName;
  final double quantitySold;
  final double unitPrice;
  final double grossAmount;
  final double commissionAmount;
  final double netAmount;
  final String? deliveryNumber; // Invoice number from delivery
  final bool isCarryForward; // Whether this is a carry forward item

  ClaimItem({
    required this.productName,
    required this.quantitySold,
    required this.unitPrice,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    this.deliveryNumber,
    this.isCarryForward = false,
  });
}

class DeliveryItem {
  final String productName;
  final double quantity;
  final double unitPrice;
  final double totalPrice;

  DeliveryItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
}

class PaymentAllocation {
  final String claimNumber;
  final double amount;

  PaymentAllocation({
    required this.claimNumber,
    required this.amount,
  });
}

/// PDF Generator for PocketBizz Documents
/// Supports: Claims, Payments, Invoices, Delivery Notes
class PDFGenerator {
  static final DateFormat _dateFormat = DateFormat('dd MMMM yyyy', 'ms_MY');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm', 'ms_MY');

  /// Generate Claim Invoice PDF
  static Future<Uint8List> generateClaimInvoice({
    required String claimNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime claimDate,
    required double grossAmount,
    required double commissionRate,
    required double commissionAmount,
    required double netAmount,
    required double paidAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? commissionType, // 'percentage' or 'price_range'
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'INVOIS TUNTUTAN',
              documentNumber: claimNumber,
              date: claimDate,
              businessName: businessName ?? 'PocketBizz',
              businessAddress: businessAddress,
              businessPhone: businessPhone,
            ),
            pw.SizedBox(height: 20),
            _buildVendorInfo(vendorName: vendorName, vendorPhone: vendorPhone),
            pw.SizedBox(height: 20),
            _buildItemsTable(items: items),
            pw.SizedBox(height: 20),
            _buildSummary(
              grossAmount: grossAmount,
              commissionRate: commissionRate,
              commissionAmount: commissionAmount,
              netAmount: netAmount,
              paidAmount: paidAmount,
              balanceAmount: balanceAmount,
              commissionType: commissionType,
            ),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildNotes(notes),
            ],
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Payment Receipt PDF
  static Future<Uint8List> generatePaymentReceipt({
    required String paymentNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime paymentDate,
    required String paymentMethod,
    required double totalAmount,
    required String? paymentReference,
    required List<PaymentAllocation> allocations,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'RESIT BAYARAN',
              documentNumber: paymentNumber,
              date: paymentDate,
              businessName: businessName ?? 'PocketBizz',
              businessAddress: businessAddress,
              businessPhone: businessPhone,
            ),
            pw.SizedBox(height: 20),
            _buildVendorInfo(vendorName: vendorName, vendorPhone: vendorPhone),
            pw.SizedBox(height: 20),
            _buildPaymentDetails(
              paymentMethod: paymentMethod,
              paymentReference: paymentReference,
              totalAmount: totalAmount,
            ),
            pw.SizedBox(height: 20),
            if (allocations.isNotEmpty) _buildAllocationsTable(allocations: allocations),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildNotes(notes),
            ],
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Delivery Note PDF
  static Future<Uint8List> generateDeliveryNote({
    required String deliveryNumber,
    required String vendorName,
    required String vendorPhone,
    required DateTime deliveryDate,
    required double totalAmount,
    required List<DeliveryItem> items,
    String? notes,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'NOTA PENGHANTARAN',
              documentNumber: deliveryNumber,
              date: deliveryDate,
              businessName: businessName ?? 'PocketBizz',
              businessAddress: businessAddress,
              businessPhone: businessPhone,
            ),
            pw.SizedBox(height: 20),
            _buildVendorInfo(vendorName: vendorName, vendorPhone: vendorPhone),
            pw.SizedBox(height: 20),
            _buildDeliveryItemsTable(items: items),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'JUMLAH: RM ${totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              _buildNotes(notes),
            ],
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Thermal PDF (80mm width for thermal printers)
  static Future<Uint8List> generateThermalClaim({
    required String claimNumber,
    required String vendorName,
    required DateTime claimDate,
    required double netAmount,
    required double balanceAmount,
    required List<ClaimItem> items,
    String? businessName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                businessName ?? 'POCKETBIZZ',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'INVOIS TUNTUTAN',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(claimNumber, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tarikh:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(_dateFormat.format(claimDate), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Vendor:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Expanded(
                    child: pw.Text(
                      vendorName,
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item.productName,
                        style: const pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${item.quantitySold.toStringAsFixed(1)}x RM ${item.unitPrice.toStringAsFixed(2)} = RM ${item.netAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Jumlah:',
                    style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'RM ${netAmount.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Baki:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('RM ${balanceAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Terima kasih!',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Purchase Order PDF (for suppliers)
  static Future<Uint8List> generatePOPDF(
    PurchaseOrder po, {
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'PURCHASE ORDER',
              documentNumber: po.poNumber,
              date: po.createdAt,
              businessName: businessName ?? 'PocketBizz',
              businessAddress: businessAddress,
              businessPhone: businessPhone,
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Kepada:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(po.supplierName, style: const pw.TextStyle(fontSize: 12)),
                  if (po.supplierPhone != null && po.supplierPhone!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Tel: ${po.supplierPhone}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                  if (po.supplierEmail != null && po.supplierEmail!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text('Email: ${po.supplierEmail}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                  if (po.supplierAddress != null && po.supplierAddress!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(po.supplierAddress!, style: const pw.TextStyle(fontSize: 10)),
                  ],
                  if (po.deliveryAddress != null && po.deliveryAddress!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Alamat Penghantaran:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(po.deliveryAddress!, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.5),
                1: pw.FlexColumnWidth(3.5),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1.5),
                4: pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableCell('#', isHeader: true),
                    _tableCell('Item', isHeader: true),
                    _tableCell('Qty', isHeader: true),
                    _tableCell('Harga Anggaran', isHeader: true),
                    _tableCell('Jumlah', isHeader: true),
                  ],
                ),
                ...po.items.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final item = entry.value;
                  final estPrice = item.estimatedPrice ?? item.actualPrice ?? 0;
                  final total = item.calculateTotal(); // Use correct calculation with package size
                  return pw.TableRow(
                    children: [
                      _tableCell(index.toString(), alignment: pw.Alignment.center),
                      _tableCell(item.itemName),
                      _tableCell(item.formatQuantityWithPackages()), // Shows: "1410.0 gram (3 pek/pcs)"
                      _tableCell(
                        estPrice > 0 ? 'RM ${estPrice.toStringAsFixed(2)}' : '-',
                      ),
                      _tableCell(
                        estPrice > 0 ? 'RM ${total.toStringAsFixed(2)}' : '-',
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Jumlah Anggaran: RM ${po.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  if (po.notes != null && po.notes!.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Nota:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      po.notes!,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Subscription Payment Receipt PDF
  /// Note: This receipt is from PocketBizz to user, so header uses PocketBizz/BNI Digital Enterprise info
  static Future<Uint8List> generateSubscriptionReceipt({
    required String paymentReference,
    required String planName,
    required int durationMonths,
    required double amount,
    required DateTime paidAt,
    required String paymentGateway,
    String? gatewayTransactionId,
    String? userEmail,
    String? userName,
    bool isEarlyAdopter = false,
  }) async {
    final pdf = pw.Document();

    // Fixed business info for PocketBizz (vendor) - receipt is between PocketBizz and user
    const pocketbizzBusinessName = 'PocketBizz';
    const pocketbizzCompanyName = 'BNI Digital Enterprise';
    const pocketbizzRegistrationNumber = 'TR0323644-V';
    const pocketbizzAddress = ''; // Add address if available
    const pocketbizzPhone = ''; // Add phone if available
    const pocketbizzEmail = 'support@pocketbizz.com'; // Add support email if available

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildHeader(
              title: 'RESIT PEMBAYARAN LANGGANAN',
              documentNumber: paymentReference,
              date: paidAt,
              businessName: pocketbizzBusinessName,
              businessAddress: pocketbizzAddress.isNotEmpty 
                  ? '$pocketbizzAddress\n$pocketbizzCompanyName ($pocketbizzRegistrationNumber)'
                  : '$pocketbizzCompanyName ($pocketbizzRegistrationNumber)',
              businessPhone: pocketbizzPhone.isNotEmpty ? pocketbizzPhone : null,
            ),
            pw.SizedBox(height: 20),
            _buildSubscriptionInfo(
              planName: planName,
              durationMonths: durationMonths,
              isEarlyAdopter: isEarlyAdopter,
            ),
            pw.SizedBox(height: 20),
            if (userName != null || userEmail != null)
              _buildUserInfo(
                userName: userName,
                userEmail: userEmail,
              ),
            if (userName != null || userEmail != null) pw.SizedBox(height: 20),
            _buildSubscriptionPaymentDetails(
              paymentGateway: paymentGateway,
              paymentReference: paymentReference,
              totalAmount: amount,
              gatewayTransactionId: gatewayTransactionId,
            ),
            pw.SizedBox(height: 30),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Print PDF
  static Future<void> printPDF(Uint8List pdfBytes, {String? name}) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: name ?? 'PocketBizz Document',
    );
  }

  /// Share PDF via system share
  static Future<void> sharePDF(Uint8List pdfBytes, {String? fileName}) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${fileName ?? 'document_${DateTime.now().millisecondsSinceEpoch}.pdf'}');
    await file.writeAsBytes(pdfBytes);

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName ?? 'document.pdf',
    );
  }

  /// Save PDF to device
  static Future<File> savePDF(Uint8List pdfBytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  // Helper methods

  static pw.Widget _buildHeader({
    required String title,
    required String documentNumber,
    required DateTime date,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName ?? 'PocketBizz',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                if (businessAddress != null) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10)),
                ],
                if (businessPhone != null) ...[
                  pw.SizedBox(height: 3),
                  pw.Text('Tel: $businessPhone', style: const pw.TextStyle(fontSize: 10)),
                ],
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('No: $documentNumber', style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 3),
                pw.Text('Tarikh: ${_dateFormat.format(date)}', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildVendorInfo({
    required String vendorName,
    required String vendorPhone,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Kepada:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            vendorName,
            style: const pw.TextStyle(fontSize: 12),
          ),
          if (vendorPhone.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Tel: $vendorPhone',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable({required List<ClaimItem> items}) {
    // Note: Commission already deducted in delivery, so no commission column needed
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5),  // No. column
        1: pw.FlexColumnWidth(3.5),  // Produk column
        2: pw.FlexColumnWidth(1.2),  // Kuantiti column
        3: pw.FlexColumnWidth(2),    // Harga Unit column
        4: pw.FlexColumnWidth(2),    // Jumlah column
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('No.', isHeader: true),
            _tableCell('Produk', isHeader: true),
            _tableCell('Kuantiti', isHeader: true),
            _tableCell('Harga Unit', isHeader: true),
            _tableCell('Jumlah', isHeader: true),
          ],
        ),
        ...items.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final item = entry.value;
            
            // Build product name with delivery number and C/F remark
            // productName is required String, so it should never be null
            String productDisplayName = item.productName;
            
            // Add delivery number if available
            final deliveryNum = item.deliveryNumber;
            if (deliveryNum != null && deliveryNum.toString().isNotEmpty) {
              productDisplayName += '\n[Invois: $deliveryNum]';
            }
            
            // Add C/F remark if it's a carry forward item
            if (item.isCarryForward == true) {
              productDisplayName += '\n[Carry Forward C/F]';
            }
            
            return pw.TableRow(
              children: [
                _tableCell('${index + 1}'),
                _tableCell(productDisplayName),
                _tableCell(item.quantitySold.toStringAsFixed(1)),
                _tableCell('RM ${item.unitPrice.toStringAsFixed(2)}'),
                _tableCell('RM ${item.grossAmount.toStringAsFixed(2)}'),
              ],
            );
          },
        ),
      ],
    );
  }

  static pw.Widget _buildDeliveryItemsTable({required List<DeliveryItem> items}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('Produk', isHeader: true),
            _tableCell('Kuantiti', isHeader: true),
            _tableCell('Harga Unit', isHeader: true),
            _tableCell('Jumlah', isHeader: true),
          ],
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              _tableCell(item.productName),
              _tableCell(item.quantity.toStringAsFixed(1)),
              _tableCell('RM ${item.unitPrice.toStringAsFixed(2)}'),
              _tableCell('RM ${item.totalPrice.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSummary({
    required double grossAmount,
    required double commissionRate,
    required double commissionAmount,
    required double netAmount,
    required double paidAmount,
    required double balanceAmount,
    String? commissionType, // 'percentage' or 'price_range'
  }) {
    // Determine commission label based on type
    final commissionLabel = commissionType == 'price_range'
        ? 'Komisyen (Price Range)'
        : 'Komisyen (${commissionRate.toStringAsFixed(1)}%)';
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Commission already deducted in delivery (unit_price = retail_price - commission)
          // So gross = net = claim amount (no need to show commission deduction)
          _summaryRow('Jumlah Tuntutan', netAmount, isBold: true),
          // Note: For backward compatibility, only show commission info if > 0 (old claims)
          if (commissionAmount > 0) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              '* Nota: Komisyen sudah ditolak dalam invois penghantaran',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
          pw.SizedBox(height: 10),
          _summaryRow('Telah Dibayar', paidAmount),
          pw.SizedBox(height: 5),
          _summaryRow('Jumlah Tuntutan', balanceAmount, isBold: true, isOutstanding: true),
        ],
      ),
    );
  }

  static pw.Widget _buildSubscriptionInfo({
    required String planName,
    required int durationMonths,
    required bool isEarlyAdopter,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Maklumat Langganan', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _infoRow('Pakej', planName),
          pw.SizedBox(height: 5),
          _infoRow('Tempoh', '$durationMonths bulan'),
          if (isEarlyAdopter) ...[
            pw.SizedBox(height: 5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.green100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                'Early Adopter - Harga Istimewa',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.green800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildUserInfo({
    String? userName,
    String? userEmail,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Maklumat Pengguna', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          if (userName != null) _infoRow('Nama', userName),
          if (userName != null) pw.SizedBox(height: 5),
          if (userEmail != null) _infoRow('Email', userEmail),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$label:', style: const pw.TextStyle(fontSize: 11)),
        pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentDetails({
    required String paymentMethod,
    String? paymentReference,
    required double totalAmount,
    String? gatewayTransactionId,
  }) {
    final methodLabels = {
      'bill_to_bill': 'Bill to Bill',
      'per_claim': 'Per Claim',
      'partial': 'Bayar Separa',
      'carry_forward': 'Carry Forward',
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Kaedah Bayaran:', style: const pw.TextStyle(fontSize: 11)),
              pw.Text(
                methodLabels[paymentMethod] ?? paymentMethod,
                style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          if (paymentReference != null && paymentReference.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Rujukan:', style: const pw.TextStyle(fontSize: 11)),
                pw.Text(paymentReference, style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Jumlah Bayaran:',
                style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'RM ${totalAmount.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAllocationsTable({required List<PaymentAllocation> allocations}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableCell('No. Tuntutan', isHeader: true),
            _tableCell('Jumlah', isHeader: true),
          ],
        ),
        ...allocations.map(
          (allocation) => pw.TableRow(
            children: [
              _tableCell(allocation.claimNumber),
              _tableCell('RM ${allocation.amount.toStringAsFixed(2)}'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNotes(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Nota:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            notes,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        children: [
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text(
            'Dokumen ini dijana oleh PocketBizz',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            _dateTimeFormat.format(DateTime.now()),
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment? alignment,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Align(
        alignment: alignment ?? pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isDeduction = false,
    bool isOutstanding = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          '${isDeduction ? '-' : ''}RM ${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: isBold ? 13 : 11,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isOutstanding ? PdfColors.red700 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSubscriptionPaymentDetails({
    required String paymentGateway,
    required String paymentReference,
    required double totalAmount,
    String? gatewayTransactionId,
  }) {
    final gatewayLabels = {
      'bcl_my': 'BCL.my',
      'stripe': 'Stripe',
      'paypal': 'PayPal',
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Maklumat Pembayaran', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _infoRow('Kaedah Pembayaran', gatewayLabels[paymentGateway.toLowerCase()] ?? paymentGateway),
          pw.SizedBox(height: 5),
          _infoRow('Rujukan Pembayaran', paymentReference),
          if (gatewayTransactionId != null && gatewayTransactionId.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            _infoRow('ID Transaksi Gateway', gatewayTransactionId),
          ],
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Jumlah Dibayar:', style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'RM ${totalAmount.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}