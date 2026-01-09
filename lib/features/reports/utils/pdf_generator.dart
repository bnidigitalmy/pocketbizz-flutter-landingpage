import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../data/models/profit_loss_report.dart';
import '../data/models/top_product.dart';
import '../data/models/top_vendor.dart';
import '../data/models/monthly_trend.dart';
import '../data/models/sales_by_channel.dart';
import '../../../../data/models/business_profile.dart';

/// PDF Generator for Reports
class ReportsPDFGenerator {
  /// Generate Profit & Loss Report PDF
  static Future<Uint8List> generateProfitLossPDF({
    required ProfitLossReport profitLoss,
    required List<TopProduct> topProducts,
    required List<TopVendor> topVendors,
    required List<MonthlyTrend> monthlyTrends,
    DateTime? startDate,
    DateTime? endDate,
    BusinessProfile? businessProfile,
    List<SalesByChannel>? salesByChannel,
  }) async {
    final pdf = pw.Document();

    // Date range text
    final dateRangeText = startDate != null && endDate != null
        ? '${DateFormat('d MMM yyyy', 'ms_MY').format(startDate)} - ${DateFormat('d MMM yyyy', 'ms_MY').format(endDate)}'
        : DateFormat('MMMM yyyy', 'ms_MY').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          _buildHeader(dateRangeText, businessProfile),
          pw.SizedBox(height: 20),

          // Executive Summary / Key Highlights
          _buildExecutiveSummary(profitLoss),
          pw.SizedBox(height: 20),

          // Profit & Loss Summary
          _buildProfitLossSection(profitLoss),
          pw.SizedBox(height: 20),

          // Revenue Breakdown by Channel
          if (salesByChannel != null && salesByChannel.isNotEmpty) ...[
            _buildSalesByChannelSection(salesByChannel),
            pw.SizedBox(height: 20),
          ],

          // Top Products
          if (topProducts.isNotEmpty) ...[
            _buildTopProductsSection(topProducts),
            pw.SizedBox(height: 20),
          ],

          // Top Vendors
          if (topVendors.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _buildTopVendorsSection(topVendors),
            pw.SizedBox(height: 16),
          ],

          // Monthly Trends Summary
          if (monthlyTrends.isNotEmpty) ...[
            _buildMonthlyTrendsSection(monthlyTrends),
            pw.SizedBox(height: 20),
          ],

          // Footer
          _buildFooter(),
        ],
      ),
    );

    // Generate PDF bytes
    final pdfBytes = await pdf.save();
    
    // Note: Print dialog is handled in reports_page.dart for better platform control
    // On web, we trigger download directly; on mobile, we show print dialog
    
    return pdfBytes;
  }

  static pw.Widget _buildHeader(String dateRange, BusinessProfile? businessProfile) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Laporan Untung Rugi',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        // Business Name
        pw.Text(
          businessProfile?.businessName ?? 'Laporan Untung Rugi',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        // Business Details (if available)
        if (businessProfile != null) ...[
          if (businessProfile.tagline != null && businessProfile.tagline!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              businessProfile.tagline!,
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
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
          if (businessProfile.email != null && businessProfile.email!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'Email: ${businessProfile.email}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
          if (businessProfile.registrationNumber != null && businessProfile.registrationNumber!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'No. Pendaftaran: ${businessProfile.registrationNumber}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          'Tempoh: $dateRange',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey600,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Dijana pada: ${DateFormat('d MMM yyyy, h:mm a', 'ms_MY').format(DateTime.now())}',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey500,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildProfitLossSection(ProfitLossReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Ringkasan Untung Rugi',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          
          // Revenue
          _buildMetricRow('Jualan (Revenue)', report.totalSales, PdfColors.blue700),
          pw.SizedBox(height: 8),
          
          // COGS
          _buildMetricRow('Kos Pengeluaran (COGS)', report.costOfGoodsSold, PdfColors.red700),
          pw.SizedBox(height: 8),
          
          // Divider
          pw.Divider(),
          pw.SizedBox(height: 8),
          
          // Gross Profit
          _buildMetricRow(
            'Untung Kasar (Gross Profit)',
            report.grossProfit,
            report.grossProfit >= 0 ? PdfColors.green700 : PdfColors.red700,
            isBold: true,
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Margin Kasar:',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                '${report.grossProfitMargin.toStringAsFixed(2)}%',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: report.grossProfitMargin >= 0 ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          
          // Operating Expenses
          _buildMetricRow('Kos Operasi (Operating Expenses)', report.operatingExpenses, PdfColors.orange700),
          pw.SizedBox(height: 8),
          
          // Divider
          pw.Divider(),
          pw.SizedBox(height: 8),
          
          // Operating Profit
          _buildMetricRow(
            'Untung Operasi (EBIT)',
            report.operatingProfit,
            report.operatingProfit >= 0 ? PdfColors.green700 : PdfColors.red700,
            isBold: true,
          ),
          pw.SizedBox(height: 12),
          
          // Other Expenses (Always show for standard P&L format)
          _buildMetricRow(
            'Perbelanjaan Lain (Other Expenses)', 
            report.otherExpenses, 
            report.otherExpenses > 0 ? PdfColors.orange700 : PdfColors.grey600,
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 8),
          
          // Net Profit
          _buildMetricRow(
            'Untung Bersih (Net Profit)',
            report.netProfit,
            report.netProfit >= 0 ? PdfColors.green700 : PdfColors.red700,
            isBold: true,
          ),
          pw.SizedBox(height: 8),
          
          // Net Profit Margin
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Margin Untung Bersih:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${report.netProfitMargin.toStringAsFixed(2)}%',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: report.netProfitMargin >= 0 ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricRow(String label, double value, PdfColor color, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          'RM ${NumberFormat('#,##0.00').format(value)}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTopProductsSection(List<TopProduct> products) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Produk Paling Untung',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Bil', isHeader: true),
                  _buildTableCell('Nama Produk', isHeader: true),
                  _buildTableCell('Terjual', isHeader: true),
                  _buildTableCell('Jumlah Untung', isHeader: true),
                  _buildTableCell('Margin %', isHeader: true),
                ],
              ),
              // Data rows
              ...products.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}'),
                    _buildTableCell(product.productName),
                    _buildTableCell(product.totalSold.toStringAsFixed(0)),
                    _buildTableCell('RM ${NumberFormat('#,##0.00').format(product.totalProfit)}'),
                    _buildTableCell('${product.profitMargin.toStringAsFixed(1)}%'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTopVendorsSection(List<TopVendor> vendors) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Vendor Paling Aktif',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Bil', isHeader: true),
                  _buildTableCell('Nama Vendor', isHeader: true),
                  _buildTableCell('Penghantaran', isHeader: true),
                  _buildTableCell('Jumlah (RM)', isHeader: true),
                ],
              ),
              // Data rows
              ...vendors.asMap().entries.map((entry) {
                final index = entry.key;
                final vendor = entry.value;
                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}'),
                    _buildTableCell(vendor.vendorName),
                    _buildTableCell('${vendor.totalDeliveries}'),
                    _buildTableCell('RM ${NumberFormat('#,##0.00').format(vendor.totalAmount)}'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMonthlyTrendsSection(List<MonthlyTrend> trends) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Trend Bulanan',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Bulan', isHeader: true),
                  _buildTableCell('Jualan (RM)', isHeader: true),
                  _buildTableCell('Kos (RM)', isHeader: true),
                ],
              ),
              // Data rows (show last 6 months)
              ...trends.take(6).map((trend) {
                return pw.TableRow(
                  children: [
                    _buildTableCell(trend.month),
                    _buildTableCell('RM ${NumberFormat('#,##0.00').format(trend.sales)}'),
                    _buildTableCell('RM ${NumberFormat('#,##0.00').format(trend.costs)}'),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildExecutiveSummary(ProfitLossReport report) {
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
                child: _buildSummaryItem('Jualan', report.totalSales, PdfColors.blue700),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildSummaryItem('Untung Kasar', report.grossProfit, PdfColors.green700),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: _buildSummaryItem('Untung Operasi', report.operatingProfit, PdfColors.green700),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildSummaryItem('Untung Bersih', report.netProfit, report.netProfit >= 0 ? PdfColors.green700 : PdfColors.red700),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Margin Kasar:',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
                pw.Text(
                  '${report.grossProfitMargin.toStringAsFixed(2)}%',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green700,
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Text(
                  'Margin Bersih:',
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
                pw.Text(
                  '${report.netProfitMargin.toStringAsFixed(2)}%',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: report.netProfitMargin >= 0 ? PdfColors.green700 : PdfColors.red700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, double value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
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
            'RM ${NumberFormat('#,##0.00').format(value)}',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSalesByChannelSection(List<SalesByChannel> channels) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Jualan Mengikut Saluran',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Saluran', isHeader: true),
                  _buildTableCell('Jumlah (RM)', isHeader: true),
                  _buildTableCell('Peratusan', isHeader: true),
                  _buildTableCell('Transaksi', isHeader: true),
                ],
              ),
              // Data rows
              ...channels.map((channel) {
                return pw.TableRow(
                  children: [
                    _buildTableCell(channel.channelLabel),
                    _buildTableCell('RM ${NumberFormat('#,##0.00').format(channel.revenue)}'),
                    _buildTableCell('${channel.percentage.toStringAsFixed(1)}%'),
                    _buildTableCell('${channel.transactionCount}'),
                  ],
                );
              }),
              // Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildTableCell('Jumlah', isHeader: true),
                  _buildTableCell(
                    'RM ${NumberFormat('#,##0.00').format(channels.fold<double>(0.0, (sum, c) => sum + c.revenue))}',
                    isHeader: true,
                  ),
                  _buildTableCell('100.0%', isHeader: true),
                  _buildTableCell(
                    '${channels.fold<int>(0, (sum, c) => sum + c.transactionCount)}',
                    isHeader: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        children: [
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Nota Penting:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Laporan ini dijana secara automatik oleh PocketBizz. Untuk tujuan perakaunan rasmi, sila rujuk dengan akauntan bertauliah.',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Laporan ini dijana oleh PocketBizz',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'www.pocketbizz.my',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey500,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
}

