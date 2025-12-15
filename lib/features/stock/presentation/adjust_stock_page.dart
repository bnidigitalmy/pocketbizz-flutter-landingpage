import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/stock_movement.dart';
import '../../../core/utils/unit_conversion.dart';

/// Adjust Stock Page - Add or remove stock with reasons
class AdjustStockPage extends StatefulWidget {
  final StockItem stockItem;

  const AdjustStockPage({super.key, required this.stockItem});

  @override
  State<AdjustStockPage> createState() => _AdjustStockPageState();
}

class _AdjustStockPageState extends State<AdjustStockPage> {
  late final StockRepository _stockRepository;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;

  bool _isAdding = true; // true = add, false = remove
  StockMovementType _selectedType = StockMovementType.replenish;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stockRepository = StockRepository(supabase);
    _quantityController = TextEditingController();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  List<StockMovementType> get _addTypes => [
        StockMovementType.purchase,
        StockMovementType.replenish,
        StockMovementType.correction,
      ];

  List<StockMovementType> get _removeTypes => [
        StockMovementType.productionUse,
        StockMovementType.waste,
        StockMovementType.returnToSupplier,
        StockMovementType.adjust,
      ];

  Future<void> _adjustStock() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Convert from pek/pcs to base unit
      final quantityInPek = double.parse(_quantityController.text);
      final quantity = quantityInPek * widget.stockItem.packageSize;
      final quantityChange = _isAdding ? quantity : -quantity;

      await _stockRepository.recordStockMovement(
        StockMovementInput(
          stockItemId: widget.stockItem.id,
          movementType: _selectedType,
          quantityChange: quantityChange,
          reason: _reasonController.text.trim().isEmpty
              ? '${_isAdding ? "Added" : "Removed"} ${quantityInPek.toStringAsFixed(0)} pek/pcs (${quantity.toStringAsFixed(2)} ${widget.stockItem.unit})'
              : _reasonController.text.trim(),
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stock adjusted successfully!'),
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
        title: const Text('Adjust Stock'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stock Item Info Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.stockItem.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Current Stock: ${UnitConversion.formatQuantity(
                            widget.stockItem.currentQuantity,
                            widget.stockItem.unit,
                          )}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Toggle (Add or Remove)
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Add Stock',
                    icon: Icons.add_circle,
                    color: Colors.green,
                    isSelected: _isAdding,
                    onTap: () {
                      setState(() {
                        _isAdding = true;
                        _selectedType = StockMovementType.replenish;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'Remove Stock',
                    icon: Icons.remove_circle,
                    color: Colors.red,
                    isSelected: !_isAdding,
                    onTap: () {
                      setState(() {
                        _isAdding = false;
                        _selectedType = StockMovementType.productionUse;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Movement Type Dropdown
            _buildMovementTypeDropdown(),
            const SizedBox(height: 16),

            // Quantity Input
            _buildQuantityInput(),
            const SizedBox(height: 16),

            // New Quantity Preview
            if (_quantityController.text.isNotEmpty)
              _buildNewQuantityPreview(),

            const SizedBox(height: 16),

            // Reason Input
            _buildReasonInput(),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _adjustStock,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAdding ? Colors.green : Colors.red,
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
                      _isAdding ? 'Add Stock' : 'Remove Stock',
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementTypeDropdown() {
    final types = _isAdding ? _addTypes : _removeTypes;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<StockMovementType>(
        value: _selectedType,
        decoration: InputDecoration(
          labelText: 'Movement Type',
          prefixIcon: Icon(
            Icons.category,
            color: _isAdding ? Colors.green : Colors.red,
          ),
          border: InputBorder.none,
        ),
        items: types.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Row(
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(type.displayName),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedType = value!);
        },
      ),
    );
  }

  Widget _buildQuantityInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Sila masukkan kuantiti';
            }
            final qty = double.tryParse(value);
            if (qty == null || qty <= 0) {
              return 'Kuantiti mesti nombor positif';
            }
            return null;
          },
          onChanged: (value) => setState(() {}), // Trigger rebuild for preview
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: _isAdding ? 'e.g., 5 (untuk 5 pek/pcs)' : 'e.g., 2 (untuk 2 pek/pcs)',
            suffixText: _isAdding ? 'pek/pcs' : 'pek/pcs',
            prefixIcon: Icon(
              Icons.scale,
              color: _isAdding ? Colors.green : Colors.red,
            ),
            helperText: _isAdding 
                ? 'Masukkan bilangan pek/pcs yang ditambah. Contoh: Jika beli 5 pek @ ${widget.stockItem.packageSize.toStringAsFixed(0)} ${widget.stockItem.unit}, masukkan: 5'
                : 'Masukkan bilangan pek/pcs yang dikurangkan.',
            helperMaxLines: 2,
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
              borderSide: BorderSide(
                color: _isAdding ? Colors.green : Colors.red,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewQuantityPreview() {
    final qtyInPek = double.tryParse(_quantityController.text);
    if (qtyInPek == null) return const SizedBox.shrink();

    // Convert from pek/pcs to base unit
    final qty = qtyInPek * widget.stockItem.packageSize;
    final newQuantity = widget.stockItem.currentQuantity + (_isAdding ? qty : -qty);
    final color = _isAdding ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Pek/pcs info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '${qtyInPek.toStringAsFixed(0)} pek/pcs (${qty.toStringAsFixed(2)} ${widget.stockItem.unit})',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quantity preview
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                UnitConversion.formatQuantity(
                  widget.stockItem.currentQuantity,
                  widget.stockItem.unit,
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.arrow_forward,
                  color: color,
                ),
              ),
              Text(
                UnitConversion.formatQuantity(
                  newQuantity,
                  widget.stockItem.unit,
                ),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: newQuantity < 0 ? Colors.red : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasonInput() {
    return TextFormField(
      controller: _reasonController,
      maxLines: 3,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please provide a reason';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Reason',
        hintText: 'Why are you adjusting this stock?',
        prefixIcon: Icon(
          Icons.comment,
          color: _isAdding ? Colors.green : Colors.red,
        ),
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
          borderSide: BorderSide(
            color: _isAdding ? Colors.green : Colors.red,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
    );
  }
}

