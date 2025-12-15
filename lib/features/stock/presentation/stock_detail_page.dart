import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/stock_movement.dart';
import '../../../data/models/stock_item_batch.dart';
import '../../../core/utils/unit_conversion.dart';
import 'add_edit_stock_item_page.dart';
import 'adjust_stock_page.dart';
import 'batch_management_page.dart';

/// Stock Detail Page - View stock item details and movement history
class StockDetailPage extends StatefulWidget {
  final StockItem stockItem;

  const StockDetailPage({super.key, required this.stockItem});

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> with SingleTickerProviderStateMixin {
  late final StockRepository _stockRepository;
  late StockItem _stockItem;
  List<StockMovement> _movements = [];
  List<StockItemBatch> _batches = [];
  Map<String, dynamic> _batchSummary = {};
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);
    _stockItem = widget.stockItem;
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Reload stock item to get latest data
      final item = await _stockRepository.getStockItemById(_stockItem.id);
      if (item != null) _stockItem = item;

      // Load movements
      final movements = await _stockRepository.getStockMovements(_stockItem.id);

      // Load batches
      final batches = await _stockRepository.getStockItemBatches(_stockItem.id);
      final summary = await _stockRepository.getBatchSummary(_stockItem.id);

      setState(() {
        _movements = movements;
        _batches = batches;
        _batchSummary = summary;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_stockItem.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditStockItemPage(stockItem: _stockItem),
                ),
              );
              if (result == true) _loadData();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'History'),
            Tab(text: 'Batches'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(),
          _buildHistoryTab(),
          _buildBatchesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdjustStockPage(stockItem: _stockItem),
            ),
          );
          if (result == true) _loadData();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.tune),
        label: const Text('Adjust Stock'),
      ),
    );
  }

  Widget _buildDetailsTab() {
    final isLowStock = _stockItem.isLowStock;
    final isOutOfStock = _stockItem.currentQuantity <= 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stock Status Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Current Quantity
                  Text(
                    UnitConversion.formatQuantity(
                      _stockItem.currentQuantity,
                      _stockItem.unit,
                    ),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: isOutOfStock
                          ? Colors.red
                          : isLowStock
                              ? Colors.orange
                              : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current Stock',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Badge
                  if (isOutOfStock || isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOutOfStock ? Icons.error : Icons.warning_amber_rounded,
                            size: 16,
                            color: isOutOfStock ? Colors.red : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isOutOfStock
                                ? 'OUT OF STOCK'
                                : 'LOW STOCK (${_stockItem.stockLevelPercentage.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isOutOfStock ? Colors.red : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Item Information Card
          _buildInfoCard(
            'Item Information',
            [
              _buildInfoRow('Package Size', '${_stockItem.packageSize} ${_stockItem.unit}'),
              _buildInfoRow('Purchase Price', 'RM ${_stockItem.purchasePrice.toStringAsFixed(2)}'),
              _buildInfoRow('Cost per ${_stockItem.unit}', 'RM ${_stockItem.costPerUnit.toStringAsFixed(4)}'),
              _buildInfoRow(
                'Low Stock Alert', 
                '${(_stockItem.lowStockThreshold / _stockItem.packageSize).toStringAsFixed(0)} pek/pcs (${_stockItem.lowStockThreshold.toStringAsFixed(2)} ${_stockItem.unit})',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stock Value Card
          _buildInfoCard(
            'Current Value',
            [
              _buildInfoRow(
                'Total Value',
                'RM ${(_stockItem.currentQuantity * _stockItem.costPerUnit).toStringAsFixed(2)}',
                isHighlighted: true,
              ),
              _buildInfoRow('Quantity', UnitConversion.formatQuantity(_stockItem.currentQuantity, _stockItem.unit)),
              _buildInfoRow('Unit Cost', 'RM ${_stockItem.costPerUnit.toStringAsFixed(4)}'),
            ],
          ),
          const SizedBox(height: 16),

          // Notes Card (if available)
          if (_stockItem.notes != null && _stockItem.notes!.isNotEmpty)
            _buildInfoCard(
              'Notes',
              [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _stockItem.notes!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No movement history yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _movements.length,
        itemBuilder: (context, index) {
          return _buildMovementCard(_movements[index]);
        },
      ),
    );
  }

  Widget _buildMovementCard(StockMovement movement) {
    final isIncrease = movement.isIncrease;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Movement type icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isIncrease
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    movement.movementType.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),

                // Movement type and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movement.movementType.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        dateFormat.format(movement.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Quantity change
                Text(
                  '${isIncrease ? '+' : ''}${movement.quantityChange.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isIncrease ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),

            // Quantity flow
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  movement.quantityBefore.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ),
                Text(
                  movement.quantityAfter.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' ${_stockItem.unit}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            // Reason (if provided)
            if (movement.reason != null && movement.reason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        movement.reason!,
                        style: TextStyle(
                          fontSize: 12,
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

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              color: isHighlighted ? AppColors.primary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final expiredCount = _batchSummary['expired_batches'] ?? 0;
    final expiringSoonCount = _batches.where((b) => b.isExpiringSoon && !b.isExpired).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Batch Summary
          if (_batches.isNotEmpty) _buildBatchSummaryCard(),

          // Expiry Alerts
          if (expiredCount > 0 || expiringSoonCount > 0)
            _buildExpiryAlertBanner(expiredCount, expiringSoonCount),

          // Batches List
          Expanded(
            child: _batches.isEmpty
                ? _buildEmptyBatchesState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _batches.length,
                    itemBuilder: (context, index) {
                      return _buildBatchCard(_batches[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchSummaryCard() {
    final totalBatches = _batchSummary['total_batches'] ?? 0;
    final totalRemaining = _batchSummary['total_remaining'] ?? 0.0;
    final earliestExpiry = _batchSummary['earliest_expiry'] as DateTime?;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Batch Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BatchManagementPage(stockItem: _stockItem),
                    ),
                  ).then((_) => _loadData());
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Batches',
                  '${totalBatches}',
                  Icons.inventory_2,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryItem(
                  'Remaining',
                  UnitConversion.formatQuantity(
                    totalRemaining,
                    _stockItem.unit,
                  ),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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

  Widget _buildExpiryAlertBanner(int expiredCount, int expiringSoonCount) {
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
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
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
            Row(
              children: [
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
                  child: Text(
                    batch.batchNumber ?? 'Batch #${batch.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Remaining',
                    UnitConversion.formatQuantity(
                      batch.remainingQty,
                      _stockItem.unit,
                    ),
                    Icons.shopping_cart,
                  ),
                ),
                if (batch.expiryDate != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoChip(
                      'Expiry',
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
      child: Row(
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBatchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'No batches yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add batches to track expiry dates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BatchManagementPage(stockItem: _stockItem),
                ),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah Batch'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

