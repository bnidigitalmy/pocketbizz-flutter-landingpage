import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/stock_movement.dart';

/// Stock History Page - Timeline of all stock movements
/// Mobile-first, Malay language
class StockHistoryPage extends StatefulWidget {
  final String stockItemId;

  const StockHistoryPage({
    super.key,
    required this.stockItemId,
  });

  @override
  State<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends State<StockHistoryPage> {
  StockItem? _stockItem;
  List<StockMovement> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      // Load stock item
      final itemData = await supabase
          .from('stock_items')
          .select()
          .eq('id', widget.stockItemId)
          .single();
      
      _stockItem = StockItem.fromJson(itemData);

      // Load movements
      final movementsData = await supabase
          .from('stock_movements')
          .select()
          .eq('stock_item_id', widget.stockItemId)
          .order('created_at', ascending: false);

      _movements = (movementsData as List)
          .map((json) => StockMovement.fromJson(json))
          .toList();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sejarah Pergerakan'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_stockItem == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sejarah Pergerakan'),
        ),
        body: const Center(
          child: Text('Item tidak dijumpai'),
        ),
      );
    }

    // Calculate totals
    final totalIncrease = _movements
        .where((m) => m.quantityChange > 0)
        .fold(0.0, (sum, m) => sum + m.quantityChange);

    final totalDecrease = _movements
        .where((m) => m.quantityChange < 0)
        .fold(0.0, (sum, m) => sum + m.quantityChange.abs());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sejarah Pergerakan'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stockItem!.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stok Semasa: ${_stockItem!.currentQuantity.toStringAsFixed(2)} ${_stockItem!.unit}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Jumlah Masuk',
                    '+${totalIncrease.toStringAsFixed(2)} ${_stockItem!.unit}',
                    AppColors.success,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Jumlah Keluar',
                    '-${totalDecrease.toStringAsFixed(2)} ${_stockItem!.unit}',
                    AppColors.error,
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildStatCard(
              'Jumlah Pergerakan',
              '${_movements.length} rekod',
              AppColors.primary,
              Icons.history,
            ),
            const SizedBox(height: 24),

            // Movements Timeline
            if (_movements.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tiada rekod pergerakan',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rekod Pergerakan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._movements.map((movement) => _buildMovementCard(movement)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementCard(StockMovement movement) {
    final isIncrease = movement.quantityChange > 0;
    final config = _getMovementConfig(movement.movementType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Type
            Row(
              children: [
                Icon(
                  config.icon,
                  color: config.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: config.color,
                    ),
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(movement.createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quantity Changes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sebelum',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${movement.quantityBefore.toStringAsFixed(2)} ${_stockItem!.unit}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.grey[400],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Perubahan',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${isIncrease ? "+" : ""}${movement.quantityChange.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isIncrease ? AppColors.success : AppColors.error,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.grey[400],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Selepas',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${movement.quantityAfter.toStringAsFixed(2)} ${_stockItem!.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Reason
            if (movement.reason != null && movement.reason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        movement.reason!,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
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

  MovementConfig _getMovementConfig(String type) {
    switch (type) {
      case 'purchase':
        return MovementConfig('Pembelian', Icons.shopping_cart, Colors.blue);
      case 'replenish':
        return MovementConfig('Tambah Stok', Icons.add_circle, AppColors.success);
      case 'adjust':
        return MovementConfig('Pelarasan', Icons.tune, Colors.orange);
      case 'production_use':
        return MovementConfig('Guna Produksi', Icons.factory, Colors.deepOrange);
      case 'waste':
        return MovementConfig('Rosak/Buang', Icons.delete, AppColors.error);
      case 'return':
        return MovementConfig('Pulangan', Icons.keyboard_return, Colors.purple);
      case 'transfer':
        return MovementConfig('Pindah', Icons.swap_horiz, Colors.indigo);
      case 'correction':
        return MovementConfig('Pembetulan', Icons.settings, Colors.grey);
      default:
        return MovementConfig('Lain-lain', Icons.help_outline, Colors.grey);
    }
  }
}

class MovementConfig {
  final String label;
  final IconData icon;
  final Color color;

  MovementConfig(this.label, this.icon, this.color);
}

