/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/repositories/production_batch_rpc_repository.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/models/production_batch.dart';
import '../../../data/models/product.dart';
import '../../subscription/widgets/subscription_guard.dart';

/// Record Production Page - Create new production batch
class RecordProductionPage extends StatefulWidget {
  final Product? product; // Optional - can be pre-selected

  const RecordProductionPage({super.key, this.product});

  @override
  State<RecordProductionPage> createState() => _RecordProductionPageState();
}

class _RecordProductionPageState extends State<RecordProductionPage> {
  late final ProductionRepository _productionRepo;
  late final ProductionBatchRpcRepository _productionRpc;
  late final ProductsRepositorySupabase _productsRepo;
  
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _notesController = TextEditingController();

  List<Product> _products = [];
  Product? _selectedProduct;
  DateTime _batchDate = DateTime.now();
  DateTime? _expiryDate;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _productionRepo = ProductionRepository(supabase);
    _productionRpc = ProductionBatchRpcRepository(client: supabase);
    _productsRepo = ProductsRepositorySupabase();
    _selectedProduct = widget.product;
    _loadProducts();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _batchNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      final products = await _productsRepo.getAll(limit: 100);
      setState(() {
        _products = products;
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

  Future<void> _recordProduction() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null) {
      return;
    }

    // PHASE: Subscriber Expired System - Protect record action
    await requirePro(context, 'Rekod Pengeluaran', () async {
      setState(() => _isSaving = true);

      try {
      final input = ProductionBatchInput(
        productId: _selectedProduct!.id,
        quantity: int.parse(_quantityController.text),
        batchDate: _batchDate,
        expiryDate: _expiryDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        batchNumber: _batchNumberController.text.trim().isEmpty
            ? null
            : _batchNumberController.text.trim(),
      );

        await _productionRpc.recordProductionBatch(input);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Production recorded! Stock auto-deducted ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
        if (mounted) {
          final handled = await SubscriptionEnforcement.maybePromptUpgrade(
            context,
            action: 'Rekod Pengeluaran',
            error: e,
          );
          if (handled) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    });
  }

  Future<void> _selectDate({required bool isExpiry}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isExpiry ? (_expiryDate ?? DateTime.now()) : _batchDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = date;
        } else {
          _batchDate = date;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Record Production'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Product selection
                  if (widget.product == null)
                    _buildProductDropdown(),
                  if (widget.product == null) const SizedBox(height: 16),

                  // Product info card (if selected)
                  if (_selectedProduct != null)
                    _buildProductInfoCard(),
                  if (_selectedProduct != null) const SizedBox(height: 16),

                  // Quantity
                  _buildTextField(
                    controller: _quantityController,
                    label: 'Quantity to Produce',
                    hint: 'e.g., 100',
                    icon: Icons.production_quantity_limits,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null || int.parse(value) <= 0) {
                        return 'Invalid quantity';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Batch Date
                  _buildDateField(
                    label: 'Batch Date',
                    date: _batchDate,
                    onTap: () => _selectDate(isExpiry: false),
                  ),
                  const SizedBox(height: 16),

                  // Expiry Date
                  _buildDateField(
                    label: 'Expiry Date (Optional)',
                    date: _expiryDate,
                    onTap: () => _selectDate(isExpiry: true),
                    clearable: true,
                    onClear: () => setState(() => _expiryDate = null),
                  ),
                  const SizedBox(height: 16),

                  // Batch Number
                  _buildTextField(
                    controller: _batchNumberController,
                    label: 'Batch Number (Optional)',
                    hint: 'e.g., BATCH-001',
                    icon: Icons.qr_code,
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  _buildTextField(
                    controller: _notesController,
                    label: 'Notes (Optional)',
                    hint: 'Production notes...',
                    icon: Icons.notes,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Warning card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Stock will be automatically deducted based on recipe',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Record button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _recordProduction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Record Production',
                            style: TextStyle(
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

  Widget _buildProductDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<Product>(
        value: _selectedProduct,
        decoration: InputDecoration(
          labelText: 'Select Product',
          prefixIcon: Icon(Icons.shopping_bag, color: AppColors.primary),
          border: InputBorder.none,
        ),
        items: _products.map((product) {
          return DropdownMenuItem(
            value: product,
            child: Text(product.name),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedProduct = value);
        },
        validator: (value) => value == null ? 'Please select a product' : null,
      ),
    );
  }

  Widget _buildProductInfoCard() {
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
              _selectedProduct!.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cost per unit:'),
                Text(
                  'RM ${(_selectedProduct!.costPrice ?? 0).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    bool clearable = false,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today, color: AppColors.primary),
          suffixIcon: clearable && date != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          date != null ? DateFormat('dd MMM yyyy').format(date) : 'Not set',
          style: TextStyle(
            color: date != null ? Colors.black87 : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

