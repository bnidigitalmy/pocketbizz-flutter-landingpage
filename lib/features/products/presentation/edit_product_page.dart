import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/models/product.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../features/subscription/widgets/subscription_guard.dart';
import '../../recipes/presentation/recipe_builder_page.dart';
import 'widgets/category_dropdown.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  
  const EditProductPage({
    super.key,
    required this.product,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = ProductsRepositorySupabase();
  final _productionRepo = ProductionRepository(supabase);
  final _imageService = ImageUploadService();

  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _descriptionController;

  String? _selectedCategory;
  String? _currentImageUrl;
  XFile? _pendingImage;
  bool _loading = false;
  double _availableStock = 0.0;
  bool _loadingStock = true;

  @override
  void initState() {
    super.initState();
    _skuController = TextEditingController(text: widget.product.sku);
    _nameController = TextEditingController(text: widget.product.name);
    _selectedCategory = widget.product.category;
    _unitController = TextEditingController(text: widget.product.unit);
    _salePriceController = TextEditingController(text: widget.product.salePrice.toString());
    _costPriceController = TextEditingController(text: widget.product.costPrice.toString());
    _descriptionController = TextEditingController(text: widget.product.description ?? '');
    _currentImageUrl = widget.product.imageUrl;
    
    // Add listeners for real-time profit preview
    _salePriceController.addListener(() => setState(() {}));
    _costPriceController.addListener(() => setState(() {}));
    
    _loadStock();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _salePriceController.dispose();
    _costPriceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    try {
      final stock = await _productionRepo.getTotalRemainingForProduct(widget.product.id);
      setState(() {
        _availableStock = stock;
        _loadingStock = false;
      });
    } catch (e) {
      setState(() => _loadingStock = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = source == ImageSource.gallery
          ? await _imageService.pickImageFromGallery()
          : await _imageService.pickImageFromCamera();

      if (image != null) {
        setState(() {
          _pendingImage = image;
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

    // PHASE: Subscriber Expired System - Protect edit action
    await requirePro(context, 'Edit Produk', () async {
      setState(() => _loading = true);

      try {
      String? imageUrl = _currentImageUrl;

      // Upload image if there's a pending one
      if (_pendingImage != null) {
        try {
          imageUrl = await _imageService.updateProductImage(
            _pendingImage!,
            widget.product.id,
            _currentImageUrl,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ralat memuat naik gambar: $e'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          // Continue with save even if image upload fails
        }
      }

      final costPrice = double.parse(_costPriceController.text);
      final salePrice = double.parse(_salePriceController.text);
      
      final updates = {
        'sku': _skuController.text.trim(),
        'name': _nameController.text.trim(),
        'unit': _unitController.text.trim(),
        'cost_price': costPrice,
        'sale_price': salePrice,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'category': _selectedCategory,
        if (imageUrl != null) 'image_url': imageUrl,
        if (_pendingImage != null && imageUrl == null) 'image_url': null,
      };

      await _repo.updateProduct(widget.product.id, updates);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Produk berjaya dikemaskini!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Edit Produk',
          error: e,
        );
        if (handled) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: $e'),
            backgroundColor: Colors.red,
          ),
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
    final salePrice = double.tryParse(_salePriceController.text) ?? 0.0;
    final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
    final profit = salePrice - costPrice;
    // Fix: Profit margin should be (profit / sale_price) * 100, not (profit / cost_price) * 100
    final margin = salePrice > 0.0 ? (profit / salePrice) * 100.0 : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Produk'),
            Text(
              'Kemaskini maklumat produk',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Product Image
            _buildImageSection(),
            const SizedBox(height: 24),

            // Stock Information Card
            _buildStockCard(),
            const SizedBox(height: 16),

            // SKU
            TextFormField(
              controller: _skuController,
              decoration: InputDecoration(
                labelText: '# SKU',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.tag),
                helperText: 'Biasanya tidak perlu diubah',
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Diperlukan' : null,
            ),
            const SizedBox(height: 16),

            // Product Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Produk *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.shopping_bag),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Diperlukan' : null,
            ),
            const SizedBox(height: 16),

            // Category
            CategoryDropdown(
              initialValue: _selectedCategory,
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            const SizedBox(height: 16),

            // Unit
            TextFormField(
              controller: _unitController,
              decoration: InputDecoration(
                labelText: 'Unit *',
                hintText: 'e.g., pcs, kg, box',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.straighten),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Diperlukan' : null,
            ),
            const SizedBox(height: 16),

            // Sale Price
            TextFormField(
              controller: _salePriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Harga Jualan (RM) *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Diperlukan';
                if (double.tryParse(v!) == null) return 'Nombor tidak sah';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Cost Price
            TextFormField(
              controller: _costPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Harga Kos (RM) *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.money_off),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Diperlukan';
                if (double.tryParse(v!) == null) return 'Nombor tidak sah';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Profit Preview (Real-time)
            if (salePrice > 0.0 || costPrice > 0.0) _buildProfitPreview(profit, margin),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Penerangan (Pilihan)',
                hintText: 'Butiran produk...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),

            // Recipe Link Card
            _buildRecipeLinkCard(),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _loading ? null : _saveProduct,
              icon: const Icon(Icons.save),
              label: const Text('Simpan Perubahan'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gambar Produk',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
            child: _pendingImage != null
                ? FutureBuilder<List<int>>(
            future: _pendingImage!.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    Uint8List.fromList(snapshot.data!),
                    fit: BoxFit.cover,
                  ),
                );
              }
                      return const Center(child: CircularProgressIndicator());
                    },
                  )
                : _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _currentImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildImagePlaceholder();
                          },
                        ),
                      )
                    : _buildImagePlaceholder(),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _showImageSourceDialog,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(
              _currentImageUrl != null || _pendingImage != null
                  ? 'Tukar Gambar'
                  : 'Tambah Gambar',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Tiada Gambar',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _availableStock > 0
              ? Colors.green[50]
              : Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _availableStock > 0
                ? Colors.green[200]!
                : Colors.red[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _availableStock > 0 ? Icons.inventory_2 : Icons.error_outline,
              color: _availableStock > 0
                  ? Colors.green[700]
                  : Colors.red[700],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stok Tersedia',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  _loadingStock
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '${_availableStock.toStringAsFixed(1)} ${widget.product.unit}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _availableStock > 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitPreview(double profit, double margin) {
    final isPositive = profit >= 0;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isPositive ? Colors.green[50] : Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPositive ? Colors.green[300]! : Colors.red[300]!,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: isPositive ? Colors.green[700] : Colors.red[700],
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pratonton Untung',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Untung seunit:'),
                Text(
                  'RM${profit.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green[700] : Colors.red[700],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Margin untung:'),
                Text(
                  '${margin.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green[700] : Colors.red[700],
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

  Widget _buildRecipeLinkCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeBuilderPage(
                productId: widget.product.id,
                productName: widget.product.name,
                productUnit: widget.product.unit,
              ),
            ),
          );
          if (result == true) {
            _loadStock(); // Reload stock after recipe changes
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange[200]!,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.orange[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Urus Resipi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tambah atau edit bahan-bahan resipi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.orange[700], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
