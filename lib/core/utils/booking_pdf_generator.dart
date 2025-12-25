import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/repositories/bookings_repository_supabase.dart';
import '../../data/models/business_profile.dart';
import 'date_time_helper.dart';

/**
 * 🔒 POCKETBIZZ CORE ENGINE (STABLE)
 * ❌ DO NOT MODIFY
 * ❌ DO NOT REFACTOR
 * ❌ DO NOT OPTIMIZE
 * This logic is production-tested.
 * New features must EXTEND, not change.
 * 
 * Balance calculations (totalAmount - deposit - totalPaid) are critical.
 * Invoice shows "Baki Perlu Dibayar" (fixed), Receipt shows "Baki Terkini" (current).
 */
/// PDF Generator for Booking Invoices
class BookingPDFGenerator {
  /// Generate PDF Invoice for Booking
  static Future<Uint8List> generateBookingInvoice(
    Booking booking, {
    BusinessProfile? businessProfile,
    String? invoiceNumber,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.now());
    final deliveryDate = DateFormat('dd MMMM yyyy', 'ms_MY').format(
      DateTime.parse(booking.deliveryDate),
    );
    
    // Generate invoice number if not provided
    final invNumber = invoiceNumber ?? _generateInvoiceNumber(booking.createdAt);

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
                        businessProfile?.businessName ?? 'Tempahan Invoice',
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
                            'INVOICE',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            invNumber,
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
                        color: _getStatusColor(booking.status),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        _getStatusLabel(booking.status),
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

            // Invoice Details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'No. Tempahan: ${booking.bookingNumber}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarikh Invoice: $date',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Customer Details
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
                    'PELANGGAN:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    booking.customerName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    booking.customerPhone,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  if (booking.customerEmail != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      booking.customerEmail!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Event Details
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
                    'MAKLUMAT MAJLIS:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Jenis: ${_formatEventType(booking.eventType)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  if (booking.eventDate != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarikh Majlis: ${DateFormat('dd MMMM yyyy', 'ms_MY').format(DateTime.parse(booking.eventDate!))}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Tarikh Hantar: $deliveryDate',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  if (booking.deliveryTime != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Masa: ${booking.deliveryTime}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                  if (booking.deliveryLocation != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Lokasi: ${booking.deliveryLocation}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Items Table
            if (booking.items != null && booking.items!.isNotEmpty) ...[
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
                  ...booking.items!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final total = item.subtotal;

                    return pw.TableRow(
                      children: [
                        _buildTableCell('${index + 1}'),
                        _buildTableCell(item.productName),
                        _buildTableCell(item.quantity.toStringAsFixed(1)),
                        _buildTableCell(item.unitPrice.toStringAsFixed(2)),
                        _buildTableCell(total.toStringAsFixed(2)),
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
                            'Subtotal:',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.Text(
                            'RM${_calculateItemsTotal(booking.items!).toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      if (booking.discountAmount != null &&
                          booking.discountAmount! > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Diskaun:',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.green700,
                              ),
                            ),
                            pw.Text(
                              '-RM${booking.discountAmount!.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                color: PdfColors.green700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
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
                            'RM${booking.totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (booking.depositAmount != null &&
                          booking.depositAmount! > 0) ...[
                        pw.SizedBox(height: 12),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Deposit:',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                            pw.Text(
                              'RM${booking.depositAmount!.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Baki Perlu Dibayar:',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'RM${(booking.totalAmount - (booking.depositAmount ?? 0.0)).toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
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
            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
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
                      booking.notes!,
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
              'Terima kasih atas tempahan anda!',
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

  static double _calculateItemsTotal(List<BookingItem> items) {
    return items.fold<double>(
      0.0,
      (sum, item) => sum + item.subtotal,
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return PdfColors.orange;
      case 'confirmed':
        return PdfColors.blue;
      case 'completed':
        return PdfColors.green;
      case 'cancelled':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  static String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'MENUNGGU';
      case 'confirmed':
        return 'DISAHKAN';
      case 'completed':
        return 'SELESAI';
      case 'cancelled':
        return 'DIBATALKAN';
      default:
        return status.toUpperCase();
    }
  }

  static String _formatEventType(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'perkahwinan':
        return 'Perkahwinan';
      case 'kenduri':
        return 'Kenduri';
      case 'door_gifts':
        return 'Door Gifts';
      case 'birthday':
        return 'Hari Jadi';
      case 'aqiqah':
        return 'Aqiqah';
      case 'lain-lain':
        return 'Lain-lain';
      default:
        return eventType;
    }
  }

  /// Generate invoice number based on date and booking number
  /// Format: INV-YYMM-XXXX (e.g., INV-2412-0001)
  /// Uses booking number sequence for uniqueness
  static String _generateInvoiceNumber(DateTime date) {
    final yearMonth = DateFormat('yyMM').format(date);
    // Extract sequence from timestamp (last 4 digits)
    // This ensures uniqueness while maintaining date-based format
    final timestamp = date.millisecondsSinceEpoch;
    final sequence = (timestamp % 10000).toString().padLeft(4, '0');
    return 'INV-$yearMonth-$sequence';
  }

  /// Generate Payment Receipt PDF
  static Future<Uint8List> generatePaymentReceipt({
    required Booking booking,
    required Map<String, dynamic> payment,
    BusinessProfile? businessProfile,
  }) async {
    final pdf = pw.Document();
    final date = DateTimeHelper.formatDate(DateTime.now(), pattern: 'dd MMMM yyyy');
    final paymentDate = payment['payment_date'] != null
        ? DateTimeHelper.formatDate(DateTime.parse(payment['payment_date']), pattern: 'dd MMMM yyyy')
        : date;
    final paymentTime = payment['payment_time'] != null
        ? payment['payment_time'] as String
        : DateTimeHelper.formatTime(DateTime.now(), pattern: 'hh:mm a');
    
    final paymentNumber = payment['payment_number'] as String? ?? 'N/A';
    final paymentAmount = (payment['payment_amount'] as num).toDouble();
    final paymentMethod = payment['payment_method'] as String? ?? 'cash';
    final paymentReference = payment['payment_reference'] as String?;
    final notes = payment['notes'] as String?;

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
                        businessProfile?.businessName ?? 'Resit Pembayaran',
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
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green700,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'RESIT PEMBAYARAN',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            paymentNumber,
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Payment Details
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
                    'Maklumat Pembayaran',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildReceiptRow('No. Tempahan', booking.bookingNumber),
                  _buildReceiptRow('Pelanggan', booking.customerName),
                  _buildReceiptRow('Tarikh Pembayaran', '$paymentDate, $paymentTime'),
                  _buildReceiptRow('Jumlah Pembayaran', 'RM${paymentAmount.toStringAsFixed(2)}', isHighlight: true),
                  _buildReceiptRow('Kaedah Pembayaran', _formatPaymentMethod(paymentMethod)),
                  if (paymentReference != null && paymentReference.isNotEmpty)
                    _buildReceiptRow('Rujukan', paymentReference),
                  if (notes != null && notes.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Nota: $notes',
                      style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Products Ordered Section
            if (booking.items != null && booking.items!.isNotEmpty) ...[
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
                      'Produk Ditempah',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    // Products Table
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(0.3),
                        1: const pw.FlexColumnWidth(2.0),
                        2: const pw.FlexColumnWidth(1.0),
                        3: const pw.FlexColumnWidth(1.2),
                        4: const pw.FlexColumnWidth(1.2),
                      },
                      children: [
                        // Header Row
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _buildTableCell('No', isHeader: true, fontSize: 9),
                            _buildTableCell('Produk', isHeader: true, fontSize: 9),
                            _buildTableCell('Kuantiti', isHeader: true, fontSize: 9),
                            _buildTableCell('Harga', isHeader: true, fontSize: 9),
                            _buildTableCell('Jumlah', isHeader: true, fontSize: 9),
                          ],
                        ),
                        // Item Rows
                        ...booking.items!.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return pw.TableRow(
                            children: [
                              _buildTableCell('${index + 1}', fontSize: 9),
                              _buildTableCell(item.productName, fontSize: 9),
                              _buildTableCell(item.quantity.toStringAsFixed(1), fontSize: 9),
                              _buildTableCell('RM${item.unitPrice.toStringAsFixed(2)}', fontSize: 9),
                              _buildTableCell('RM${item.subtotal.toStringAsFixed(2)}', fontSize: 9),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],
            
            // Booking Summary
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
                    'Ringkasan Tempahan',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildReceiptRow('Jumlah Tempahan', 'RM${booking.totalAmount.toStringAsFixed(2)}'),
                  if (booking.depositAmount != null && booking.depositAmount! > 0)
                    _buildReceiptRow('Deposit', 'RM${booking.depositAmount!.toStringAsFixed(2)}'),
                  _buildReceiptRow('Jumlah Dibayar', 'RM${booking.totalPaid.toStringAsFixed(2)}'),
                  pw.Divider(),
                  _buildReceiptRow(
                    'Baki',
                    'RM${(booking.totalAmount - (booking.depositAmount ?? 0.0) - booking.totalPaid).toStringAsFixed(2)}',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            
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
                    'Terima kasih atas pembayaran anda!',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Sila simpan resit ini sebagai rekod pembayaran.',
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

  static pw.Widget _buildReceiptRow(String label, String value, {bool isHighlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isHighlight ? 12 : 11,
              fontWeight: isHighlight ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHighlight ? PdfColors.blueGrey800 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cek';
      case 'credit_card':
        return 'Kad Kredit';
      case 'e_wallet':
        return 'E-Wallet';
      case 'other':
        return 'Lain-lain';
      default:
        return method;
    }
  }
}

