import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/product.dart';
import '../../../../data/models/production_preview.dart';
import '../../../../data/repositories/production_repository_supabase.dart';
import '../../../../data/repositories/shopping_cart_repository_supabase.dart';
import '../../../../data/models/production_batch.dart';

/// 3-Step Production Planning Dialog
class ProductionPlanningDialog extends StatefulWidget {
  final List<Product> products;
  final ProductionRepository productionRepo;
  final ShoppingCartRepository cartRepo;
  final VoidCallback onSuccess;

  const ProductionPlanningDialog({
    super.key,
    required this.products,
    required this.productionRepo,
    required this.cartRepo,
    required this.onSuccess,
  });

  @override
  State<ProductionPlanningDialog> createState() => _ProductionPlanningDialogState();
}

class _ProductionPlanningDialogState extends State<ProductionPlanningDialog> {
  String _step = 'select'; // select, preview, confirm
  Product? _selectedProduct;
  int _quantity = 1;
  DateTime _batchDate = DateTime.now();
  DateTime? _expiryDate;
  String _expiryInputType = 'days';
  String _shelfLifeDays = '';
  String _notes = '';
  ProductionPlan? _productionPlan;
  bool _isLoading = false;

  void _calculateExpiryDate() {
    if (_shelfLifeDays.isEmpty || int.tryParse(_shelfLifeDays) == null) {
      setState(() => _expiryDate = null);
      return;
    }

    final days = int.parse(_shelfLifeDays);
    if (days <= 0) {
      setState(() => _expiryDate = null);
      return;
    }

    final date = DateTime(_batchDate.year, _batchDate.month, _batchDate.day);
    final expiry = date.add(Duration(days: days));
    setState(() => _expiryDate = expiry);
  }

