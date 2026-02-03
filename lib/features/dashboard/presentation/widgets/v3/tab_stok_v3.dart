import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../../../../core/supabase/supabase_client.dart' show supabase;
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/repositories/stock_repository_supabase.dart';
import '../../../../../data/models/stock_item.dart';
import '../../../../../core/utils/unit_conversion.dart';
import 'dashboard_skeleton_v3.dart';
import 'stagger_animation.dart';

/// Tab Stok (Stock) - Stock status overview and purchase suggestions
class TabStokV3 extends StatefulWidget {
  final VoidCallback onViewStock;
  final VoidCallback onCreatePO;

  const TabStokV3({
    super.key,
    required this.onViewStock,
    required this.onCreatePO,
  });

  @override
  State<TabStokV3> createState() => _TabStokV3State();
}

class _TabStokV3State extends State<TabStokV3> {
  late final StockRepository _stockRepo;

  bool _isLoading = true;
  int _goodStockCount = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  List<StockItem> _lowStockItems = [];

  StreamSubscription? _stockSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _stockRepo = StockRepository(supabase);
    _loadStockData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      _stockSubscription = supabase
          .from('stock_items')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((_) {
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
              if (mounted) _loadStockData();
            });
          });
    } catch (e) {
      debugPrint('Error setting up stock subscription: $e');
    }
  }

  Future<void> _loadStockData() async {
    if (!mounted) return;

    try {
      final allItems = await _stockRepo.getAllStockItems();

      int good = 0;
      int low = 0;
      int out = 0;
      final lowItems = <StockItem>[];

      for (final item in allItems) {
        if (item.currentQuantity <= 0) {
          out++;
          lowItems.add(item);
        } else if (item.stockLevelPercentage < 30) {
          low++;
          lowItems.add(item);
        } else {
          good++;
        }
      }

      // Sort low items: out of stock first, then by percentage
      lowItems.sort((a, b) {
        if (a.currentQuantity <= 0 && b.currentQuantity > 0) return -1;
        if (a.currentQuantity > 0 && b.currentQuantity <= 0) return 1;
        return a.stockLevelPercentage.compareTo(b.stockLevelPercentage);
      });

      if (mounted) {
        setState(() {
          _goodStockCount = good;
          _lowStockCount = low;
          _outOfStockCount = out;
          _lowStockItems = lowItems.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stock data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const TabStokSkeleton();
    }

    return StaggeredColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stock Status Summary
        _buildStockStatus(),
        const SizedBox(height: 16),
        // Purchase Suggestions
        _buildPurchaseSuggestions(),
      ],
    );
  }

  Widget _buildStockStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Status Stok',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status rows
          _buildStatusRow(
            icon: Icons.check_circle,
            label: 'Cukup',
            count: _goodStockCount,
            color: Colors.green,
            onTap: widget.onViewStock,
          ),
          const SizedBox(height: 10),
          _buildStatusRow(
            icon: Icons.warning_amber,
            label: 'Hampir Habis',
            count: _lowStockCount,
            color: Colors.orange,
            actionLabel: 'Lihat',
            onTap: widget.onViewStock,
          ),
          const SizedBox(height: 10),
          _buildStatusRow(
            icon: Icons.error_outline,
            label: 'Habis',
            count: _outOfStockCount,
            color: Colors.red,
            actionLabel: 'Restock',
            onTap: widget.onCreatePO,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    String? actionLabel,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: count > 0 ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (actionLabel != null && count > 0) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withOpacity(0.6),
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseSuggestions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cadangan Beli',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_lowStockItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 40,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stok mencukupi!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      'Tiada pembelian diperlukan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._lowStockItems.map((item) => _buildSuggestionItem(item)),

          if (_lowStockItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onViewStock,
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('Shopping List'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onCreatePO,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Buat PO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(StockItem item) {
    final isOut = item.currentQuantity <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(
                color: isOut ? Colors.red : Colors.orange,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isOut)
                  Text(
                    'Baki: ${UnitConversion.formatQuantity(item.currentQuantity, item.unit)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOut
                  ? Colors.red.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isOut ? 'HABIS' : '${item.stockLevelPercentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isOut ? Colors.red : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
