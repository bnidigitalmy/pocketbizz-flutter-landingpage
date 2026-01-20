/**
 * 🔒 STABLE CORE MODULE – DO NOT MODIFY
 * This file is production-tested.
 * Any changes must be isolated via extension or wrapper.
 */
// ❌ AI WARNING:
// DO NOT refactor, rename, optimize or restructure this logic.
// Only READ-ONLY reference allowed.
// 
// Product List Page - Cost Display Logic
// - Uses costPerUnit (includes packaging) for accurate cost display
// - Fallback to costPrice if costPerUnit is null
// - Profit calculation uses costPerUnit for consistency
// - Cost display matches recipe page (with packaging difference clarified)

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/repositories/recipes_repository_supabase.dart';
import '../../../data/models/product.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/cache_service.dart';
import '../../recipes/presentation/recipe_builder_page.dart';
import 'add_product_with_recipe_page.dart';
import '../../../core/widgets/cached_image.dart';
import '../../subscription/widgets/subscription_guard.dart';
import '../../subscription/exceptions/subscription_limit_exception.dart';
import '../../subscription/presentation/subscription_page.dart';

/// Helper class for virtual scrolling list items
class _ProductListItem {
  final _ProductListItemType type;
  final Product? product;
  final int activeCount;
  final int disabledCount;

  _ProductListItem({
    required this.type,
    this.product,
    this.activeCount = 0,
    this.disabledCount = 0,
  });
}

