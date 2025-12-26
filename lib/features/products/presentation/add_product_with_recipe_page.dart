import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/utils/unit_conversion.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../data/models/stock_item.dart';
import '../../../data/models/category.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/stock_repository_supabase.dart';
import '../../../data/repositories/categories_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/recipes_repository_supabase.dart';

/**
 * 🔒 POCKETBIZZ CORE ENGINE (STABLE)
 * ❌ DO NOT MODIFY
 * ❌ DO NOT REFACTOR
 * ❌ DO NOT OPTIMIZE
 * This logic is production-tested.
 * New features must EXTEND, not change.
 * 
 * Add/Edit Product with Recipe & Auto-Cost Calculation
 * - Supports both add and edit modes
 * - Cost calculation: materials + labour + other + (packaging * units_per_batch)
 * - Cost per unit = totalCostPerBatch / unitsPerBatch (INCLUDES packaging)
 * - Recipe integration with automatic cost sync
 * - Cost fields are critical - do not change calculation logic
 */

/// Add/Edit Product with Recipe & Auto-Cost Calculation
/// Mobile-first, non-techy friendly, Malay language
/// Supports both add (product=null) and edit (product provided) modes
class AddProductWithRecipePage extends StatefulWidget {
  final Product? product; // If provided, edit mode. If null, add mode.
  
  const AddProductWithRecipePage({super.key, this.product});

  @override
  State<AddProductWithRecipePage> createState() => _AddProductWithRecipePageState();
}

