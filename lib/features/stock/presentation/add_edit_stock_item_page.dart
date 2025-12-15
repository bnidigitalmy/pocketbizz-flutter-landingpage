import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/stock_movement.dart';
import '../../../core/utils/unit_conversion.dart';

/// Add/Edit Stock Item Page
class AddEditStockItemPage extends StatefulWidget {
  final StockItem? stockItem;

  const AddEditStockItemPage({super.key, this.stockItem});

  bool get isEditing => stockItem != null;

  @override
  State<AddEditStockItemPage> createState() => _AddEditStockItemPageState();
}

class _AddEditStockItemPageState extends State<AddEditStockItemPage> {
  late final StockRepository _stockRepository;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _packageSizeController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _lowStockThresholdController;
  late final TextEditingController _notesController;
  late final TextEditingController _initialQuantityController;
  late final TextEditingController _reasonController;

  String _selectedUnit = Units.gram;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);

    // Initialize controllers
    _nameController = TextEditingController(text: widget.stockItem?.name ?? '');
    _packageSizeController = TextEditingController(
      text: widget.stockItem?.packageSize.toString() ?? '',
    );
    _purchasePriceController = TextEditingController(
      text: widget.stockItem?.purchasePrice.toString() ?? '',
    );
    // Convert low stock threshold from base unit to pek/pcs for display
    final lowStockInPek = widget.stockItem != null && widget.stockItem!.packageSize > 0
        ? (widget.stockItem!.lowStockThreshold / widget.stockItem!.packageSize).toStringAsFixed(0)
        : '5';
    _lowStockThresholdController = TextEditingController(text: lowStockInPek);
    _notesController = TextEditingController(text: widget.stockItem?.notes ?? '');
    _initialQuantityController = TextEditingController();
    _reasonController = TextEditingController();

    if (widget.stockItem != null) {
      _selectedUnit = widget.stockItem!.unit;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _packageSizeController.dispose();
    _purchasePriceController.dispose();
    _lowStockThresholdController.dispose();
    _notesController.dispose();
    _initialQuantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveStockItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final packageSize = double.parse(_packageSizeController.text);
      final lowStockInPek = double.parse(_lowStockThresholdController.text);
      // Convert from pek/pcs to base unit
      final lowStockThreshold = lowStockInPek * packageSize;
      
      final input = StockItemInput(
        name: _nameController.text.trim(),
        unit: _selectedUnit,
        packageSize: packageSize,
        purchasePrice: double.parse(_purchasePriceController.text),
        lowStockThreshold: lowStockThreshold,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (widget.isEditing) {
        // Update existing item
        await _stockRepository.updateStockItem(widget.stockItem!.id, input);
      } else {
        // Create new item
        final newItem = await _stockRepository.createStockItem(input);

        // If initial quantity provided, add it (convert from pek/pcs to base unit)
        final initialQtyInPek = _initialQuantityController.text.trim();
        if (initialQtyInPek.isNotEmpty && double.parse(initialQtyInPek) > 0) {
          final initialQty = double.parse(initialQtyInPek) * packageSize;
          await _stockRepository.recordStockMovement(
            StockMovementInput(
              stockItemId: newItem.id,
              movementType: StockMovementType.purchase,
              quantityChange: initialQty,
              reason: _reasonController.text.trim().isEmpty
                  ? 'Initial stock'
                  : _reasonController.text.trim(),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Stock item updated!'
                  : 'Stock item added!',
            ),
            backgroundColor: Colors.green,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Stock Item' : 'Add Stock Item'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Item Name
            _buildTextField(
              controller: _nameController,
              label: 'Item Name',
              hint: 'e.g., Tepung Gandum, Gula Pasir',
              icon: Icons.inventory_2,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter item name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Unit Selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUnitDropdown(),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber[900]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Unit = Unit measurement yang digunakan semasa beli/order dari supplier '
                          '(kg, gram, liter, pcs, etc.)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Package Size & Purchase Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _packageSizeController,
                        label: 'Package Size',
                        hint: 'e.g., 1 atau 500',
                        icon: Icons.scale,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _purchasePriceController,
                        label: 'Purchase Price (RM)',
                        hint: 'e.g., 8.00',
                        icon: Icons.attach_money,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Penjelasan:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Package Size = Saiz satu pek/pcs yang dibeli\n'
                              '  Contoh: 1 untuk 1kg, 500 untuk 500gram\n'
                              '• Purchase Price = Harga untuk satu pek/pcs\n'
                              '  Contoh: RM 8.00 untuk 1 pek 1kg\n'
                              '• Cost per Unit = Auto-calculated (Harga ÷ Saiz)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[900],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Cost per unit calculation
            if (_packageSizeController.text.isNotEmpty &&
                _purchasePriceController.text.isNotEmpty)
              _buildCostPerUnitInfo(),

            const SizedBox(height: 16),

            // Low Stock Threshold (in pek/pcs)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _lowStockThresholdController,
                  label: 'Low Stock Alert Threshold',
                  hint: 'e.g., 2 (untuk 2 pek/pcs)',
                  icon: Icons.warning_amber_rounded,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Mesti nombor positif';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Masukkan bilangan pek/pcs untuk alert. '
                          'Contoh: Jika package size = ${_packageSizeController.text.isEmpty ? "500" : _packageSizeController.text} $_selectedUnit, '
                          'masukkan "2" untuk alert bila tinggal 2 pek.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[900],
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

            // Notes
            _buildTextField(
              controller: _notesController,
              label: 'Notes (Optional)',
              hint: 'Additional information...',
              icon: Icons.notes,
              maxLines: 3,
            ),

            // Initial Quantity (only for new items)
            if (!widget.isEditing) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Initial Stock (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add initial quantity if you already have this item in stock',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _initialQuantityController,
                    label: 'Initial Quantity',
                    hint: 'e.g., 5 (untuk 5 pek/pcs)',
                    icon: Icons.add_box,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            () {
                              final packageSize = _packageSizeController.text.isEmpty 
                                  ? 1.0 
                                  : (double.tryParse(_packageSizeController.text) ?? 1.0);
                              return 'Masukkan bilangan pek/pcs yang ada. '
                                  'Contoh: Jika beli 5 pek @ ${packageSize.toStringAsFixed(0)} $_selectedUnit setiap satu, '
                                  'masukkan: 5 (untuk 5 pek).';
                            }(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[900],
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

              _buildTextField(
                controller: _reasonController,
                label: 'Reason (Optional)',
                hint: 'e.g., Initial stock from inventory',
                icon: Icons.comment,
                maxLines: 2,
              ),
            ],

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveStockItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                  : Text(
                      widget.isEditing ? 'Update Item' : 'Add Item',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedUnit,
        decoration: InputDecoration(
          labelText: 'Unit of Measurement',
          prefixIcon: Icon(Icons.straighten, color: AppColors.primary),
          border: InputBorder.none,
        ),
        items: Units.flatList.map((unit) {
          final category = UnitConversion.getUnitCategory(unit) ?? 'Other';
          return DropdownMenuItem(
            value: unit,
            child: Text('$unit ($category)'),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedUnit = value!);
        },
      ),
    );
  }

  Widget _buildCostPerUnitInfo() {
    final packageSize = double.tryParse(_packageSizeController.text);
    final purchasePrice = double.tryParse(_purchasePriceController.text);

    if (packageSize != null && purchasePrice != null && packageSize > 0) {
      final costPerUnit = purchasePrice / packageSize;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calculate, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Cost per $_selectedUnit: RM ${costPerUnit.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