enum _ProductListItemType {
  header,
  disabledHeader,
  product,
}

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
  bool _showDisabledProducts = false; // Toggle to show/hide disabled products
  
  // Search debouncing
  Timer? _searchDebounce;
  Timer? _productsReloadDebounce;
  Timer? _stockReloadDebounce;
  
  // Summary stats
  int _totalProducts = 0;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;

  // Real-time subscriptions for cache invalidation
  StreamSubscription? _productsSubscription;
  StreamSubscription? _productionBatchesSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProducts();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _productsReloadDebounce?.cancel();
    _stockReloadDebounce?.cancel();
    _productsSubscription?.cancel();
    _productionBatchesSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleProductsReload() {
    _productsReloadDebounce?.cancel();
    _productsReloadDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _loadProducts();
      }
    });
  }

  void _scheduleStockReload(List<Product> products) {
    _stockReloadDebounce?.cancel();
    _stockReloadDebounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _loadStockAsync(products);
      }
    });
  }

  /// Setup real-time subscriptions to invalidate cache when data changes
  void _setupRealtimeSubscriptions() {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Subscribe to products table changes
      _productsSubscription = supabase
          .from('products')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              // Invalidate products cache when products change
              CacheService.invalidateMultiple([
                'products_list',
                'products_list_inactive',
                'products_stock_map',
              ]);
              _scheduleProductsReload(); // Reload with fresh data
            }
          });

      // Subscribe to production_batches changes (affects stock)
      _productionBatchesSubscription = supabase
          .from('production_batches')
          .stream(primaryKey: ['id'])
          .eq('business_owner_id', userId)
          .listen((data) {
            if (mounted) {
              // Invalidate stock cache when batches change
              CacheService.invalidate('products_stock_map');
              _scheduleStockReload(_allProducts); // Reload stock
            }
          });

      debugPrint('✅ Products page real-time subscriptions setup complete');
    } catch (e) {
      debugPrint('⚠️ Error setting up products real-time subscriptions: $e');
    }
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
      // Use cache for products list - faster loading
      final cacheKey = _showDisabledProducts 
          ? 'products_list_inactive' 
          : 'products_list';
      
      final products = await CacheService.getOrFetch(
        cacheKey,
        () => _repo.listProducts(includeInactive: _showDisabledProducts),
        ttl: const Duration(minutes: 10), // Products don't change often
      );
      
      // Show products immediately (don't wait for stock)
      if (mounted) {
        setState(() {
          _allProducts = products;
          _loading = false;
          _applyFilters();
        });
      }
      
      // Load stock in background (non-blocking) with cache
      _loadStockAsync(products);
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

  /// Load stock for all products asynchronously (non-blocking)
  /// This allows products to show immediately while stock loads in background
  /// Uses cache for faster subsequent loads
  Future<void> _loadStockAsync(List<Product> products) async {
    try {
      // Check cache first - if valid, use cached stock map
      if (CacheService.hasValidCache('products_stock_map')) {
        final cachedStockMap = await CacheService.getOrFetch<Map<String, double>>(
          'products_stock_map',
          () async {
            // Build stock map from products
            return await _fetchStockMap(products);
          },
          ttl: const Duration(minutes: 5), // Stock changes more frequently
        );

        if (mounted) {
          setState(() {
            _stockCache = cachedStockMap;
            _calculateSummary();
            _applyFilters();
          });
        }
        return; // Use cached data
      }

      // Cache miss or expired - fetch fresh stock data
      final stockMap = await CacheService.getOrFetch<Map<String, double>>(
        'products_stock_map',
        () => _fetchStockMap(products),
        ttl: const Duration(minutes: 5),
      );

      // Update UI with stock data
      if (mounted) {
        setState(() {
          _stockCache = stockMap;
          _calculateSummary();
          _applyFilters(); // Re-apply filters to update stock-based filters
        });
      }
    } catch (e) {
      // Silently fail - stock is optional for display
      debugPrint('Error loading stock: $e');
    }
  }

  /// Fetch stock map for all products (helper method)
  Future<Map<String, double>> _fetchStockMap(List<Product> products) async {
    if (products.isEmpty) return {};

    final productIds = products.map((p) => p.id).toList();
    final response = await supabase
        .from('production_batches')
        .select('product_id, remaining_qty')
        .inFilter('product_id', productIds);

    final totals = <String, double>{};
    for (final entry in response as List) {
      final id = entry['product_id'] as String;
      final remaining = (entry['remaining_qty'] as num?)?.toDouble() ?? 0.0;
      totals[id] = (totals[id] ?? 0.0) + remaining;
    }

    // Ensure every product has a key
    for (final product in products) {
      totals.putIfAbsent(product.id, () => 0.0);
    }

    return totals;
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
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Header section (summary, search, filters)
                  SliverToBoxAdapter(
                    child: Padding(
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
                        ],
                      ),
                    ),
                  ),
                  // Products list with virtual scrolling
                  _buildProductsListSliver(),
                ],
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
        const SizedBox(height: 12),
        // Toggle to show/hide disabled products
        InkWell(
          onTap: () {
            setState(() {
              _showDisabledProducts = !_showDisabledProducts;
            });
            _loadProducts();
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _showDisabledProducts ? Colors.orange[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showDisabledProducts ? Colors.orange[300]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showDisabledProducts ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                  color: _showDisabledProducts ? Colors.orange[700] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _showDisabledProducts ? 'Sembunyikan Produk Tidak Aktif' : 'Tunjukkan Produk Tidak Aktif',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _showDisabledProducts ? Colors.orange[700] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
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

  /// Build products list using SliverList for virtual scrolling
  Widget _buildProductsListSliver() {
    if (_filteredProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildEmptyState(),
        ),
      );
    }

    // Separate active and disabled products if showing disabled
    final activeProducts = _filteredProducts.where((p) => p.isActive).toList();
    final disabledProducts = _filteredProducts.where((p) => !p.isActive).toList();
    
    // Combine all items with separators for ListView.builder
    final allItems = <_ProductListItem>[];
    
    // Add header
    allItems.add(_ProductListItem(
      type: _ProductListItemType.header,
      activeCount: activeProducts.length,
      disabledCount: disabledProducts.length,
    ));
    
    // Add active products
    for (final product in activeProducts) {
      allItems.add(_ProductListItem(
        type: _ProductListItemType.product,
        product: product,
      ));
    }
    
    // Add disabled section header if needed
    if (disabledProducts.isNotEmpty) {
      allItems.add(_ProductListItem(
        type: _ProductListItemType.disabledHeader,
        disabledCount: disabledProducts.length,
      ));
      
      // Add disabled products
      for (final product in disabledProducts) {
        allItems.add(_ProductListItem(
          type: _ProductListItemType.product,
          product: product,
        ));
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = allItems[index];
            
            switch (item.type) {
              case _ProductListItemType.header:
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${item.activeCount} produk aktif${item.disabledCount > 0 ? ', ${item.disabledCount} tidak aktif' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                );
              
              case _ProductListItemType.disabledHeader:
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.visibility_off, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Produk Tidak Aktif (${item.disabledCount})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              
              case _ProductListItemType.product:
                return _buildProductCard(item.product!);
            }
          },
          childCount: allItems.length,
        ),
      ),
    );
  }


  Widget _buildProductCard(Product product) {
    final stock = _stockCache[product.id] ?? 0.0;
    final isLowStock = stock > 0 && stock < 10;
    final isOutOfStock = stock == 0;
    final isDisabled = !product.isActive;
    // Use costPerUnit if available (calculated with packaging), otherwise fallback to costPrice
    final effectiveCostPrice = product.costPerUnit ?? product.costPrice;
    final profit = product.salePrice - effectiveCostPrice;
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
          color: isDisabled
              ? Colors.grey[400]!
              : isOutOfStock
              ? Colors.red[200]!
              : isLowStock
                  ? Colors.orange[200]!
                  : Colors.grey[200]!,
          width: (isDisabled || isOutOfStock || isLowStock) ? 2 : 1,
        ),
      ),
      color: isDisabled ? Colors.grey[50] : null,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
      child: InkWell(
        onTap: () => _showProductDetails(product),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status Badge for disabled products
              if (isDisabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tidak Aktif',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Product Image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CachedProductImage(
                  imageUrl: product.imageUrl,
                  width: 70,
                  height: 70,
                  borderRadius: BorderRadius.circular(12),
                ),
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
                            'Kos: RM${(product.costPerUnit ?? product.costPrice).toStringAsFixed(2)}',
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
                          builder: (context) => AddProductWithRecipePage(product: product),
                        ),
                      );
                      if (result == true && mounted) {
                        _loadProducts();
                      }
                    },
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.purple),
                    onPressed: () => _duplicateProduct(product),
                    tooltip: 'Duplicate',
                  ),
                  // Enable/Disable button
                  if (!product.isActive)
                  IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.green),
                      onPressed: () => _enableProduct(product),
                      tooltip: 'Aktifkan',
                    ),
                  // Disable/Delete button
                  IconButton(
                    icon: Icon(
                      product.isActive ? Icons.visibility_off : Icons.delete_forever,
                      color: product.isActive ? Colors.orange : Colors.red,
                    ),
                    onPressed: () => _confirmDelete(product),
                    tooltip: product.isActive ? 'Nonaktifkan' : 'Padam Kekal',
                  ),
                ],
              ),
            ],
          ),
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

  Future<void> _enableProduct(Product product) async {
    try {
      await _repo.enableProduct(product.id);
      await _loadProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Produk berjaya diaktifkan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat mengaktifkan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(Product product) async {
    // Show dialog with options: Disable (recommended) or Delete (permanent)
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.isActive ? 'Nonaktifkan Produk' : 'Padam Produk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih tindakan untuk "${product.name}":'),
            const SizedBox(height: 16),
            if (product.isActive) ...[
              const Text(
                '💡 Disyorkan: Nonaktifkan produk (boleh diaktifkan semula kemudian)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              '⚠️ Peringatan: Padam produk akan memadam secara kekal dan tidak boleh dibatalkan.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Batal'),
          ),
          if (product.isActive)
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'disable'),
              icon: const Icon(Icons.visibility_off, size: 18),
              label: const Text('Nonaktifkan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, 'delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Padam Kekal'),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;

    try {
      if (action == 'disable') {
        // Disable product (soft delete)
        await _repo.disableProduct(product.id);
        await _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Produk berjaya dinyahaktifkan'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (action == 'delete') {
        // Permanent delete - show confirmation again
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('⚠️ Padam Kekal'),
            content: Text(
              'Adakah anda PASTI mahu memadam "${product.name}" secara kekal?\n\n'
              'Tindakan ini TIDAK BOLEH dibatalkan. Semua data produk akan hilang.',
            ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Ya, Padam Kekal'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
        final hasHardDeleteBlockers = await _hasHardDeleteBlockers(product.id);
        if (hasHardDeleteBlockers && mounted) {
          final disableInstead = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Produk Tidak Boleh Dipadam'),
              content: const Text(
                'Produk ini masih digunakan dalam jualan/rekod stok.\n\n'
                'Anda hanya boleh nonaktifkan produk ini.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Nonaktifkan'),
                ),
              ],
            ),
          );
          if (disableInstead == true && mounted) {
            await _repo.disableProduct(product.id);
            await _loadProducts();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Produk berjaya dinyahaktifkan'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
          return;
        }

        await _deleteProductRecipes(product.id);
        await _repo.deleteProduct(product.id);
        CacheService.invalidateMultiple([
          'products_list',
          'products_list_inactive',
          'products_stock_map',
        ]);
        if (mounted) {
          setState(() {
            _allProducts.removeWhere((p) => p.id == product.id);
            _filteredProducts.removeWhere((p) => p.id == product.id);
            _stockCache.remove(product.id);
            _calculateSummary();
          });
        }
        await _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Produk berjaya dipadam secara kekal'),
              backgroundColor: Colors.green,
            ),
          );
          }
        }
        }
      } catch (e) {
        if (mounted) {
          if (_isForeignKeyError(e)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Produk masih digunakan dalam rekod lain. Sila nonaktifkan dahulu.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
            content: Text('Ralat: $e'),
              backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            ),
          );
      }
    }
  }

  Future<void> _duplicateProduct(Product product) async {
    await requirePro(context, 'Duplicate Produk', () async {
      if (!mounted) return;

      var progressShown = false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Sedang gandakan produk...')),
            ],
          ),
        ),
      );
      progressShown = true;

      try {
        final now = DateTime.now();
        final newSku = _generateDuplicateSku(product.sku);
        final newName = _generateDuplicateName(product.name);

        final duplicated = Product(
          id: '',
          businessOwnerId: '',
          sku: newSku,
          name: newName,
          categoryId: product.categoryId,
          category: product.category,
          unit: product.unit,
          salePrice: product.salePrice,
          costPrice: product.costPrice,
          description: product.description,
          imageUrl: product.imageUrl,
          unitsPerBatch: product.unitsPerBatch,
          labourCost: product.labourCost,
          otherCosts: product.otherCosts,
          packagingCost: product.packagingCost,
          materialsCost: product.materialsCost,
          totalCostPerBatch: product.totalCostPerBatch,
          costPerUnit: product.costPerUnit,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        final created = await _repo.createProduct(duplicated);

        final recipesRepo = RecipesRepositorySupabase();
        final activeRecipe = await recipesRepo.getActiveRecipe(product.id);
        if (activeRecipe != null) {
          final newRecipe = await recipesRepo.createRecipe(
            productId: created.id,
            name: '${activeRecipe.name} (Salinan)',
            description: activeRecipe.description,
            yieldQuantity: activeRecipe.yieldQuantity,
            yieldUnit: activeRecipe.yieldUnit,
            version: 1,
            isActive: true,
          );

          final items = await recipesRepo.getRecipeItems(activeRecipe.id);
          for (final item in items) {
            await recipesRepo.addRecipeItem(
              recipeId: newRecipe.id,
              stockItemId: item.stockItemId,
              quantityNeeded: item.quantityNeeded,
              usageUnit: item.usageUnit,
              position: item.position,
              notes: item.notes,
            );
          }
        }

        CacheService.invalidateMultiple([
          'products_list',
          'products_list_inactive',
          'products_stock_map',
        ]);
        await _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Produk berjaya diduplikasi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          if (progressShown) {
            Navigator.of(context, rootNavigator: true).pop();
            progressShown = false;
          }
          if (e is SubscriptionLimitException) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Had Langganan Dicapai'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.userMessage),
                    const SizedBox(height: 16),
                    const Text(
                      'Upgrade langganan anda untuk menambah lebih banyak produk.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Lihat Pakej'),
                  ),
                ],
              ),
            );
          } else {
            final handled = await SubscriptionEnforcement.maybePromptUpgrade(
              context,
              action: 'Duplicate Produk',
              error: e,
            );
            if (!handled && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ralat: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } finally {
        if (mounted && progressShown) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    });
  }

  String _generateDuplicateSku(String sku) {
    final trimmed = sku.trim();
    final base = trimmed.isEmpty ? 'SKU' : trimmed;
    final existingSkus = _allProducts.map((p) => p.sku.toLowerCase()).toSet();

    var candidate = '$base-COPY';
    var counter = 2;
    while (existingSkus.contains(candidate.toLowerCase())) {
      candidate = '$base-COPY-$counter';
      counter++;
    }
    return candidate;
  }

  String _generateDuplicateName(String name) {
    final base = name.trim().isEmpty ? 'Produk' : name.trim();
    const suffix = ' (Salinan)';
    final existingNames = _allProducts.map((p) => p.name.toLowerCase()).toSet();

    var candidate = '$base$suffix';
    var counter = 2;
    while (existingNames.contains(candidate.toLowerCase())) {
      candidate = '$base$suffix $counter';
      counter++;
    }
    return candidate;
  }

  Future<bool> _hasHardDeleteBlockers(String productId) async {
    final checks = await Future.wait([
      _hasAnyRow('inventory_batches', 'product_id', productId),
      _hasAnyRow('finished_product_batches', 'product_id', productId),
      _hasAnyRow('sales_items', 'product_id', productId),
    ]);
    return checks.any((hasAny) => hasAny);
  }

  Future<bool> _hasAnyRow(String table, String column, String id) async {
    final response = await supabase.from(table).select('id').eq(column, id).limit(1);
    return (response as List).isNotEmpty;
  }

  Future<void> _deleteProductRecipes(String productId) async {
    final recipesRepo = RecipesRepositorySupabase();
    final recipes = await recipesRepo.getRecipesByProduct(productId);
    for (final recipe in recipes) {
      await recipesRepo.deleteRecipe(recipe.id);
    }
  }

  bool _isForeignKeyError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('foreign key') ||
        msg.contains('violates foreign key') ||
        msg.contains('23503');
  }

  void _showProductDetails(Product product) {
    final stock = _stockCache[product.id] ?? 0.0;
    // Use costPerUnit if available (calculated with packaging), otherwise fallback to costPrice
    final effectiveCostPrice = product.costPerUnit ?? product.costPrice;
    final profit = product.salePrice - effectiveCostPrice;
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
                      'RM${(product.costPerUnit ?? product.costPrice).toStringAsFixed(2)}',
                    ),
                    if (product.costPerUnit != null && product.totalCostPerBatch != null)
                      _buildDetailRow(
                        'Jumlah Kos Per Batch',
                        'RM${product.totalCostPerBatch!.toStringAsFixed(2)}',
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