class _AddProductWithRecipePageState extends State<AddProductWithRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final _stockRepo = StockRepository(supabase);
  final _categoriesRepo = CategoriesRepositorySupabase();
  final _productsRepo = ProductsRepositorySupabase();
  final _recipesRepo = RecipesRepositorySupabase();
  final _imageService = ImageUploadService();

  // Product Info
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _imageUrlController = TextEditingController();
  String? _currentImageUrl;
  XFile? _pendingImage;
  Uint8List? _pendingImageBytes;
  
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
  
  // Edit mode data
  String? _existingRecipeId; // Store recipe ID if editing

  // Cost calculations
  double _materialsCost = 0.0;
  double _totalPackagingCost = 0.0;
  double _totalCostPerBatch = 0.0;
  double _costPerUnit = 0.0;
  int _suggestedMarginPercent = 70; // Default 70% markup for food manufacturing
  double _suggestedSellingPrice = 0.0;

  // Common emojis for product categories
  static const List<String> _categoryEmojis = [
    '🍰', '🥧', '🧁', '🍪', '🍩', '🍮',
    '🍞', '🥐', '🥖', '🥨', '🥯', '🥞',
    '🍕', '🌮', '🌯', '🥙', '🍔', '🍟',
    '🍗', '🥩', '🥓', '🍖', '🍤', '🦐',
    '🍜', '🍝', '🍲', '🍱', '🍛', '🍚',
    '🥗', '🥙', '🥒', '🥕', '🌽', '🥑',
    '🍎', '🍊', '🍋', '🍌', '🍉', '🍇',
    '🍓', '🍈', '🍒', '🍑', '🥭', '🍍',
    '🥥', '🥝', '🍅', '🍆', '🥔', '🥕',
    '🥛', '🍼', '☕', '🍵', '🥤', '🧃',
    '🧉', '🧊', '🍺', '🍻', '🥂', '🍷',
    '🍸', '🍹', '🧋', '🍬', '🍭', '🍫',
    '🍿', '🌰', '🥜', '🧀', '🥚', '🍳',
    '🧇', '🌭', '🥪', '🥘', '🥫', '🍣',
    '🥟', '🥠', '🥡', '🍢', '🍡', '🍧',
    '🍨', '🍦', '🎂', '📦', '🛍️', '🎁',
  ];

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
      // Load stock items and categories first (needed for loading recipe data)
      final stockItems = await _stockRepo.getAllStockItems(limit: 100);
      final categories = await _categoriesRepo.getAll(limit: 100);
      
      setState(() {
        _stockItems = stockItems;
        _categories = categories;
      });
      
      // If editing, load existing product data (after stock items are loaded)
      if (widget.product != null) {
        await _loadExistingProductData();
      }
      
      setState(() {
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
  
  Future<void> _loadExistingProductData() async {
    if (widget.product == null) return;
    
    final product = widget.product!;
    
    // Load product fields
    _nameController.text = product.name;
    _categoryController.text = product.category ?? '';
    _sellingPriceController.text = product.salePrice.toStringAsFixed(2);
    _unitsPerBatchController.text = (product.unitsPerBatch ?? 1).toString();
    _labourCostController.text = (product.labourCost ?? 0.0).toStringAsFixed(2);
    _otherCostsController.text = (product.otherCosts ?? 0.0).toStringAsFixed(2);
    _packagingCostController.text = (product.packagingCost ?? 0.0).toStringAsFixed(2);
    _currentImageUrl = product.imageUrl;
    if (product.imageUrl != null) {
      _imageUrlController.text = product.imageUrl!;
    }
    
    // Load existing recipe if any
    try {
      final recipe = await _recipesRepo.getActiveRecipe(product.id);
      if (recipe != null) {
        _existingRecipeId = recipe.id;
        
        // Update units per batch if different
        if (recipe.yieldQuantity != double.parse(_unitsPerBatchController.text)) {
          _unitsPerBatchController.text = recipe.yieldQuantity.toStringAsFixed(0);
        }
        
        // Load recipe items
        final recipeItems = await _recipesRepo.getRecipeItems(recipe.id);
        _recipeItems.clear();
        for (final item in recipeItems) {
          final input = RecipeItemInput();
          input.stockItemId = item.stockItemId;
          input.usageUnit = item.usageUnit;
          input.quantityController.text = item.quantityNeeded.toString();
          _recipeItems.add(input);
        }
        
        // If no recipe items, add one empty row
        if (_recipeItems.isEmpty) {
          _recipeItems.add(RecipeItemInput());
        }
      }
    } catch (e) {
      // Recipe might not exist yet, that's ok
      if (kDebugMode) {
        print('No recipe found for product: $e');
      }
    }
    
    // Trigger cost calculation
    _calculateCosts();
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

    // Suggested margin based on cost (markup percentage)
    // For food manufacturing, need to cover: overhead (15-25%), wastage (5-10%), 
    // marketing (5-10%), contingency (5%), and profit (20-30%)
    // Minimum safe margin: 60-70%, Ideal: 80-100%
    int suggestedMarginPercent = 70; // Default: 70% markup (more reasonable for food business)
    if (costPerUnit < 1) suggestedMarginPercent = 80; // Higher margin for low-cost items
    else if (costPerUnit < 3) suggestedMarginPercent = 75;
    else if (costPerUnit < 5) suggestedMarginPercent = 70;
    
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = source == ImageSource.gallery
          ? await _imageService.pickImageFromGallery()
          : await _imageService.pickImageFromCamera();

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _pendingImage = image;
          _pendingImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Gambar'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_currentImageUrl != null || _pendingImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Padam Gambar'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _currentImageUrl = null;
                    _pendingImage = null;
                    _pendingImageBytes = null;
                    _imageUrlController.clear();
                  });
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Batal'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
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
      final isEditMode = widget.product != null;
      Product productToSave;
      String productId;

      if (isEditMode) {
        // UPDATE MODE: Update existing product
        productId = widget.product!.id;
        
        // Upload image if any
        String? imageUrl = _currentImageUrl;
        if (_pendingImage != null) {
          try {
            imageUrl = await _imageService.updateProductImage(
              _pendingImage!,
              productId,
              _currentImageUrl,
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gambar tidak dapat dimuat naik: $e'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
        
        // Update product
        final updates = {
          'name': _nameController.text.trim(),
          'category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
          'sale_price': double.parse(_sellingPriceController.text),
          'cost_price': _costPerUnit,
          'units_per_batch': int.parse(_unitsPerBatchController.text),
          'labour_cost': double.parse(_labourCostController.text),
          'other_costs': double.parse(_otherCostsController.text),
          'packaging_cost': double.parse(_packagingCostController.text),
          'materials_cost': _materialsCost,
          'total_cost_per_batch': _totalCostPerBatch,
          'cost_per_unit': _costPerUnit,
          if (imageUrl != null) 'image_url': imageUrl,
          if (_pendingImage != null && imageUrl == null) 'image_url': null,
        };
        
        await _productsRepo.updateProduct(productId, updates);
        productToSave = widget.product!;
      } else {
        // CREATE MODE: Create new product
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
          imageUrl: null,
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

        productToSave = await _productsRepo.createProduct(product);
        productId = productToSave.id;

        // Upload image if any
      if (_pendingImage != null) {
        try {
          final imageUrl = await _imageService.uploadProductImage(
            _pendingImage!,
              productId,
          );
            await _productsRepo.updateProduct(productId, {'image_url': imageUrl});
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gambar tidak dapat dimuat naik: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          }
        }
      }

      // Handle recipe (create or update)
      if (isEditMode && _existingRecipeId != null) {
        // UPDATE RECIPE: Delete existing items and recreate
        final existingItems = await _recipesRepo.getRecipeItems(_existingRecipeId!);
        for (final item in existingItems) {
          await _recipesRepo.deleteRecipeItem(item.id);
        }
        
        // Update recipe
        await _recipesRepo.updateRecipe(_existingRecipeId!, {
          'yield_quantity': double.parse(_unitsPerBatchController.text),
          'name': '${productToSave.name} Recipe',
        });
        
        // Add updated recipe items
        for (final item in _recipeItems) {
          final quantity = double.tryParse(item.quantityController.text);
          if (item.stockItemId != null && quantity != null && quantity > 0) {
            await _recipesRepo.addRecipeItem(
              recipeId: _existingRecipeId!,
              stockItemId: item.stockItemId!,
              quantityNeeded: quantity,
              usageUnit: item.usageUnit ?? 'pcs',
            );
          }
        }
      } else {
        // CREATE RECIPE: Create new recipe
      final recipe = await _recipesRepo.createRecipe(
          productId: productId,
          name: '${productToSave.name} Recipe',
        yieldQuantity: double.parse(_unitsPerBatchController.text),
        yieldUnit: 'pcs',
        isActive: true,
      );

        // Create recipe items
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
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditMode 
              ? '✅ Produk & resepi berjaya dikemaskini!' 
              : '✅ Produk & resepi berjaya ditambah!'),
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
        title: Text(widget.product != null ? 'Edit Produk & Resepi' : 'Tambah Produk & Resepi'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Product Image
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  
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
                  
                  // Category Selection Button
                  OutlinedButton.icon(
                    onPressed: _showCategorySelector,
                    icon: Icon(
                      _categoryController.text.isNotEmpty ? Icons.check_circle : Icons.category_outlined,
                      color: _categoryController.text.isNotEmpty ? AppColors.success : AppColors.primary,
                    ),
                    label: Text(
                      _categoryController.text.isNotEmpty ? _categoryController.text : 'Pilih Kategori',
                      style: TextStyle(
                        color: _categoryController.text.isNotEmpty ? AppColors.success : AppColors.primary,
                        fontWeight: _categoryController.text.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: BorderSide(
                        color: _categoryController.text.isNotEmpty ? AppColors.success : AppColors.primary,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Hidden TextField for validation
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(height: 0, fontSize: 0),
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
                        _isSaving 
                          ? 'Menyimpan...' 
                          : (widget.product != null ? 'Kemaskini Produk' : 'Simpan Produk'),
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

  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.category,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Pilih Kategori',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Category List
              Expanded(
                child: _categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tiada kategori tersedia',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = _categoryController.text == category.name;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey[200]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _categoryController.text = category.name;
                                });
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Category Icon
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary.withOpacity(0.1)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.grey[300]!,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: category.icon != null && category.icon!.isNotEmpty
                                            ? Text(
                                                category.icon!,
                                                style: const TextStyle(fontSize: 28),
                                              )
                                            : Icon(
                                                Icons.category,
                                                color: isSelected
                                                    ? AppColors.primary
                                                    : Colors.grey[600],
                                                size: 28,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Category Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            category.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : Colors.black,
                                            ),
                                          ),
                                          if (category.description != null && category.description!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              category.description!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Selected Icon
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Add New Category Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateCategoryDialog();
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Tambah Kategori Baru'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.primary, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateCategoryDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedIcon;
    String? selectedColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Tambah Kategori Baru',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori *',
                      hintText: 'cth: Kuih, Kek, Minuman',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Penerangan (Pilihan)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  // Icon Selection with Emoji Picker
                  Text(
                    'Icon (Emoji) - Pilihan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Selected Emoji Display
                  if (selectedIcon != null && selectedIcon!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedIcon!,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Icon dipilih',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            color: Colors.blue[700],
                            onPressed: () {
                              setDialogState(() {
                                selectedIcon = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Emoji Grid
                  Container(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      minHeight: 200,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _categoryEmojis.length,
                      itemBuilder: (context, index) {
                        final emoji = _categoryEmojis[index];
                        final isSelected = selectedIcon == emoji;
                        
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = emoji;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(
                        top: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nama kategori diperlukan'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            try {
                              final newCategory = await _categoriesRepo.create(
                                nameController.text.trim(),
                                description: descController.text.trim().isEmpty
                                    ? null
                                    : descController.text.trim(),
                                icon: selectedIcon,
                                color: selectedColor,
                              );

                              // Reload categories
                              final categories = await _categoriesRepo.getAll(limit: 100);
                              setState(() {
                                _categories = categories;
                                _categoryController.text = newCategory.name;
                              });

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Kategori "${newCategory.name}" ditambah'),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Ralat: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Tambah'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showIngredientSelector(int itemIndex, RecipeItemInput item) {
    final searchController = TextEditingController();
    List<StockItem> filteredStock = List.from(_stockItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          String searchQuery = '';

          void updateFilter(String query) {
            setModalState(() {
              searchQuery = query;
              if (query.isEmpty) {
                filteredStock = List.from(_stockItems);
              } else {
                final lowerQuery = query.toLowerCase();
                filteredStock = _stockItems.where((stock) {
                  return stock.name.toLowerCase().contains(lowerQuery);
                }).toList();
              }
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Pilih Bahan',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari bahan...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  updateFilter('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: updateFilter,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  // Stock Items List
                  Expanded(
                    child: filteredStock.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  searchQuery.isNotEmpty
                                      ? 'Tiada bahan ditemui'
                                      : 'Tiada bahan tersedia',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredStock.length,
                            itemBuilder: (context, index) {
                              final stock = filteredStock[index];
                              final isAvailable = stock.currentQuantity > 0;
                              final costPerUnit = stock.purchasePrice / stock.packageSize;
                              final packageInfo = '${stock.packageSize}${stock.unit} @ RM${stock.purchasePrice.toStringAsFixed(2)}';

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isAvailable
                                        ? Colors.grey[200]!
                                        : Colors.red[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: isAvailable
                                      ? () {
                                          Navigator.pop(context);
                                          _showQuantityDialogForItem(itemIndex, item, stock);
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Stock Icon
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: isAvailable
                                                ? Colors.green[50]
                                                : Colors.red[50],
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isAvailable
                                                  ? Colors.green[200]!
                                                  : Colors.red[200]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            isAvailable
                                                ? Icons.inventory_2
                                                : Icons.warning_amber_rounded,
                                            color: isAvailable
                                                ? Colors.green[600]
                                                : Colors.orange[600],
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Stock Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                stock.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue[50],
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'RM${costPerUnit.toStringAsFixed(4)}/${stock.unit}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: Colors.blue[700],
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isAvailable
                                                          ? Colors.green[50]
                                                          : Colors.red[50],
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      'Stok: ${stock.currentQuantity.toStringAsFixed(1)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: isAvailable
                                                            ? Colors.green[700]
                                                            : Colors.red[700],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                packageInfo,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Add Icon
                                        if (isAvailable)
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.add_circle,
                                              color: AppColors.primary,
                                              size: 28,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.block,
                                            color: Colors.grey,
                                            size: 28,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQuantityDialogForItem(int itemIndex, RecipeItemInput item, StockItem stock) {
    final quantityController = TextEditingController(
      text: item.quantityController.text.isEmpty ? '1' : item.quantityController.text,
    );
    String selectedUnit = item.usageUnit ?? stock.unit;
    List<String> compatibleUnits = UnitConversion.getCompatibleUnits(stock.unit);
    
    // Ensure stock.unit is included (case-insensitive check)
    final stockUnitLower = stock.unit.toLowerCase();
    if (!compatibleUnits.any((u) => u.toLowerCase() == stockUnitLower)) {
      compatibleUnits.insert(0, stock.unit);
    }
    
    // Remove duplicates (case-insensitive) and sort
    final seen = <String>{};
    compatibleUnits = compatibleUnits.where((unit) {
      final lower = unit.toLowerCase();
      if (seen.contains(lower)) {
        return false; // Skip duplicate
      }
      seen.add(lower);
      return true;
    }).toList()..sort();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.add_circle, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stock.name,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Kuantiti',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit Resepi',
                      border: OutlineInputBorder(),
                      helperText: 'Unit mesti serasi dengan unit stok bahan.',
                    ),
                    items: compatibleUnits
                        .map(
                          (u) => DropdownMenuItem<String>(
                            value: u,
                            child: Text(u),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedUnit = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stok tersedia: ${stock.currentQuantity.toStringAsFixed(1)} ${stock.unit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final quantity = double.tryParse(quantityController.text) ?? 0.0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kuantiti mesti lebih daripada 0'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  setState(() {
                    item.stockItemId = stock.id;
                    item.quantityController.text = quantity.toString();
                    item.usageUnit = selectedUnit;
                  });
                  Navigator.pop(context);
                  _calculateCosts();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecipeItemCard(int index, RecipeItemInput item) {
    final selectedStock = item.stockItemId != null
        ? _stockItems.firstWhere((s) => s.id == item.stockItemId, orElse: () => _stockItems.first)
        : null;
    
    // Get compatible units and remove duplicates (case-insensitive)
    List<String> compatibleUnits = selectedStock != null
        ? getCompatibleUnits(selectedStock.unit)
        : <String>[];
    
    // Remove duplicates (case-insensitive) to prevent DropdownButton errors
    final seen = <String>{};
    compatibleUnits = compatibleUnits.where((unit) {
      final lower = unit.toLowerCase();
      if (seen.contains(lower)) {
        return false; // Skip duplicate
      }
      seen.add(lower);
      return true;
    }).toList()..sort();

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
          
          // Stock Item Selection Button
          OutlinedButton.icon(
            onPressed: () => _showIngredientSelector(index, item),
            icon: Icon(
              selectedStock != null ? Icons.check_circle : Icons.add_circle_outline,
              color: selectedStock != null ? AppColors.success : AppColors.primary,
            ),
            label: Text(
              selectedStock != null ? selectedStock.name : 'Cari & Pilih Bahan',
              style: TextStyle(
                color: selectedStock != null ? AppColors.success : AppColors.primary,
                fontWeight: selectedStock != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(
                color: selectedStock != null ? AppColors.success : AppColors.primary,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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

  Widget _buildImageSection() {
    Widget preview;
    if (_pendingImageBytes != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _pendingImageBytes!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _currentImageUrl!,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    } else {
      preview = _buildImagePlaceholder();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gambar Produk',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        preview,
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showImageSourceDialog,
          icon: const Icon(Icons.photo_camera_back_outlined),
          label: const Text('Tukar Gambar'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 48, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(
              'Tiada gambar',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
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

