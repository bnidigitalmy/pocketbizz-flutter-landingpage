import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/finished_product.dart';
import '../../../data/models/product.dart';
import '../../../data/repositories/finished_products_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import 'batch_details_dialog.dart';

/// Finished Products Page
/// Displays inventory of finished products ready for sale
class FinishedProductsPage extends StatefulWidget {
  const FinishedProductsPage({super.key});

  @override
  State<FinishedProductsPage> createState() => _FinishedProductsPageState();
}

class _FinishedProductsPageState extends State<FinishedProductsPage> {
  final _repository = FinishedProductsRepository();
  final _productsRepo = ProductsRepositorySupabase();
  List<FinishedProductSummary> _products = [];
  List<Product> _allProducts = [];
  Map<String, Product> _productMap = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [finishedProducts, allProducts] = await Future.wait([
        _repository.getFinishedProductsSummary(),
        _productsRepo.listProducts(),
      ]);

      // Create product map for quick lookup
      final productMap = <String, Product>{};
      for (final product in allProducts as List<Product>) {
        productMap[product.id] = product;
      }

      setState(() {
        _products = finishedProducts as List<FinishedProductSummary>;
        _allProducts = allProducts as List<Product>;
        _productMap = productMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Siap'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _products.isEmpty
                  ? _buildEmptyView()
                  : _buildProductsGrid(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading products',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Tiada Stok Siap',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat produksi untuk menambah stok siap',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: _products.length,
          itemBuilder: (context, index) {
            return _buildProductCard(_products[index]);
          },
        ),
      ),
    );
  }

  Widget _buildProductCard(FinishedProductSummary product) {
    final expiryStatus = _getExpiryStatus(product.nearestExpiry);
    
    // Find product to get image
    final productInfo = _productMap[product.productId];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showBatchDetails(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image and Name Row
              Row(
                children: [
                  // Product Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: productInfo?.imageUrl != null && productInfo!.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              productInfo.imageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.grey[400],
                                    size: 28,
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.grey[400],
                              size: 28,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Product Name
                  Expanded(
                    child: Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              // Total remaining
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    product.totalRemaining.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'unit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text('${product.batchCount} batch'),
                    backgroundColor: Colors.grey[200],
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  if (product.nearestExpiry != null)
                    Chip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getExpiryIcon(expiryStatus.status),
                            size: 14,
                            color: expiryStatus.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            expiryStatus.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: expiryStatus.color,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: expiryStatus.backgroundColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ExpiryStatus _getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) {
      return ExpiryStatus(
        status: 'unknown',
        label: 'Tiada Expiry',
        color: Colors.grey,
        backgroundColor: Colors.grey[100]!,
        icon: Icons.help_outline,
      );
    }

    final now = DateTime.now();
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilExpiry = expiry.difference(today).inDays;

    if (daysUntilExpiry < 0) {
      return ExpiryStatus(
        status: 'expired',
        label: 'Expired',
        color: Colors.red[700]!,
        backgroundColor: Colors.red[50]!,
        icon: Icons.warning,
      );
    } else if (daysUntilExpiry <= 3) {
      return ExpiryStatus(
        status: 'warning',
        label: '$daysUntilExpiry hari lagi',
        color: Colors.orange[700]!,
        backgroundColor: Colors.orange[50]!,
        icon: Icons.access_time,
      );
    } else if (daysUntilExpiry <= 7) {
      return ExpiryStatus(
        status: 'soon',
        label: '$daysUntilExpiry hari lagi',
        color: Colors.blue[700]!,
        backgroundColor: Colors.blue[50]!,
        icon: Icons.schedule,
      );
    } else {
      return ExpiryStatus(
        status: 'fresh',
        label: 'Fresh',
        color: Colors.green[700]!,
        backgroundColor: Colors.green[50]!,
        icon: Icons.check_circle,
      );
    }
  }

  IconData _getExpiryIcon(String status) {
    switch (status) {
      case 'expired':
        return Icons.warning;
      case 'warning':
        return Icons.access_time;
      case 'fresh':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _showBatchDetails(FinishedProductSummary product) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BatchDetailsDialog(
        productId: product.productId,
        productName: product.productName,
      ),
    );
  }
}

class ExpiryStatus {
  final String status;
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  ExpiryStatus({
    required this.status,
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });
}

