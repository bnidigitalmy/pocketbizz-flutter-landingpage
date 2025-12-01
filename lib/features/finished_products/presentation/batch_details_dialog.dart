import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/finished_product.dart';
import '../../../data/repositories/finished_products_repository_supabase.dart';

/// Batch Details Dialog
/// Shows all batches for a specific product with FIFO ordering
class BatchDetailsDialog extends StatefulWidget {
  final String productId;
  final String productName;

  const BatchDetailsDialog({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  State<BatchDetailsDialog> createState() => _BatchDetailsDialogState();
}

class _BatchDetailsDialogState extends State<BatchDetailsDialog> {
  final _repository = FinishedProductsRepository();
  List<ProductionBatch> _batches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final batches = await _repository.getProductBatches(widget.productId);
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading batches: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.productName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _batches.isEmpty
                        ? _buildEmptyView()
                        : _buildBatchesList(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Tiada batch untuk produk ini',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchesList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _batches.length,
      itemBuilder: (context, index) {
        return _buildBatchCard(_batches[index], index);
      },
    );
  }

  Widget _buildBatchCard(ProductionBatch batch, int index) {
    final expiryStatus = _getExpiryStatus(batch.expiryDate);
    final percentage = batch.remainingPercentage;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges
            Row(
              children: [
                Chip(
                  label: Text('FIFO #${index + 1}'),
                  backgroundColor: Colors.grey[200],
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        expiryStatus.icon,
                        size: 14,
                        color: expiryStatus.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        expiryStatus.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: expiryStatus.color,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: expiryStatus.backgroundColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Dates
            Row(
              children: [
                Expanded(
                  child: _buildDateInfo(
                    'Tarikh Produksi',
                    DateFormat('dd MMM yyyy', 'ms_MY').format(batch.batchDate),
                  ),
                ),
                if (batch.expiryDate != null)
                  Expanded(
                    child: _buildDateInfo(
                      'Expiry Date',
                      DateFormat('dd MMM yyyy', 'ms_MY').format(batch.expiryDate!),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Remaining quantity
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Baki:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${batch.remainingQty.toStringAsFixed(1)} / ${batch.quantity} unit',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage > 50
                                ? Colors.green
                                : percentage > 25
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Notes
            if (batch.notes != null && batch.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        batch.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
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

  Widget _buildDateInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  ExpiryStatus _getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) {
      return ExpiryStatus(
        status: 'unknown',
        label: 'Tiada Expiry',
        color: Colors.grey,
        backgroundColor: Colors.grey[100]!,
        icon: Icons.help_outline,
      );
    }

    final now = DateTime.now();
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilExpiry = expiry.difference(today).inDays;

    if (daysUntilExpiry < 0) {
      return ExpiryStatus(
        status: 'expired',
        label: 'Expired',
        color: Colors.red[700]!,
        backgroundColor: Colors.red[50]!,
        icon: Icons.warning,
      );
    } else if (daysUntilExpiry <= 3) {
      return ExpiryStatus(
        status: 'warning',
        label: '$daysUntilExpiry hari lagi',
        color: Colors.orange[700]!,
        backgroundColor: Colors.orange[50]!,
        icon: Icons.access_time,
      );
    } else if (daysUntilExpiry <= 7) {
      return ExpiryStatus(
        status: 'soon',
        label: '$daysUntilExpiry hari lagi',
        color: Colors.blue[700]!,
        backgroundColor: Colors.blue[50]!,
        icon: Icons.schedule,
      );
    } else {
      return ExpiryStatus(
        status: 'fresh',
        label: 'Fresh',
        color: Colors.green[700]!,
        backgroundColor: Colors.green[50]!,
        icon: Icons.check_circle,
      );
    }
  }
}

class ExpiryStatus {
  final String status;
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  ExpiryStatus({
    required this.status,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });
}

