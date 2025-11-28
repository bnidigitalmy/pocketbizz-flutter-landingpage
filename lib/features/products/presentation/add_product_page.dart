import 'package:flutter/material.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/api/models/product_models.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ProductsRepositorySupabase();

  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController(text: 'pcs');
  final _salePriceController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _salePriceController.dispose();
    _costPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final product = ProductCreate(
        sku: _skuController.text.trim(),
        name: _nameController.text.trim(),
        unit: _unitController.text.trim(),
        costPrice: double.parse(_costPriceController.text),
        salePrice: double.parse(_salePriceController.text),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );

      await _repo.createProduct(product as Product);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // SKU
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(
                labelText: 'SKU *',
                hintText: 'e.g., PROD-001',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Product Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g., Chocolate Cake',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Category
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                hintText: 'e.g., Cakes, Pastries',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
            ),
            const SizedBox(height: 16),

            // Unit
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                hintText: 'e.g., pcs, kg, box',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.straighten),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Sale Price
            TextFormField(
              controller: _salePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sale Price (RM) *',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Cost Price
            TextFormField(
              controller: _costPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cost Price (RM) *',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money_off),
              ),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Product details...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 24),

            // Profit Margin Preview
            if (_salePriceController.text.isNotEmpty &&
                _costPriceController.text.isNotEmpty)
              _buildProfitPreview(),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _loading ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Create Product',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitPreview() {
    final salePrice = double.tryParse(_salePriceController.text) ?? 0;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0;
    final profit = salePrice - costPrice;
    final margin = costPrice > 0 ? (profit / costPrice * 100) : 0;

    return Card(
      color: profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profit Preview',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Profit per unit:'),
                Text(
                  'RM${profit.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: profit >= 0 ? Colors.green : Colors.red,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Profit margin:'),
                Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: profit >= 0 ? Colors.green : Colors.red,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

