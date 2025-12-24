import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/models/product.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../recipes/presentation/recipe_builder_page.dart';
import 'edit_product_page.dart';
import 'add_product_with_recipe_page.dart';
import '../../onboarding/presentation/widgets/contextual_tooltip.dart';
import '../../onboarding/data/tooltip_content.dart';
import '../../onboarding/services/tooltip_service.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _repo = ProductsRepositorySupabase();
  final _productionRepo = ProductionRepository(supabase);
  final _searchController = TextEditingController();
  
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  Map<String, double> _stockCache = {};
  bool _loading = false;
  
  String _searchQuery = '';
  String? _selectedCategory;
  String _sortBy = 'name'; // name, price_high, price_low, stock_low
  
  // Search debouncing
  Timer? _searchDebounce;
  
  // Summary stats
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTooltip();
    });
  }

  Future<void> _checkAndShowTooltip() async {
    final hasData = _allProducts.isNotEmpty;
    
    final shouldShow = await TooltipHelper.shouldShowTooltip(
      context,
      hasData ? TooltipKeys.products : TooltipKeys.products,
      checkEmptyState: !hasData,
      emptyStateChecker: () => !hasData,
    );
    
    if (shouldShow && mounted) {
      final content = hasData ? TooltipContent.products : TooltipContent.productsEmpty;
      await TooltipHelper.showTooltip(
        context,
        content.moduleKey,
        content.title,
        content.message,
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);

    try {
      final products = await _repo.listProducts();
      
      // Load stock for all products IN PARALLEL (much faster!)
      final stockFutures = products.map((product) async {
        try {
          final stock = await _productionRepo.getTotalRemainingForProduct(product.id);
          return MapEntry(product.id, stock);
        } catch (e) {
          return MapEntry(product.id, 0.0);
        }
      });
      
      final stockResults = await Future.wait(stockFutures);
      final stockMap = Map<String, double>.fromEntries(stockResults);

      if (mounted) {
        setState(() {
          _allProducts = products;
          _stockCache = stockMap;
          _loading = false;
          _calculateSummary();
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuatkan produk: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateSummary() {
    _totalProducts = _allProducts.length;
    _lowStockCount = 0;
    _outOfStockCount = 0;

    for (final product in _allProducts) {
      final stock = _stockCache[product.id] ?? 0.0;
      
      if (stock == 0) {
        _outOfStockCount++;
      } else if (stock < 10) { // Low stock threshold
        _lowStockCount++;
      }
    }
  }

  void _applyFilters() {
    var filtered = List<Product>.from(_allProducts);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(_searchQuery) ||
               p.sku.toLowerCase().contains(_searchQuery) ||
               (p.category?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    // Category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'price_high':
        filtered.sort((a, b) => b.salePrice.compareTo(a.salePrice));
        break;
      case 'price_low':
        filtered.sort((a, b) => a.salePrice.compareTo(b.salePrice));
        break;
      case 'stock_low':
        filtered.sort((a, b) {
          final stockA = _stockCache[a.id] ?? 0.0;
          final stockB = _stockCache[b.id] ?? 0.0;
          return stockA.compareTo(stockB);
        });
        break;
    }

    setState(() => _filteredProducts = filtered);
  }

  List<String> get _availableCategories {
    final categories = _allProducts
        .where((p) => p.category != null && p.category!.isNotEmpty)
        .map((p) => p.category!)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(canPop),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProducts,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilters(),
                    const SizedBox(height: 12),
                    _buildProductsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddProductWithRecipePage(),
            ),
          );
          if (result == true && mounted) {
            _loadProducts();
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool canPop) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (canPop) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacementNamed('/');
          }
        },
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Produk'),
          Text(
            'Urus inventori produk anda',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadProducts,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Jumlah Produk',
            '$_totalProducts',
            Icons.inventory_2,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Stok Rendah',
            '$_lowStockCount',
            Icons.warning,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Habis Stok',
            '$_outOfStockCount',
            Icons.error,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Cari produk, SKU atau kategori...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCategoryFilter(),
            ),
            const SizedBox(width: 12),
            _buildSortDropdown(),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    if (_availableCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategory == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Semua'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = null;
                    _applyFilters();
                  });
                },
              ),
            );
          }

          final category = _availableCategories[index - 1];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : null;
                  _applyFilters();
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: _sortBy,
        isDense: true,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'name', child: Text('Nama A-Z')),
          DropdownMenuItem(value: 'price_high', child: Text('Harga ↓')),
          DropdownMenuItem(value: 'price_low', child: Text('Harga ↑')),
          DropdownMenuItem(value: 'stock_low', child: Text('Stok ↓')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _sortBy = value;
              _applyFilters();
            });
          }
        },
      ),
    );
  }

  Widget _buildProductsList() {
    if (_filteredProducts.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_filteredProducts.length} produk ditemui',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) {
            final product = _filteredProducts[index];
            return _buildProductCard(product);
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final stock = _stockCache[product.id] ?? 0.0;
    final isLowStock = stock > 0 && stock < 10;
    final isOutOfStock = stock == 0;
    final profit = product.salePrice - product.costPrice;
    final profitMargin =
        product.salePrice > 0 ? (profit / product.salePrice) * 100 : 0.0;

    Color stockColor;
    IconData stockIcon;
    String stockText;

    if (isOutOfStock) {
      stockColor = Colors.red;
      stockIcon = Icons.error_outline;
      stockText = 'Habis';
    } else if (isLowStock) {
      stockColor = Colors.orange;
      stockIcon = Icons.warning_amber_rounded;
      stockText = 'Rendah';
    } else {
      stockColor = Colors.green;
      stockIcon = Icons.check_circle_outline;
      stockText = 'Cukup';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOutOfStock
              ? Colors.red[200]!
              : isLowStock
                  ? Colors.orange[200]!
                  : Colors.grey[200]!,
          width: isOutOfStock || isLowStock ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showProductDetails(product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Product Image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image, color: Colors.grey);
                          },
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Stock Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: stockColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: stockColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(stockIcon, size: 14, color: stockColor),
                              const SizedBox(width: 4),
                              Text(
                                stockText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: stockColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (product.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.category!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Jual: RM${product.salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Kos: RM${product.costPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Stok: ${stock.toStringAsFixed(1)} ${product.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Untung: RM${profit.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: profit >= 0 ? Colors.green[700] : Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Margin: ${profitMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: profitMargin > 30
                                    ? Colors.green[700]
                                    : profitMargin > 15
                                        ? Colors.orange[700]
                                        : Colors.red[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.restaurant_menu, color: Colors.orange),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RecipeBuilderPage(
                            productId: product.id,
                            productName: product.name,
                            productUnit: product.unit,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Resipi',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProductPage(product: product),
                        ),
                      );
                      if (result == true && mounted) {
                        _loadProducts();
                      }
                    },
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(product),
                    tooltip: 'Padam',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'Tiada produk ditemui'
                : 'Tiada produk lagi',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != null
                ? 'Cuba ubah carian atau filter anda'
                : 'Mula dengan menambah produk pertama anda',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty && _selectedCategory == null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductWithRecipePage(),
                  ),
                );
                if (result == true && mounted) {
                  _loadProducts();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk Pertama'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Padam Produk'),
        content: Text('Adakah anda pasti mahu memadam "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repo.deleteProduct(product.id);
        await _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berjaya dipadam'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ralat memadam: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showProductDetails(Product product) {
    final stock = _stockCache[product.id] ?? 0.0;
    final profit = product.salePrice - product.costPrice;
    final profitMargin =
        product.salePrice > 0 ? (profit / product.salePrice) * 100 : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 24,
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
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow('SKU', product.sku),
                    if (product.category != null)
                      _buildDetailRow('Kategori', product.category!),
                    _buildDetailRow('Unit', product.unit),
                    _buildDetailRow(
                      'Harga Jualan',
                      'RM${product.salePrice.toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Harga Kos',
                      'RM${product.costPrice.toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Untung (Anggaran)',
                      'RM${profit.toStringAsFixed(2)}',
                    ),
                    _buildDetailRow(
                      'Margin Untung',
                      '${profitMargin.toStringAsFixed(1)}%',
                    ),
                    _buildDetailRow(
                      'Stok Tersedia',
                      '${stock.toStringAsFixed(1)} ${product.unit}',
                    ),
                    if (product.description != null)
                      _buildDetailRow('Penerangan', product.description!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
