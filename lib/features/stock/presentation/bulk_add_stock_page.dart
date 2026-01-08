import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/repositories/stock_repository_supabase.dart';
import '../../../../data/models/stock_item.dart';
import '../../../../data/models/stock_movement.dart';
import '../../../../core/supabase/supabase_client.dart' show supabase;
import '../../../../core/utils/unit_conversion.dart';

/// Bulk Add Stock Page
/// Excel-like interface untuk add quantity dan update price untuk multiple items sekaligus
class BulkAddStockPage extends StatefulWidget {
  final List<StockItem> selectedItems;

  const BulkAddStockPage({
    super.key,
    required this.selectedItems,
  });

  @override
  State<BulkAddStockPage> createState() => _BulkAddStockPageState();
}

class _BulkAddStockPageState extends State<BulkAddStockPage> {
  final _stockRepo = StockRepository(supabase);
  
  // Map untuk store edited values: itemId -> {quantity: double?, price: double?}
  final Map<String, Map<String, double?>> _editedValues = {};
  // Controllers untuk text fields
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize dengan empty values dan controllers
    for (final item in widget.selectedItems) {
      _editedValues[item.id] = {
        'quantity': null,
        'price': null,
      };
      _quantityControllers[item.id] = TextEditingController();
      _priceControllers[item.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateQuantity(String itemId, String value) {
    final double? qty = value.isEmpty ? null : double.tryParse(value);
    setState(() {
      _editedValues[itemId] = {
        'quantity': qty,
        'price': _editedValues[itemId]?['price'],
      };
    });
  }

  void _updatePrice(String itemId, String value) {
    final double? price = value.isEmpty ? null : double.tryParse(value);
    setState(() {
      _editedValues[itemId] = {
        'quantity': _editedValues[itemId]?['quantity'],
        'price': price,
      };
    });
  }

  Future<void> _save() async {
    // Validate: at least one item must have quantity
    final hasAnyQuantity = _editedValues.values.any((values) => values['quantity'] != null && values['quantity']! > 0);
    
    if (!hasAnyQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila masukkan kuantiti untuk sekurang-kurangnya satu item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      int successCount = 0;
      int failureCount = 0;
      List<String> errors = [];

      for (final item in widget.selectedItems) {
        final edited = _editedValues[item.id];
        final addQuantity = edited?['quantity'];
        final newPrice = edited?['price'];

        try {
          // 1. Update price jika ada
          if (newPrice != null && newPrice > 0) {
            final input = StockItemInput(
              name: item.name,
              unit: item.unit,
              packageSize: item.packageSize,
              purchasePrice: newPrice, // Update price
              lowStockThreshold: item.lowStockThreshold,
              notes: item.notes,
              supplierId: item.supplierId,
            );
            await _stockRepo.updateStockItem(item.id, input);
          }

          // 2. Add quantity jika ada
          if (addQuantity != null && addQuantity > 0) {
            await _stockRepo.recordStockMovement(
              StockMovementInput(
                stockItemId: item.id,
                movementType: StockMovementType.replenish,
                quantityChange: addQuantity,
                reason: 'Bulk stock addition',
              ),
            );
          }

          successCount++;
        } catch (e) {
          failureCount++;
          errors.add('${item.name}: $e');
        }
      }

      if (mounted) {
        setState(() => _isSaving = false);

        // Show result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Keputusan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Berjaya: $successCount item'),
                  Text('❌ Gagal: $failureCount item'),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Ralat:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...errors.take(5).map((error) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        error,
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                    if (errors.length > 5)
                      Text('... dan ${errors.length - 5} ralat lagi'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close result dialog
                  Navigator.pop(context, true); // Close page with success
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bulk Add Stock'),
            Text(
              '${widget.selectedItems.length} item',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Masukkan kuantiti dan/atau harga baru untuk setiap item. Kosongkan jika tiada perubahan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Stok Semasa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Tambah Qty',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Harga Semasa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Harga Baru',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table rows
          Expanded(
            child: ListView.builder(
              itemCount: widget.selectedItems.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final item = widget.selectedItems[index];
                final edited = _editedValues[item.id] ?? {};
                final addQty = edited['quantity'];
                final newPrice = edited['price'];

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                    color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Item name
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${item.unit} (${item.packageSize} ${item.unit}/pkg)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Current stock
                      Expanded(
                        flex: 2,
                        child: Text(
                          UnitConversion.formatQuantity(
                            item.currentQuantity,
                            item.unit,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),

                      // Add quantity input
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _quantityControllers[item.id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '0.0',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (value) => _updateQuantity(item.id, value),
                          ),
                        ),
                      ),

                      // Current price
                      Expanded(
                        flex: 2,
                        child: Text(
                          'RM ${item.purchasePrice.toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),

                      // New price input
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _priceControllers[item.id],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: 'RM',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (value) => _updatePrice(item.id, value),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Simpan Semua'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

