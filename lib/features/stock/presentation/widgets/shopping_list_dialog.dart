import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/stock_item.dart';
import '../../../../data/repositories/shopping_cart_repository_supabase.dart';
import '../../../subscription/widgets/subscription_guard.dart';

/// Shopping List Dialog
/// Review and confirm items to add to shopping cart
class ShoppingListDialog extends StatefulWidget {
  final List<StockItem> selectedItems;
  final VoidCallback onSuccess;

  const ShoppingListDialog({
    super.key,
    required this.selectedItems,
    required this.onSuccess,
  });

  @override
  State<ShoppingListDialog> createState() => _ShoppingListDialogState();
}

class _ShoppingListDialogState extends State<ShoppingListDialog> {
  final _cartRepo = ShoppingCartRepository();
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _notesControllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with suggested quantities (in pek/pcs)
    for (final item in widget.selectedItems) {
      final suggestedQtyInPek = _calculateSuggestedQuantity(item);
      _quantityControllers[item.id] = TextEditingController(
        text: suggestedQtyInPek.toStringAsFixed(0), // pek/pcs (no decimals)
      );
      _notesControllers[item.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _calculateSuggestedQuantity(StockItem item) {
    final shortage = item.lowStockThreshold - item.currentQuantity;
    if (shortage <= 0) return 1.0; // At least 1 pek

    // Round up to nearest package (return in pek/pcs)
    final packagesNeeded = (shortage / item.packageSize).ceil();
    return packagesNeeded.toDouble(); // Return pek/pcs count, not base unit
  }

  double _calculateEstimatedTotal() {
    double total = 0.0;
    
    for (final item in widget.selectedItems) {
      // qty is in pek/pcs
      final qtyInPek = double.tryParse(_quantityControllers[item.id]?.text ?? '0') ?? 0;
      // qtyInPek is already in pek/pcs, so use directly
      total += qtyInPek * item.purchasePrice;
    }
    
    return total;
  }

  int _getLowStockCount() {
    return widget.selectedItems.where((item) => item.isLowStock).length;
  }

  Future<void> _handleBulkAdd() async {
    // PHASE: Subscriber Expired System - Protect bulk action
    await requirePro(context, 'Tambah ke Senarai Belian (Bulk)', () async {
      setState(() => _isLoading = true);

      try {
      final items = widget.selectedItems.map((item) {
        // qty is in pek/pcs, convert to base unit
        final qtyInPek = double.tryParse(_quantityControllers[item.id]?.text ?? '0') ?? 0;
        final qty = qtyInPek * item.packageSize; // Convert to base unit
        final notes = _notesControllers[item.id]?.text;

        return {
          'stockItemId': item.id,
          'shortageQty': qty, // Base unit
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        };
      }).toList();

      final result = await _cartRepo.bulkAddToCart(items);

      if (mounted) {
        Navigator.pop(context);
        
        final added = result['results']['added'] ?? 0;
        final skipped = result['results']['skipped'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $added item ditambah${skipped > 0 ? ", $skipped sudah dalam senarai" : ""}',
            ),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Lihat Senarai',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pushNamed(context, '/shopping-list');
              },
            ),
          ),
        );
        
        widget.onSuccess();
      }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Tambah ke Senarai Belian (Bulk)',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final estimatedTotal = _calculateEstimatedTotal();
    final lowStockCount = _getLowStockCount();

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tambah ke Senarai Belian',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Semak ${widget.selectedItems.length} item dipilih',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Jumlah',
                      '${widget.selectedItems.length}',
                      Icons.shopping_bag,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildSummaryItem(
                      'Rendah',
                      '$lowStockCount',
                      Icons.warning_amber,
                      color: AppColors.warning,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  Expanded(
                    child: _buildSummaryItem(
                      'Anggaran',
                      'RM ${estimatedTotal.toStringAsFixed(2)}',
                      Icons.attach_money,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),

            // Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.selectedItems.length,
                itemBuilder: (context, index) {
                  final item = widget.selectedItems[index];
                  return _buildCartItemCard(item);
                },
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleBulkAdd,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_cart, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Tambah ${widget.selectedItems.length} Item',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppColors.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemCard(StockItem item) {
    // qty is in pek/pcs
    final qtyInPek = double.tryParse(_quantityControllers[item.id]?.text ?? '0') ?? 0;
    final cost = qtyInPek * item.purchasePrice; // qtyInPek is already in pek/pcs
    final suggestedQtyInPek = _calculateSuggestedQuantity(item);
    final qtyInBaseUnit = qtyInPek * item.packageSize;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Header
            Row(
              children: [
                if (item.isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'RENDAH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (item.isLowStock) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Stock Info
            Row(
              children: [
                Text(
                  'Stok: ${item.currentQuantity.toStringAsFixed(2)} ${item.unit}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Text(
                  'Threshold: ${item.lowStockThreshold.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pakej: ${item.packageSize.toStringAsFixed(2)} ${item.unit} @ RM ${item.purchasePrice.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            // Quantity Input (in pek/pcs)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _quantityControllers[item.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        decoration: InputDecoration(
                          labelText: 'Kuantiti Beli',
                          hintText: 'e.g., 5 (untuk 5 pek/pcs)',
                          suffixText: 'pek/pcs',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          helperText: 'Cadangan: $suggestedQtyInPek pek/pcs (${(suggestedQtyInPek * item.packageSize).toStringAsFixed(1)} ${item.unit})',
                          helperStyle: const TextStyle(fontSize: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (qtyInPek > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '= ${qtyInBaseUnit.toStringAsFixed(1)} ${item.unit}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kos',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'RM ${cost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        if (qtyInPek > 0)
                          Text(
                            '$qtyInPek pek/pcs',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notes Input
            TextField(
              controller: _notesControllers[item.id],
              decoration: InputDecoration(
                labelText: 'Catatan (Optional)',
                hintText: 'Tambah nota...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

