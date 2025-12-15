import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/supabase/supabase_client.dart' show supabase;
import '../../../../data/repositories/stock_repository_supabase.dart';
import '../../../../data/models/stock_item.dart';
import '../../../../data/models/stock_item_batch.dart';

/// Dialog untuk add new batch
class AddBatchDialog extends StatefulWidget {
  final StockItem stockItem;

  const AddBatchDialog({super.key, required this.stockItem});

  @override
  State<AddBatchDialog> createState() => _AddBatchDialogState();
}

class _AddBatchDialogState extends State<AddBatchDialog> {
  late final StockRepository _stockRepository;
  final _formKey = GlobalKey<FormState>();
  
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _packageSizeController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _purchaseDate = DateTime.now();
  DateTime? _expiryDate;
  bool _hasExpiryDate = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);
    // Pre-fill dengan stock item values
    _packageSizeController.text = widget.stockItem.packageSize.toStringAsFixed(2);
    _purchasePriceController.text = widget.stockItem.purchasePrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _packageSizeController.dispose();
    _batchNumberController.dispose();
    _supplierNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isExpiry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? (_expiryDate ?? DateTime.now()) : _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _purchaseDate = picked;
        }
      });
    }
  }

  void _calculateCostPerUnit() {
    if (_purchasePriceController.text.isNotEmpty &&
        _packageSizeController.text.isNotEmpty) {
      final price = double.tryParse(_purchasePriceController.text) ?? 0;
      final size = double.tryParse(_packageSizeController.text) ?? 1;
      final costPerUnit = size > 0 ? price / size : 0;
      
      // Update UI to show calculated cost (optional)
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Convert from pek/pcs to base unit
      final quantityInPek = double.parse(_quantityController.text);
      final purchasePrice = double.parse(_purchasePriceController.text);
      final packageSize = double.parse(_packageSizeController.text);
      
      // Convert pek/pcs to base unit
      final quantity = quantityInPek * packageSize;

      if (quantityInPek <= 0) {
        throw Exception('Quantity must be greater than 0');
      }
      if (purchasePrice <= 0) {
        throw Exception('Purchase price must be greater than 0');
      }
      if (packageSize <= 0) {
        throw Exception('Package size must be greater than 0');
      }

      final input = StockItemBatchInput(
        stockItemId: widget.stockItem.id,
        quantity: quantity, // Base unit quantity
        purchaseDate: _purchaseDate,
        expiryDate: _hasExpiryDate ? _expiryDate : null,
        purchasePrice: purchasePrice,
        packageSize: packageSize,
        batchNumber: _batchNumberController.text.isEmpty
            ? null
            : _batchNumberController.text,
        supplierName: _supplierNameController.text.isEmpty
            ? null
            : _supplierNameController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        recordMovement: true,
      );

      await _stockRepository.createStockItemBatch(input);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Batch created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final costPerUnit = _purchasePriceController.text.isNotEmpty &&
            _packageSizeController.text.isNotEmpty
        ? (double.tryParse(_purchasePriceController.text) ?? 0) /
            (double.tryParse(_packageSizeController.text) ?? 1)
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tambah Batch Baru',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.stockItem.name,
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

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quantity (in pek/pcs)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _quantityController,
                            decoration: InputDecoration(
                              labelText: 'Quantity *',
                              hintText: 'e.g., 5 (untuk 5 pek/pcs)',
                              suffixText: 'pek/pcs',
                              prefixIcon: const Icon(Icons.inventory),
                              helperText: 'Masukkan bilangan pek/pcs yang dibeli.',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Sila masukkan quantity';
                              }
                              if (double.tryParse(value) == null ||
                                  double.parse(value) <= 0) {
                                return 'Quantity mesti lebih daripada 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Contoh: Jika beli 5 pek @ ${widget.stockItem.packageSize.toStringAsFixed(0)} ${widget.stockItem.unit} setiap satu, masukkan: 5 (untuk 5 pek).',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[900],
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Purchase Date
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Purchase Date *',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy').format(_purchaseDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Expiry Date Toggle
                      Row(
                        children: [
                          Checkbox(
                            value: _hasExpiryDate,
                            onChanged: (value) {
                              setState(() {
                                _hasExpiryDate = value ?? false;
                                if (!_hasExpiryDate) _expiryDate = null;
                              });
                            },
                          ),
                          const Text('Ada Expiry Date'),
                        ],
                      ),

                      // Expiry Date
                      if (_hasExpiryDate) ...[
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date *',
                              prefixIcon: Icon(Icons.event_busy),
                            ),
                            child: Text(
                              _expiryDate != null
                                  ? DateFormat('dd MMM yyyy').format(_expiryDate!)
                                  : 'Pilih tarikh',
                              style: TextStyle(
                                fontSize: 16,
                                color: _expiryDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Purchase Price & Package Size
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _purchasePriceController,
                              decoration: const InputDecoration(
                                labelText: 'Purchase Price *',
                                hintText: 'e.g., 50.00',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) {
                                setState(() => _calculateCostPerUnit());
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _packageSizeController,
                              decoration: InputDecoration(
                                labelText: 'Package Size *',
                                hintText: 'e.g., 1',
                                suffixText: widget.stockItem.unit,
                                prefixIcon: const Icon(Icons.scale),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (_) {
                                setState(() => _calculateCostPerUnit());
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0) {
                                  return 'Invalid';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      // Cost per Unit (read-only display)
                      if (costPerUnit > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Cost per ${widget.stockItem.unit}: RM ${costPerUnit.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Batch Number (optional)
                      TextFormField(
                        controller: _batchNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Batch Number (Optional)',
                          hintText: 'e.g., BATCH-001',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Supplier Name (optional)
                      TextFormField(
                        controller: _supplierNameController,
                        decoration: const InputDecoration(
                          labelText: 'Supplier Name (Optional)',
                          hintText: 'e.g., ABC Supplier',
                          prefixIcon: Icon(Icons.store),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes (optional)
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'Additional notes...',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Tambah Batch'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