  Future<void> _handlePreview() async {
    if (_selectedProduct == null || _quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila pilih produk dan masukkan kuantiti'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedProduct == null) return;
      
      final plan = await widget.productionRepo.previewProductionPlan(
        productId: _selectedProduct!.id,
        quantity: _quantity,
      );

      setState(() {
        _productionPlan = plan;
        _step = 'preview';
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

  Future<void> _handleAddToShoppingList() async {
    if (_productionPlan == null) return;
    
    final insufficientItems = _productionPlan!.materialsNeeded
        .where((m) => !m.isSufficient)
        .toList();

    if (insufficientItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tiada bahan yang perlu ditambah'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Add items one by one to ensure they're added properly
      int successCount = 0;
      int failCount = 0;
      
      for (var item in insufficientItems) {
        try {
          await widget.cartRepo.addToCart(
            stockItemId: item.stockItemId,
            shortageQty: item.shortage,
            notes: 'Untuk produksi ${_productionPlan?.product.name ?? 'Unknown'}',
            priority: 'high', // Set priority to high for production items
          );
          successCount++;
        } catch (e) {
          failCount++;
          debugPrint('Error adding ${item.stockItemName}: $e');
        }
      }

      setState(() => _isLoading = false);

      if (mounted) {
        if (successCount > 0) {
          // Show success dialog with option to navigate
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 32),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Bahan Ditambah!'),
                  ),
                ],
              ),
              content: Text(
                failCount > 0
                    ? '$successCount bahan berjaya ditambah ke senarai belian.\n$failCount bahan gagal ditambah.'
                    : '✅ $successCount bahan berjaya ditambah ke senarai belian.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kekal di Sini'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Close success dialog
                    Navigator.pop(context); // Close production dialog
                    // Navigate to shopping list - it will auto-refresh on initState
                    await Navigator.pushNamed(context, '/shopping-list');
                    // Refresh production page when returning
                    widget.onSuccess();
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Lihat Senarai Belian'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Gagal menambah bahan: $failCount item gagal'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleConfirm() async {
    // Enforce stock check - prevent production if stock is insufficient
    if (_productionPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila preview produksi terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_productionPlan!.allStockSufficient) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Stok tidak mencukupi untuk produksi ini.\n'
            'Sila beli bahan terlebih dahulu sebelum meneruskan produksi.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (_selectedProduct == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final input = ProductionBatchInput(
        productId: _selectedProduct!.id,
        quantity: _quantity * _selectedProduct!.unitsPerBatch,
        batchDate: _batchDate,
        expiryDate: _expiryDate,
        notes: _notes.trim().isEmpty ? null : _notes.trim(),
      );

      await widget.productionRepo.recordProductionBatch(input);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Produksi telah direkod dan stok telah dikurangkan.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
                  const Icon(Icons.restaurant_menu, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _step == 'select'
                              ? 'Rancang Produksi Baru'
                              : _step == 'preview'
                                  ? 'Preview Bahan Diperlukan'
                                  : 'Pengesahan Produksi',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _step == 'select'
                              ? 'Pilih produk dan kuantiti yang ingin dihasilkan'
                              : _step == 'preview'
                                  ? 'Semak keperluan bahan dan status stok'
                                  : 'Sahkan maklumat produksi',
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _step == 'select'
                    ? _buildSelectStep()
                    : _step == 'preview'
                        ? _buildPreviewStep()
                        : _buildConfirmStep(),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: _buildFooterActions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectStep() {
    final totalUnits = _selectedProduct != null
        ? _quantity * _selectedProduct!.unitsPerBatch
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Selection
        DropdownButtonFormField<Product>(
          value: _selectedProduct,
          decoration: InputDecoration(
            labelText: 'Produk',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.inventory_2),
          ),
          items: widget.products.map<DropdownMenuItem<Product>>((product) {
            return DropdownMenuItem<Product>(
              value: product,
              child: Text(product.name),
            );
          }).toList(),
          onChanged: (product) {
            setState(() => _selectedProduct = product);
          },
        ),
        const SizedBox(height: 20),

        // Quantity Input
        TextFormField(
          initialValue: _quantity.toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Kuantiti (batch)',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.numbers),
            helperText: _selectedProduct != null
                ? '$_quantity batch = $totalUnits unit'
                : null,
          ),
          onChanged: (value) {
            final qty = int.tryParse(value) ?? 1;
            setState(() => _quantity = qty < 1 ? 1 : qty);
          },
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    if (_productionPlan == null) {
      return const Center(child: Text('Error: Production plan not available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Production Info Card
        Card(
          color: AppColors.primary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Maklumat Produksi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Produk', _productionPlan!.product.name),
                _buildInfoRow(
                  'Kuantiti',
                  '${_productionPlan!.quantity} batch (${_productionPlan!.totalUnits} unit)',
                ),
                _buildInfoRow(
                  'Anggaran Kos',
                  'RM ${_productionPlan!.totalProductionCost.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Stock Status Alert
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _productionPlan!.allStockSufficient
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _productionPlan!.allStockSufficient
                  ? Colors.green
                  : Colors.red,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _productionPlan!.allStockSufficient
                    ? Icons.check_circle
                    : Icons.warning,
                color: _productionPlan!.allStockSufficient
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _productionPlan!.allStockSufficient
                      ? 'Stok Mencukupi - Boleh teruskan produksi'
                      : 'Stok Tidak Mencukupi - Sila beli bahan terlebih dahulu',
                  style: TextStyle(
                    color: _productionPlan!.allStockSufficient
                        ? Colors.green[700]
                        : Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Materials List
        const Text(
          'Bahan Diperlukan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ..._productionPlan!.materialsNeeded.map((material) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: material.isSufficient ? null : Colors.red.withOpacity(0.05),
            child: ListTile(
              leading: Icon(
                material.isSufficient ? Icons.check_circle : Icons.cancel,
                color: material.isSufficient ? Colors.green : Colors.red,
              ),
              title: Text(
                material.stockItemName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Diperlukan: ${material.quantityNeeded.toStringAsFixed(2)} ${material.usageUnit}'),
                  Text('Stok: ${material.currentStock.toStringAsFixed(2)} ${material.stockUnit}'),
                  if (!material.isSufficient)
                    Text(
                      'Kurang: ${material.shortage.toStringAsFixed(2)} ${material.stockUnit}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConfirmStep() {
    if (_productionPlan == null || _selectedProduct == null) {
      return const Center(child: Text('Error: Production plan or product not available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Batch Date
        TextFormField(
          initialValue: DateFormat('yyyy-MM-dd').format(_batchDate),
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Tarikh Produksi',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _batchDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() {
                _batchDate = date;
                if (_expiryInputType == 'days' && _shelfLifeDays.isNotEmpty) {
                  _calculateExpiryDate();
                }
              });
            }
          },
        ),
        const SizedBox(height: 20),

        // Expiry Date Input Type
        const Text(
          'Tarikh Luput (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Tempoh (Hari)'),
                value: 'days',
                groupValue: _expiryInputType,
                onChanged: (value) {
                  setState(() {
                    _expiryInputType = value!;
                    _expiryDate = null;
                    _shelfLifeDays = '';
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Tarikh Spesifik'),
                value: 'date',
                groupValue: _expiryInputType,
                onChanged: (value) {
                  setState(() {
                    _expiryInputType = value!;
                    _shelfLifeDays = '';
                  });
                },
              ),
            ),
          ],
        ),

        // Days Input
        if (_expiryInputType == 'days') ...[
          TextFormField(
            initialValue: _shelfLifeDays,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Tempoh (Hari)',
              hintText: 'Contoh: 7 (7 hari dari tarikh produksi)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.calendar_view_day),
            ),
            onChanged: (value) {
              setState(() => _shelfLifeDays = value);
              _calculateExpiryDate();
            },
          ),
          if (_expiryDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tarikh luput: ${_expiryDate != null ? DateFormat('dd MMMM yyyy').format(_expiryDate!) : 'N/A'}',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],

        // Date Input
        if (_expiryInputType == 'date') ...[
          TextFormField(
            initialValue: _expiryDate != null
                ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
                : '',
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Tarikh Luput',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.event),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _expiryDate ?? _batchDate.add(const Duration(days: 7)),
                firstDate: _batchDate,
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _expiryDate = date);
              }
            },
          ),
        ],
        const SizedBox(height: 20),

        // Notes
        TextFormField(
          initialValue: _notes,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Nota (Optional)',
            hintText: 'Catatan tambahan untuk batch ini...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.note),
          ),
          onChanged: (value) => setState(() => _notes = value),
        ),
        const SizedBox(height: 20),

        // Summary Card
        Card(
          color: AppColors.primary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Ringkasan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Produk', _productionPlan!.product.name),
                _buildInfoRow(
                  'Kuantiti',
                  '${_productionPlan!.quantity} batch (${_productionPlan!.totalUnits} unit)',
                ),
                _buildInfoRow(
                  'Jumlah Kos',
                  'RM ${_productionPlan!.totalProductionCost.toStringAsFixed(2)}',
                ),
                _buildInfoRow(
                  'Bahan',
                  '${_productionPlan!.materialsNeeded.length} item',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Warning Alert
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stok bahan akan dikurangkan secara automatik selepas pengesahan.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    // Responsive button layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 500;
        
        if (_step == 'select') {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading || _selectedProduct == null
                      ? null
                      : _handlePreview,
                  style: ElevatedButton.styleFrom(
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Preview Bahan'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          );
        }
        
        if (_step == 'preview') {
          if (isWide) {
            // Wide layout: buttons in a row
            return Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() => _step = 'select');
                          },
                    child: const Text('Kembali'),
                  ),
                ),
                if (!_productionPlan!.allStockSufficient) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleAddToShoppingList,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Tambah ke Senarai'),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _productionPlan!.allStockSufficient
                        ? () => setState(() => _step = 'confirm')
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Teruskan'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Narrow layout: buttons stacked
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() => _step = 'select');
                              },
                        child: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _productionPlan!.allStockSufficient
                            ? () => setState(() => _step = 'confirm')
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Teruskan'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_productionPlan!.allStockSufficient) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleAddToShoppingList,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Tambah ke Senarai'),
                    ),
                  ),
                ],
              ],
            );
          }
        }
        
        if (_step == 'confirm') {
          return Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() => _step = 'preview');
                        },
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 20),
                            SizedBox(width: 8),
                            Text('Sahkan Produksi'),
                          ],
                        ),
                ),
              ),
            ],
          );
        }
        
        return const SizedBox.shrink();
      },
    );
  }
}

