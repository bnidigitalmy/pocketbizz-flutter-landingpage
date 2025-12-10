import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../data/models/finished_product.dart';
import '../../../data/repositories/finished_products_repository_supabase.dart';
import '../../../data/repositories/production_repository_supabase.dart';

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
  final _productionRepo = ProductionRepository(supabase);
  List<ProductionBatch> _batches = [];
  Map<String, List<Map<String, dynamic>>> _movementHistory = {};
  Map<String, bool> _expandedBatches = {};
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
      
      // Load movement history for all batches
      final historyMap = <String, List<Map<String, dynamic>>>{};
      for (final batch in batches) {
        try {
          final history = await _productionRepo.getBatchMovementHistory(batch.id);
          historyMap[batch.id] = history;
        } catch (e) {
          historyMap[batch.id] = [];
        }
      }
      
      setState(() {
        _batches = batches;
        _movementHistory = historyMap;
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
  
  void _toggleBatchExpansion(String batchId) {
    setState(() {
      _expandedBatches[batchId] = !(_expandedBatches[batchId] ?? false);
    });
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
            
            // Tracking History Section
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _toggleBatchExpansion(batch.id),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jejak Penggunaan Stok',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Icon(
                      (_expandedBatches[batch.id] ?? false)
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded History List
            if (_expandedBatches[batch.id] ?? false) ...[
              const SizedBox(height: 8),
              _buildMovementHistory(batch.id),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildMovementHistory(String batchId) {
    final movements = _movementHistory[batchId] ?? [];
    
    if (movements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Tiada rekod penggunaan stok',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: movements.map((movement) {
          return _buildMovementItem(movement);
        }).toList(),
      ),
    );
  }
  
  Widget _buildMovementItem(Map<String, dynamic> movement) {
    final movementType = movement['movement_type'] as String? ?? 'sale';
    final quantity = (movement['quantity'] as num?)?.toDouble() ?? 0.0;
    final remainingAfter = (movement['remaining_after_movement'] as num?)?.toDouble() ?? 0.0;
    final createdAt = movement['created_at'] != null
        ? DateTime.parse(movement['created_at'] as String)
        : DateTime.now();
    final notes = movement['notes'] as String?;
    final referenceType = movement['reference_type'] as String?;
    
    // Get icon and color based on movement type
    IconData icon;
    Color color;
    String typeLabel;
    
    switch (movementType) {
      case 'sale':
        icon = Icons.shopping_cart;
        color = Colors.green;
        typeLabel = 'Jualan';
        break;
      case 'production':
        icon = Icons.factory;
        color = Colors.blue;
        typeLabel = 'Produksi';
        break;
      case 'adjustment':
        icon = Icons.edit;
        color = Colors.orange;
        typeLabel = 'Pelarasan';
        break;
      case 'expired':
        icon = Icons.warning;
        color = Colors.red;
        typeLabel = 'Luput';
        break;
      case 'damaged':
        icon = Icons.broken_image;
        color = Colors.red;
        typeLabel = 'Rosak';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        typeLabel = 'Lain-lain';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a', 'ms_MY').format(createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-${quantity.toStringAsFixed(1)} unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  Text(
                    'Baki: ${remainingAfter.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              notes,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
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

