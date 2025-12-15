import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/stock_item_batch.dart';
import '../../../core/utils/unit_conversion.dart';
import 'widgets/add_batch_dialog.dart';

/// Batch Management Page - Manage batches for a stock item
class BatchManagementPage extends StatefulWidget {
  final StockItem stockItem;

  const BatchManagementPage({super.key, required this.stockItem});

  @override
  State<BatchManagementPage> createState() => _BatchManagementPageState();
}

class _BatchManagementPageState extends State<BatchManagementPage> {
  late final StockRepository _stockRepository;
  List<StockItemBatch> _batches = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);

    try {
      final batches = await _stockRepository.getStockItemBatches(widget.stockItem.id);
      final summary = await _stockRepository.getBatchSummary(widget.stockItem.id);

      setState(() {
        _batches = batches;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showAddBatchDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => AddBatchDialog(
        stockItem: widget.stockItem,
      ),
    );

    if (result == true) {
      _loadBatches();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiredCount = _summary['expired_batches'] ?? 0;
    final expiringSoonCount = _batches.where((b) => b.isExpiringSoon && !b.isExpired).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Batches - ${widget.stockItem.name}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary Card
          if (!_isLoading) _buildSummaryCard(),

          // Expiry Alerts
          if (expiredCount > 0 || expiringSoonCount > 0)
            _buildExpiryAlerts(expiredCount, expiringSoonCount),

          // Batches List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _batches.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadBatches,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _batches.length,
                          itemBuilder: (context, index) {
                            return _buildBatchCard(_batches[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBatchDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Batch'),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalBatches = _summary['total_batches'] ?? 0;
    final totalRemaining = _summary['total_remaining'] ?? 0.0;
    final earliestExpiry = _summary['earliest_expiry'] as DateTime?;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batch Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Batches',
                  '$totalBatches',
                  Icons.inventory_2,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  'Remaining',
                  '${(totalRemaining / widget.stockItem.packageSize).toStringAsFixed(0)} pek\n'
                  '${UnitConversion.formatQuantity(totalRemaining, widget.stockItem.unit)}',
                  Icons.shopping_cart,
                  Colors.green,
                ),
              ),
            ],
          ),
          if (earliestExpiry != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: earliestExpiry.isBefore(DateTime.now())
                    ? Colors.red.withOpacity(0.1)
                    : earliestExpiry.difference(DateTime.now()).inDays <= 7
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    earliestExpiry.isBefore(DateTime.now())
                        ? Icons.error
                        : Icons.calendar_today,
                    color: earliestExpiry.isBefore(DateTime.now())
                        ? Colors.red
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          earliestExpiry.isBefore(DateTime.now())
                              ? 'Expired'
                              : 'Earliest Expiry',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(earliestExpiry),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: earliestExpiry.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryAlerts(int expiredCount, int expiringSoonCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: expiredCount > 0
            ? Colors.red.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expiredCount > 0 ? Colors.red : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            expiredCount > 0 ? Icons.error : Icons.warning_amber_rounded,
            color: expiredCount > 0 ? Colors.red : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expiredCount > 0)
                  Text(
                    '⚠️ $expiredCount batch expired!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                if (expiringSoonCount > 0)
                  Text(
                    '⏰ $expiringSoonCount batch expiring soon',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(StockItemBatch batch) {
    final isExpired = batch.isExpired;
    final isExpiringSoon = batch.isExpiringSoon;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isExpired
            ? const BorderSide(color: Colors.red, width: 2)
            : isExpiringSoon
                ? const BorderSide(color: Colors.orange, width: 2)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red
                        : isExpiringSoon
                            ? Colors.orange
                            : batch.isFullyUsed
                                ? Colors.grey
                                : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.batchNumber ?? 'Batch #${batch.id.substring(0, 8)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (batch.supplierName != null)
                        Text(
                          'Supplier: ${batch.supplierName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'EXPIRED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  )
                else if (isExpiringSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'EXPIRING SOON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Quantity Info
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Quantity',
                    '${(batch.quantity / widget.stockItem.packageSize).toStringAsFixed(0)} pek\n'
                    '${UnitConversion.formatQuantity(batch.quantity, widget.stockItem.unit)}',
                    Icons.inventory,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Remaining',
                    '${(batch.remainingQty / widget.stockItem.packageSize).toStringAsFixed(0)} pek\n'
                    '${UnitConversion.formatQuantity(batch.remainingQty, widget.stockItem.unit)}',
                    Icons.shopping_cart,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Used',
                    '${batch.usagePercentage.toStringAsFixed(0)}%',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dates and Cost
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Purchase Date',
                    dateFormat.format(batch.purchaseDate),
                    Icons.calendar_today,
                  ),
                ),
                if (batch.expiryDate != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      'Expiry Date',
                      dateFormat.format(batch.expiryDate!),
                      Icons.event_busy,
                      color: isExpired
                          ? Colors.red
                          : isExpiringSoon
                              ? Colors.orange
                              : null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Cost Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cost per ${widget.stockItem.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'RM ${batch.costPerUnit.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Notes
            if (batch.notes != null && batch.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        batch.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? AppColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No batches yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first batch to track expiry dates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
