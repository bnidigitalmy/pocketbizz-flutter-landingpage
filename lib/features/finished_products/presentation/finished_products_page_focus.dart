import 'package:flutter/material.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';
import 'package:pocketbizz/core/widgets/cached_image.dart';
import 'package:pocketbizz/data/models/finished_product.dart';
import 'package:pocketbizz/data/models/product.dart';
import 'package:pocketbizz/data/repositories/finished_products_repository_supabase.dart';
import 'package:pocketbizz/data/repositories/products_repository_supabase.dart';
import 'package:pocketbizz/features/finished_products/presentation/batch_details_dialog.dart';

/// Focus variant of Stok Siap page.
/// - Auto-scrolls to a focused product (by normalized name key)
/// - Briefly highlights the product card
///
/// Note: Created to avoid modifying the stable core `finished_products_page.dart`.
class FinishedProductsFocusPage extends StatefulWidget {
  final String focusKey; // normalized: trim + lowercase + collapse spaces
  final String? focusLabel;
  final Color? focusAccent;

  const FinishedProductsFocusPage({
    super.key,
    required this.focusKey,
    this.focusLabel,
    this.focusAccent,
  });

  @override
  State<FinishedProductsFocusPage> createState() => _FinishedProductsFocusPageState();
}

class _FinishedProductsFocusPageState extends State<FinishedProductsFocusPage> {
  final _repository = FinishedProductsRepository();
  final _productsRepo = ProductsRepositorySupabase();

  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  List<FinishedProductSummary> _products = [];
  Map<String, Product> _productMap = {};

  bool _isLoading = true;
  String? _error;

  String? _focusedProductId;
  bool _didAutoScroll = false;
  bool _highlightActive = true;

  Color _withAlpha(Color c, double opacity01) => c.withAlpha((opacity01 * 255).round());
  Color get _accent => widget.focusAccent ?? AppColors.primary;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _didAutoScroll = false;
      _highlightActive = true;
    });

    try {
      final [finishedProducts, allProducts] = await Future.wait([
        _repository.getFinishedProductsSummary(),
        _productsRepo.listProducts(),
      ]);

      final productMap = <String, Product>{};
      for (final product in allProducts as List<Product>) {
        productMap[product.id] = product;
      }

      final productsList = finishedProducts as List<FinishedProductSummary>;
      final focused = _findFocusedProduct(productsList);

      setState(() {
        _products = productsList;
        _productMap = productMap;
        _focusedProductId = focused?.productId;
        _isLoading = false;
      });

      // Try focus scroll after first paint.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocused());
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  FinishedProductSummary? _findFocusedProduct(List<FinishedProductSummary> products) {
    final key = _normalize(widget.focusKey);
    if (key.isEmpty) return null;

    for (final p in products) {
      if (_normalize(p.productName) == key) return p;
    }
    return null;
  }

  String _normalize(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _scrollToFocused() async {
    if (!mounted || _didAutoScroll) return;
    final id = _focusedProductId;
    if (id == null) return;

    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null) {
      // List not laid out yet; try one more frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocused());
      return;
    }

    _didAutoScroll = true;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.20,
    );

    // Turn off highlight after a short delay.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _highlightActive = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusLabel = widget.focusLabel?.trim();
    final showFocusBanner = (_focusedProductId != null) && (focusLabel?.isNotEmpty ?? false);

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
                  : Column(
                      children: [
                        if (showFocusBanner)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _withAlpha(_accent, 0.10),
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.touch_app_rounded, size: 18, color: _accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Fokus produk: $focusLabel',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _focusedProductId = null;
                                    _highlightActive = false;
                                  }),
                                  child: const Text('Tutup'),
                                ),
                              ],
                            ),
                          ),
                        Expanded(child: _buildProductsList()),
                      ],
                    ),
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
              'Gagal muat stok siap',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Ralat tidak diketahui',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Cuba Lagi'),
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
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Tiada Stok Siap',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat produksi untuk menambah stok siap',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/production'),
              icon: const Icon(Icons.factory_rounded),
              label: const Text('Rancang Produksi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          final key = _itemKeys.putIfAbsent(product.productId, () => GlobalObjectKey(product.productId));

          return Padding(
            key: key,
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildProductCard(product),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(FinishedProductSummary product) {
    final expiryStatus = _getExpiryStatus(product.nearestExpiry);
    final productInfo = _productMap[product.productId];

    final isFocused = _highlightActive && (_focusedProductId == product.productId);
    final focusedBorder =
        isFocused ? BorderSide(color: _withAlpha(_accent, 0.70), width: 2) : BorderSide.none;
    final glowShadow = isFocused
        ? [
            BoxShadow(
              color: _withAlpha(_accent, 0.22),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: glowShadow,
      ),
      child: Card(
        elevation: isFocused ? 4 : 2,
        shadowColor: isFocused ? _withAlpha(_accent, 0.25) : null,
        surfaceTintColor: Colors.transparent,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: focusedBorder,
        ),
        child: InkWell(
          onTap: () => _showBatchDetails(product),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isFocused)
                  Container(
                    width: 4,
                    height: 84,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                if (isFocused) const SizedBox(width: 12),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: CachedProductImage(
                    imageUrl: productInfo?.imageUrl,
                    width: 80,
                    height: 80,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.productName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFocused) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _withAlpha(_accent, 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _withAlpha(_accent, 0.30)),
                              ),
                              child: Text(
                                'TOP',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _accent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            product.totalRemaining.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('unit', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
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
                                  Icon(_getExpiryIcon(expiryStatus.status), size: 14, color: expiryStatus.color),
                                  const SizedBox(width: 4),
                                  Text(
                                    expiryStatus.label,
                                    style: TextStyle(fontSize: 11, color: expiryStatus.color),
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
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
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


