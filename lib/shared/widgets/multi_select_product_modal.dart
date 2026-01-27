import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/product.dart';

/// Model untuk track selected product dengan quantity
class SelectedProductItem {
  final Product product;
  double quantity;
  bool isSelected;

  SelectedProductItem({
    required this.product,
    this.quantity = 1.0,
    this.isSelected = false,
  });
}

/// Shared Multi-Select Product Modal
/// Boleh guna untuk Sales, Bookings, dan modul lain
///
/// Features:
/// - Checkbox multi-select
/// - Inline quantity input dengan stepper
/// - Search/filter produk
/// - Optional stock validation
/// - Bulk add button
class MultiSelectProductModal extends StatefulWidget {
  final List<Product> products;
  final Map<String, double>? productStockCache; // Optional - null means no stock check
  final Function(List<SelectedProductItem>) onConfirm;
  final String title;
  final String confirmButtonText;
  final bool validateStock;

  const MultiSelectProductModal({
    super.key,
    required this.products,
    this.productStockCache,
    required this.onConfirm,
    this.title = 'Pilih Produk',
    this.confirmButtonText = 'Tambah',
    this.validateStock = true,
  });

  /// Show the multi-select modal as a bottom sheet
  static Future<void> show({
    required BuildContext context,
    required List<Product> products,
    Map<String, double>? productStockCache,
    required Function(List<SelectedProductItem>) onConfirm,
    String title = 'Pilih Produk',
    String confirmButtonText = 'Tambah',
    bool validateStock = true,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiSelectProductModal(
        products: products,
        productStockCache: productStockCache,
        onConfirm: onConfirm,
        title: title,
        confirmButtonText: confirmButtonText,
        validateStock: validateStock,
      ),
    );
  }

  @override
  State<MultiSelectProductModal> createState() => _MultiSelectProductModalState();
}

