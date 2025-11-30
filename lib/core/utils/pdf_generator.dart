import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../data/models/purchase_order.dart';

/// PDF Generator for Purchase Orders
class PDFGenerator {
  /// Generate PDF for Purchase Order
  static Future<Uint8List> generatePOPDF(PurchaseOrder po) async {
    final pdf = pw.Document();
    final date = DateFormat('dd MMMM yyyy', 'ms_MY').format(po.createdAt);
    final dateTime = DateFormat('dd MMMM yyyy, HH:mm', 'ms_MY').format(po.createdAt);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PURCHASE ORDER',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'PocketBizz',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        po.poNumber,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tarikh: $date',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'Status: ${po.status.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(po.status),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Supplier Information
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
                    'KEPADA:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    po.supplierName,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                  if (po.supplierPhone != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Telefon: ${po.supplierPhone}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                  if (po.supplierEmail != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('Email: ${po.supplierEmail}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                  if (po.supplierAddress != null) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(po.supplierAddress!, style: const pw.TextStyle(fontSize: 11)),
                  ],
                ],
              ),
            ),
            
            if (po.deliveryAddress != null) ...[
              pw.SizedBox(height: 16),
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
                      'ALAMAT PENGHANTARAN:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      po.deliveryAddress!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            
            pw.SizedBox(height: 24),
            
            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.5),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.0),
                3: const pw.FlexColumnWidth(0.8),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('No', isHeader: true),
                    _buildTableCell('Item', isHeader: true),
                    _buildTableCell('Kuantiti', isHeader: true),
                    _buildTableCell('Unit', isHeader: true),
                    _buildTableCell('Harga (RM)', isHeader: true),
                    _buildTableCell('Jumlah (RM)', isHeader: true),
                  ],
                ),
                // Item Rows
                ...po.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final price = item.actualPrice ?? item.estimatedPrice ?? 0.0;
                  final total = price * item.quantity;
                  
                  return pw.TableRow(
                    children: [
                      _buildTableCell('${index + 1}'),
                      _buildTableCell(
                        item.itemName + (item.notes != null && item.notes!.isNotEmpty ? '\nNota: ${item.notes}' : ''),
                        fontSize: 10,
                      ),
                      _buildTableCell(item.quantity.toStringAsFixed(1)),
                      _buildTableCell(item.unit),
                      _buildTableCell(price.toStringAsFixed(2)),
                      _buildTableCell(total.toStringAsFixed(2)),
                    ],
                  );
                }),
                // Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('', colSpan: 5, isBold: true, alignment: pw.Alignment.centerRight),
                    _buildTableCell(
                      'RM ${po.totalAmount.toStringAsFixed(2)}',
                      isBold: true,
                      fontSize: 12,
                    ),
                  ],
                ),
              ],
            ),
            
            if (po.notes != null && po.notes!.isNotEmpty) ...[
              pw.SizedBox(height: 24),
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
                      po.notes!,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            
            pw.SizedBox(height: 30),
            
            // Footer
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Dibuat pada: $dateTime',
              style: pw.TextStyle(
                fontSize: 9,
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
    bool isBold = false,
    int colSpan = 1,
    pw.Alignment alignment = pw.Alignment.centerLeft,
    double fontSize = 11,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: alignment == pw.Alignment.centerRight 
            ? pw.TextAlign.right 
            : pw.TextAlign.left,
      ),
    );
  }

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return PdfColors.amber;
      case 'sent':
        return PdfColors.blue;
      case 'received':
        return PdfColors.green;
      case 'cancelled':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }
}

