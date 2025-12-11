import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/stock_item.dart';
import '../../../../data/models/stock_movement.dart';
import '../../../../data/repositories/stock_repository_supabase.dart';
import '../../../../core/supabase/supabase_client.dart';

/// Replenish Stock Dialog
/// Mobile-first dialog for adding stock quantity
class ReplenishStockDialog extends StatefulWidget {
  final StockItem stockItem;
  final VoidCallback onSuccess;

  const ReplenishStockDialog({
    super.key,
    required this.stockItem,
    required this.onSuccess,
  });

  @override
  State<ReplenishStockDialog> createState() => _ReplenishStockDialogState();
}

class _ReplenishStockDialogState extends State<ReplenishStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _packageSizeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.stockItem.purchasePrice.toString();
    _packageSizeController.text = widget.stockItem.packageSize.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _packageSizeController.dispose();
    super.dispose();
  }

  Future<void> _handleReplenish() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final additionalQty = double.parse(_quantityController.text);
      final newPrice = _priceController.text.isNotEmpty 
          ? double.parse(_priceController.text) 
          : widget.stockItem.purchasePrice;
      final newPackageSize = _packageSizeController.text.isNotEmpty
          ? double.parse(_packageSizeController.text)
          : widget.stockItem.packageSize;

      final repo = StockRepository(supabase);
      
      // Record stock movement
      await repo.recordStockMovement(
        StockMovementInput(
          stockItemId: widget.stockItem.id,
          movementType: StockMovementType.replenish,
          quantityChange: additionalQty,
          reason: 'Replenish stock - Added $additionalQty ${widget.stockItem.unit}',
        ),
      );

      // Update stock item with new quantity and optionally new price/package size
      final newQuantity = widget.stockItem.currentQuantity + additionalQty;
      
      await supabase.from('stock_items').update({
        'current_quantity': newQuantity,
        if (newPrice != widget.stockItem.purchasePrice) 
          'purchase_price': newPrice,
        if (newPackageSize != widget.stockItem.packageSize) 
          'package_size': newPackageSize,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.stockItem.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Stok berjaya ditambah!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newQuantity = widget.stockItem.currentQuantity + 
        (double.tryParse(_quantityController.text) ?? 0);
    final newPrice = double.tryParse(_priceController.text) ?? widget.stockItem.purchasePrice;
    final newPackageSize = double.tryParse(_packageSizeController.text) ?? widget.stockItem.packageSize;
    final newUnitPrice = newPrice / newPackageSize;

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_circle,
                        color: AppColors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tambah Stok',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.stockItem.name,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Current Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Stok Semasa',
                        '${widget.stockItem.currentQuantity.toStringAsFixed(2)} ${widget.stockItem.unit}',
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Pakej Semasa',
                        '${widget.stockItem.packageSize.toStringAsFixed(2)} ${widget.stockItem.unit} @ RM ${widget.stockItem.purchasePrice.toStringAsFixed(2)}',
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        'Harga Per Unit',
                        'RM ${(widget.stockItem.purchasePrice / widget.stockItem.packageSize).toStringAsFixed(4)}/${widget.stockItem.unit}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quantity Input
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Kuantiti Tambahan *',
                    hintText: 'Berapa banyak stok ditambah?',
                    suffixText: widget.stockItem.unit,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Sila masukkan kuantiti';
                    }
                    final qty = double.tryParse(value);
                    if (qty == null || qty <= 0) {
                      return 'Kuantiti mesti nombor positif';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // New Price (Optional)
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Harga Pakej Baru (Optional)',
                    hintText: 'Jika harga berubah...',
                    prefixText: 'RM ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // New Package Size (Optional)
                TextFormField(
                  controller: _packageSizeController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Saiz Pakej Baru (Optional)',
                    hintText: 'Jika saiz pakej berubah...',
                    suffixText: widget.stockItem.unit,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),

                // Preview Card
                if (_quantityController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '📦 Preview Stok Baru',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Stok Baru',
                          '${newQuantity.toStringAsFixed(2)} ${widget.stockItem.unit}',
                          valueColor: AppColors.success,
                        ),
                        if (_priceController.text.isNotEmpty || 
                            _packageSizeController.text.isNotEmpty) ...[
                          const Divider(height: 16),
                          _buildInfoRow(
                            'Pakej Baru',
                            '${newPackageSize.toStringAsFixed(2)} ${widget.stockItem.unit} @ RM ${newPrice.toStringAsFixed(2)}',
                          ),
                          const Divider(height: 16),
                          _buildInfoRow(
                            'Harga Per Unit Baru',
                            'RM ${newUnitPrice.toStringAsFixed(4)}/${widget.stockItem.unit}',
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleReplenish,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                            : const Text(
                                '✅ Tambah Stok',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