class _MultiSelectProductModalState extends State<MultiSelectProductModal> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, SelectedProductItem> _selectedItems = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, FocusNode> _qtyFocusNodes = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize controllers for all products
    for (final product in widget.products) {
      _qtyControllers[product.id] = TextEditingController(text: '1');
      _qtyFocusNodes[product.id] = FocusNode();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _qtyControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _qtyFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) {
      return widget.products;
    }
    return widget.products.where((product) {
      return product.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  int get _selectedCount => _selectedItems.values.where((item) => item.isSelected).length;

  double _getStock(String productId) {
    if (widget.productStockCache == null) return double.infinity;
    return widget.productStockCache![productId] ?? 0.0;
  }

  bool _hasStock(String productId) {
    if (!widget.validateStock || widget.productStockCache == null) return true;
    return _getStock(productId) > 0;
  }

  void _toggleProduct(Product product) {
    setState(() {
      if (_selectedItems.containsKey(product.id) && _selectedItems[product.id]!.isSelected) {
        // Deselect
        _selectedItems[product.id]!.isSelected = false;
      } else {
        // Select
        if (!_selectedItems.containsKey(product.id)) {
          _selectedItems[product.id] = SelectedProductItem(
            product: product,
            quantity: 1.0,
            isSelected: true,
          );
        } else {
          _selectedItems[product.id]!.isSelected = true;
        }

        // Auto-focus quantity field after selection
        Future.delayed(const Duration(milliseconds: 100), () {
          _qtyFocusNodes[product.id]?.requestFocus();
        });
      }
    });
  }

  void _updateQuantity(Product product, double qty) {
    if (!_selectedItems.containsKey(product.id)) {
      _selectedItems[product.id] = SelectedProductItem(
        product: product,
        quantity: qty,
        isSelected: true,
      );
    } else {
      _selectedItems[product.id]!.quantity = qty;
    }
  }

  void _incrementQty(Product product) {
    final stock = _getStock(product.id);
    final currentQty = _selectedItems[product.id]?.quantity ?? 1.0;
    final canIncrement = !widget.validateStock || currentQty < stock;

    if (canIncrement) {
      setState(() {
        _updateQuantity(product, currentQty + 1);
        _qtyControllers[product.id]?.text = (currentQty + 1).toStringAsFixed(0);
      });
    }
  }

  void _decrementQty(Product product) {
    final currentQty = _selectedItems[product.id]?.quantity ?? 1.0;
    if (currentQty > 1) {
      setState(() {
        _updateQuantity(product, currentQty - 1);
        _qtyControllers[product.id]?.text = (currentQty - 1).toStringAsFixed(0);
      });
    }
  }

  void _onConfirm() {
    final selectedList = _selectedItems.values
        .where((item) => item.isSelected && item.quantity > 0)
        .where((item) {
          if (!widget.validateStock || widget.productStockCache == null) return true;
          final stock = _getStock(item.product.id);
          return item.quantity <= stock;
        })
        .toList();

    widget.onConfirm(selectedList);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
            // Drag handle
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
            _buildHeader(),
            const Divider(height: 1),
            // Search bar
            _buildSearchBar(),
            // Selected count
            _buildSelectedCount(),
            const Divider(height: 1),
            // Product list
            Expanded(
              child: _buildProductList(scrollController),
            ),
            // Bottom action bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari produk...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildSelectedCount() {
    if (_selectedCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primary.withOpacity(0.05),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '$_selectedCount produk dipilih',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                for (final item in _selectedItems.values) {
                  item.isSelected = false;
                }
              });
            },
            child: const Text('Batal Semua'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(ScrollController scrollController) {
    final products = _filteredProducts;

    if (products.isEmpty) {
      return Center(
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
              _searchQuery.isNotEmpty
                  ? 'Tiada produk dijumpai untuk "$_searchQuery"'
                  : 'Tiada produk tersedia',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final hasPrice = product.salePrice > 0;
    final stock = _getStock(product.id);
    final hasStockCheck = widget.validateStock && widget.productStockCache != null;
    final isAvailable = !hasStockCheck || stock > 0;
    final isSelected = _selectedItems[product.id]?.isSelected ?? false;
    final currentQty = _selectedItems[product.id]?.quantity ?? 1.0;
    final qtyExceedsStock = hasStockCheck && currentQty > stock;

    return Card(
      elevation: isSelected ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : hasPrice
                  ? Colors.grey[200]!
                  : Colors.orange[200]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main product row (clickable)
          InkWell(
            onTap: hasPrice && isAvailable ? () => _toggleProduct(product) : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Checkbox
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (!hasPrice || !isAvailable)
                                ? Colors.grey[300]!
                                : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Product Image
                  _buildProductImage(product, hasPrice),
                  const SizedBox(width: 12),
                  // Product Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: (!hasPrice || !isAvailable)
                                ? Colors.grey[500]
                                : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildProductBadges(product, hasPrice, isAvailable, stock, hasStockCheck),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Quantity input (shown when selected)
          if (isSelected && hasPrice && isAvailable) ...[
            const Divider(height: 1),
            _buildQuantityInput(product, stock, qtyExceedsStock, hasStockCheck),
          ],
        ],
      ),
    );
  }

  Widget _buildProductImage(Product product, bool hasPrice) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                product.imageUrl!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderIcon(hasPrice);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            )
          : _buildPlaceholderIcon(hasPrice),
    );
  }

  Widget _buildPlaceholderIcon(bool hasPrice) {
    return Container(
      color: Colors.grey[200],
      child: Icon(
        hasPrice ? Icons.inventory_2_outlined : Icons.warning_amber_rounded,
        color: hasPrice ? Colors.grey[400] : Colors.orange[400],
        size: 24,
      ),
    );
  }

  Widget _buildProductBadges(Product product, bool hasPrice, bool isAvailable, double stock, bool hasStockCheck) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        // Price badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'RM${product.salePrice.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.blue[700],
            ),
          ),
        ),
        // Stock badge (only if stock check enabled)
        if (hasStockCheck)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAvailable ? Icons.inventory_2 : Icons.inventory_2_outlined,
                  size: 12,
                  color: isAvailable ? Colors.green[700] : Colors.red[700],
                ),
                const SizedBox(width: 4),
                Text(
                  'Stok: ${stock.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isAvailable ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        // Category badge
        if (product.category != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              product.category!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.purple[700],
              ),
            ),
          ),
        // No price warning
        if (!hasPrice)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Tiada harga',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuantityInput(Product product, double stock, bool qtyExceedsStock, bool hasStockCheck) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: qtyExceedsStock ? Colors.red[50] : AppColors.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Kuantiti:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: qtyExceedsStock ? Colors.red[700] : Colors.grey[700],
            ),
          ),
          const Spacer(),
          // Decrement button
          _buildQtyButton(
            icon: Icons.remove,
            onTap: () => _decrementQty(product),
            enabled: (_selectedItems[product.id]?.quantity ?? 1.0) > 1,
          ),
          const SizedBox(width: 8),
          // Quantity text field
          SizedBox(
            width: 70,
            child: TextField(
              controller: _qtyControllers[product.id],
              focusNode: _qtyFocusNodes[product.id],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: qtyExceedsStock ? Colors.red[700] : Colors.black,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: qtyExceedsStock ? Colors.red : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: qtyExceedsStock ? Colors.red : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: qtyExceedsStock ? Colors.red : AppColors.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                final qty = double.tryParse(value) ?? 1.0;
                setState(() {
                  _updateQuantity(product, qty > 0 ? qty : 1.0);
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          // Increment button
          _buildQtyButton(
            icon: Icons.add,
            onTap: () => _incrementQty(product),
            enabled: !hasStockCheck || (_selectedItems[product.id]?.quantity ?? 1.0) < stock,
          ),
          // Stock info (only if stock check enabled)
          if (hasStockCheck) ...[
            const SizedBox(width: 12),
            Text(
              '/ ${stock.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Material(
      color: enabled ? AppColors.primary : Colors.grey[300],
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasValidSelection = _selectedItems.values.any((item) {
      if (!item.isSelected) return false;
      if (widget.validateStock && widget.productStockCache != null) {
        final stock = _getStock(item.product.id);
        return item.quantity > 0 && item.quantity <= stock;
      }
      return item.quantity > 0;
    });

    final validCount = _selectedItems.values.where((item) {
      if (!item.isSelected) return false;
      if (widget.validateStock && widget.productStockCache != null) {
        final stock = _getStock(item.product.id);
        return item.quantity > 0 && item.quantity <= stock;
      }
      return item.quantity > 0;
    }).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: hasValidSelection ? _onConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: hasValidSelection ? 4 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_shopping_cart, size: 20),
                const SizedBox(width: 8),
                Text(
                  validCount > 0
                      ? '${widget.confirmButtonText} $validCount Produk'
                      : 'Pilih Produk',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
