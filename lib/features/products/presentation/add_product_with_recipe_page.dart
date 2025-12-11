import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/unit_conversion.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/repositories/categories_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/recipes_repository_supabase.dart';

/// Add Product with Recipe & Auto-Cost Calculation
/// Mobile-first, non-techy friendly, Malay language
class AddProductWithRecipePage extends StatefulWidget {
  const AddProductWithRecipePage({super.key});

  @override
  State<AddProductWithRecipePage> createState() => _AddProductWithRecipePageState();
}

class _AddProductWithRecipePageState extends State<AddProductWithRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _stockRepo = StockRepository(supabase);
  final _categoriesRepo = CategoriesRepositorySupabase();
  final _productsRepo = ProductsRepositorySupabase();
  final _recipesRepo = RecipesRepositorySupabase();

  // Product Info
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  
  // Production Costs
  final _unitsPerBatchController = TextEditingController(text: '1');
  final _labourCostController = TextEditingController(text: '0');
  final _otherCostsController = TextEditingController(text: '0');
  final _packagingCostController = TextEditingController(text: '0');
  final _sellingPriceController = TextEditingController(text: '0');

  // Data
  List<StockItem> _stockItems = [];
  List<Category> _categories = [];
  List<RecipeItemInput> _recipeItems = [RecipeItemInput()];
  
  bool _isLoading = true;
  bool _isSaving = false;

  // Cost calculations
  double _materialsCost = 0.0;
  double _totalPackagingCost = 0.0;
  double _totalCostPerBatch = 0.0;
  double _costPerUnit = 0.0;
  int _suggestedMarginPercent = 30;
  double _suggestedSellingPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Listen to changes for live cost calculation
    _unitsPerBatchController.addListener(_calculateCosts);
    _labourCostController.addListener(_calculateCosts);
    _otherCostsController.addListener(_calculateCosts);
    _packagingCostController.addListener(_calculateCosts);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _imageUrlController.dispose();
    _unitsPerBatchController.dispose();
    _labourCostController.dispose();
    _otherCostsController.dispose();
    _packagingCostController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final stockItems = await _stockRepo.getAllStockItems();
      final categories = await _categoriesRepo.getAll();
      
      setState(() {
        _stockItems = stockItems;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _calculateCosts() {
    double materialsCost = 0.0;

    // Calculate materials cost from recipe items
    for (final item in _recipeItems) {
      if (item.stockItemId != null && item.quantityController.text.isNotEmpty) {
        final stockItem = _stockItems.firstWhere(
          (s) => s.id == item.stockItemId,
          orElse: () => _stockItems.first,
        );
        
        final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
        final packagePrice = stockItem.purchasePrice;
        final packageSize = stockItem.packageSize;
        final usageUnit = item.usageUnit ?? stockItem.unit;
        
        // Unit price (price per single unit)
        final unitPrice = packagePrice / packageSize;
        
        // Convert quantity to stock unit
        final convertedQuantity = UnitConversion.convert(
          quantity: quantity,
          fromUnit: usageUnit,
          toUnit: stockItem.unit,
        );
        
        // Cost = converted quantity × unit price
        materialsCost += convertedQuantity * unitPrice;
      }
    }

    final unitsPerBatch = int.tryParse(_unitsPerBatchController.text) ?? 1;
    final labourCost = double.tryParse(_labourCostController.text) ?? 0.0;
    final otherCosts = double.tryParse(_otherCostsController.text) ?? 0.0;
    final packagingCost = double.tryParse(_packagingCostController.text) ?? 0.0;
    
    // Total packaging = packaging per unit × units per batch
    final totalPackagingCost = packagingCost * unitsPerBatch;
    
    // Total cost per batch
    final totalCostPerBatch = materialsCost + labourCost + otherCosts + totalPackagingCost;
    
    // Cost per unit
    final costPerUnit = unitsPerBatch > 0 ? totalCostPerBatch / unitsPerBatch : 0.0;

    // Suggested margin based on cost
    int suggestedMarginPercent = 30;
    if (costPerUnit < 1) suggestedMarginPercent = 50;
    else if (costPerUnit < 3) suggestedMarginPercent = 40;
    else if (costPerUnit < 5) suggestedMarginPercent = 35;
    
    final suggestedSellingPrice = costPerUnit * (1 + suggestedMarginPercent / 100);

    setState(() {
      _materialsCost = materialsCost;
      _totalPackagingCost = totalPackagingCost;
      _totalCostPerBatch = totalCostPerBatch;
      _costPerUnit = costPerUnit;
      _suggestedMarginPercent = suggestedMarginPercent;
      _suggestedSellingPrice = suggestedSellingPrice;
    });
  }

  void _addRecipeItem() {
    setState(() {
      _recipeItems.add(RecipeItemInput());
    });
  }

  void _removeRecipeItem(int index) {
    if (_recipeItems.length > 1) {
      setState(() {
        _recipeItems[index].dispose();
        _recipeItems.removeAt(index);
      });
      _calculateCosts();
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    final hasValidRecipe = _recipeItems.any((item) => 
      item.stockItemId != null && 
      double.tryParse(item.quantityController.text) != null &&
      double.tryParse(item.quantityController.text)! > 0
    );
    if (!hasValidRecipe) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila tambah sekurang-kurangnya satu bahan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Create product first
      final now = DateTime.now();
      final product = Product(
        id: '', // Will be generated by database
        businessOwnerId: '', // Will be set by repository
        sku: 'PROD-${DateTime.now().millisecondsSinceEpoch}', // Auto-generate SKU
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        unit: 'pcs', // Default unit
        salePrice: double.parse(_sellingPriceController.text),
        costPrice: _costPerUnit,
        description: null,
        imageUrl: _imageUrlController.text.trim().isEmpty 
            ? null 
            : _imageUrlController.text.trim(),
        unitsPerBatch: int.parse(_unitsPerBatchController.text),
        labourCost: double.parse(_labourCostController.text),
        otherCosts: double.parse(_otherCostsController.text),
        packagingCost: double.parse(_packagingCostController.text),
        materialsCost: _materialsCost,
        totalCostPerBatch: _totalCostPerBatch,
        costPerUnit: _costPerUnit,
        createdAt: now,
        updatedAt: now,
      );

      final createdProduct = await _productsRepo.createProduct(product);

      // 2. Create recipe
      final recipe = await _recipesRepo.createRecipe(
        productId: createdProduct.id,
        name: '${createdProduct.name} Recipe',
        yieldQuantity: double.parse(_unitsPerBatchController.text),
        yieldUnit: 'pcs',
        isActive: true,
      );

      // 3. Create recipe items
      for (final item in _recipeItems) {
        final quantity = double.tryParse(item.quantityController.text);
        if (item.stockItemId != null && quantity != null && quantity > 0) {
          await _recipesRepo.addRecipeItem(
            recipeId: recipe.id,
            stockItemId: item.stockItemId!,
            quantityNeeded: quantity,
            usageUnit: item.usageUnit ?? 'pcs',
          );
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk & resepi berjaya ditambah!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tambah Produk & Resepi'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calculate, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Kira Kos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pilih bahan, sistem kira kos automatik',
                                style: TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // SECTION: Product Info
                  _buildSectionHeader('Maklumat Produk', Icons.shopping_bag),
                  const SizedBox(height: 12),
                  
                  _buildTextField(
                    controller: _nameController,
                    label: 'Nama Produk',
                    hint: 'cth: Cream Puff',
                    icon: Icons.label,
                    validator: (v) => v?.isEmpty ?? true ? 'Nama produk diperlukan' : null,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTextField(
                    controller: _categoryController,
                    label: 'Kategori',
                    hint: 'cth: Kuih, Kek, Minuman',
                    icon: Icons.category,
                    validator: (v) => v?.isEmpty ?? true ? 'Kategori diperlukan' : null,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // SECTION: Recipe Items
                  _buildSectionHeader('Bahan-Bahan (Resepi)', Icons.receipt_long),
                  const SizedBox(height: 12),
                  
                  ..._recipeItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildRecipeItemCard(index, item);
                  }).toList(),
                  
                  const SizedBox(height: 12),
                  
                  // Add Recipe Item Button
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addRecipeItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Bahan'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // SECTION: Production Costs
                  _buildSectionHeader('Kos Pengeluaran', Icons.factory),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _unitsPerBatchController,
                          label: 'Unit Per Batch',
                          hint: '1',
                          icon: Icons.numbers,
                          keyboardType: TextInputType.number,
                          helperText: 'Berapa unit dihasilkan',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _packagingCostController,
                          label: 'Packaging/Unit (RM)',
                          hint: '0',
                          icon: Icons.inventory_2,
                          keyboardType: TextInputType.number,
                          helperText: 'Kos bekas per unit',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _labourCostController,
                          label: 'Kos Buruh (RM)',
                          hint: '0',
                          icon: Icons.person,
                          keyboardType: TextInputType.number,
                          helperText: 'Upah per batch',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _otherCostsController,
                          label: 'Kos Lain (RM)',
                          hint: '0',
                          icon: Icons.bolt,
                          keyboardType: TextInputType.number,
                          helperText: 'Gas, elektrik, etc',
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // SECTION: Cost Summary
                  _buildCostSummaryCard(),
                  
                  const SizedBox(height: 24),
                  
                  // SECTION: Selling Price
                  _buildSellingPriceSection(),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProduct,
                      icon: _isSaving 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save, size: 24),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : 'Simpan Produk',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildRecipeItemCard(int index, RecipeItemInput item) {
    final selectedStock = item.stockItemId != null
        ? _stockItems.firstWhere((s) => s.id == item.stockItemId, orElse: () => _stockItems.first)
        : null;
    
    final compatibleUnits = selectedStock != null
        ? getCompatibleUnits(selectedStock.unit)
        : <String>[];

    // Calculate cost for this item
    double itemCost = 0.0;
    if (selectedStock != null && item.quantityController.text.isNotEmpty) {
      final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
      if (quantity > 0) {
        final unitPrice = selectedStock.purchasePrice / selectedStock.packageSize;
        final usageUnit = item.usageUnit ?? selectedStock.unit;
        final convertedQty = UnitConversion.convert(
          quantity: quantity,
          fromUnit: usageUnit,
          toUnit: selectedStock.unit,
        );
        itemCost = convertedQty * unitPrice;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bahan ${index + 1}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_recipeItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeRecipeItem(index),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Stock Item Dropdown
          DropdownButtonFormField<String>(
            value: item.stockItemId,
            decoration: InputDecoration(
              labelText: 'Pilih Bahan',
              prefixIcon: const Icon(Icons.inventory),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _stockItems.map((stock) {
              final pricePerUnit = stock.purchasePrice / stock.packageSize;
              return DropdownMenuItem(
                value: stock.id,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(stock.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      '${stock.packageSize}${stock.unit} @ RM${stock.purchasePrice.toStringAsFixed(2)} (RM${pricePerUnit.toStringAsFixed(2)}/${stock.unit})',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                item.stockItemId = value;
                if (value != null) {
                  final stock = _stockItems.firstWhere((s) => s.id == value);
                  item.usageUnit = stock.unit;
                }
              });
              _calculateCosts();
            },
          ),
          
          const SizedBox(height: 12),
          
          // Quantity and Unit
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: item.quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Kuantiti',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => _calculateCosts(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.usageUnit,
                  decoration: InputDecoration(
                    labelText: 'Unit',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: compatibleUnits.map((unit) {
                    return DropdownMenuItem(value: unit, child: Text(unit));
                  }).toList(),
                  onChanged: selectedStock == null ? null : (value) {
                    setState(() {
                      item.usageUnit = value;
                    });
                    _calculateCosts();
                  },
                ),
              ),
            ],
          ),
          
          // Item Cost Display
          if (itemCost > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Kos: RM ${itemCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.accent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Ringkasan Kos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildCostRow('Bahan Mentah', _materialsCost),
          const SizedBox(height: 8),
          _buildCostRow('Packaging', _totalPackagingCost),
          const SizedBox(height: 8),
          _buildCostRow('Buruh', double.tryParse(_labourCostController.text) ?? 0.0),
          const SizedBox(height: 8),
          _buildCostRow('Lain-lain', double.tryParse(_otherCostsController.text) ?? 0.0),
          
          const Divider(height: 24, thickness: 2),
          
          _buildCostRow('JUMLAH KOS/BATCH', _totalCostPerBatch, isBold: true, isLarge: true),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'KOS PER UNIT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'RM ${_costPerUnit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, {bool isBold = false, bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          'RM ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSellingPriceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sell, color: AppColors.accent, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Harga Jualan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Suggested prices with markup
          const Text(
            'Cadangan Harga (Markup):',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMarkupButton('2x', 2.0),
              _buildMarkupButton('2.5x', 2.5),
              _buildMarkupButton('3x', 3.0),
              _buildMarkupButton('Cadangan ($_suggestedMarginPercent%)', 1 + _suggestedMarginPercent / 100),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Selling Price Input
          TextFormField(
            controller: _sellingPriceController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: 'Harga Jualan Per Unit (RM)',
              prefixIcon: Icon(Icons.attach_money, color: AppColors.accent, size: 28),
              filled: true,
              fillColor: AppColors.accent.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
            validator: (v) => (v?.isEmpty ?? true) ? 'Harga diperlukan' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMarkupButton(String label, double multiplier) {
    final price = _costPerUnit * multiplier;
    return ElevatedButton(
      onPressed: () {
        _sellingPriceController.text = price.toStringAsFixed(2);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('RM ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Recipe Item Input Helper Class
class RecipeItemInput {
  String? stockItemId;
  String? usageUnit;
  final TextEditingController quantityController = TextEditingController();

  void dispose() {
    quantityController.dispose();
  }
}

/// Helper function to get compatible units
List<String> getCompatibleUnits(String stockUnit) {
  return UnitConversion.getCompatibleUnits(stockUnit);
}

