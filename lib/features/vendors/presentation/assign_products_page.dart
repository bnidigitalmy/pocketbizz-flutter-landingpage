import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/vendors_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../subscription/widgets/subscription_guard.dart';

/// Assign Products Page - Link products to vendor
class AssignProductsPage extends StatefulWidget {
  final String vendorId;

  const AssignProductsPage({super.key, required this.vendorId});

  @override
  State<AssignProductsPage> createState() => _AssignProductsPageState();
}

class _AssignProductsPageState extends State<AssignProductsPage> {
  final _vendorsRepo = VendorsRepositorySupabase();
  final _productsRepo = ProductsRepositorySupabase();
  
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _assignedProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final products = await _productsRepo.listProducts();
      final assigned = await _vendorsRepo.getVendorProducts(widget.vendorId);

      setState(() {
        _allProducts = products.map((p) => {
          'id': p.id,
          'name': p.name,
          'sku': p.sku,
          'sale_price': p.salePrice,
          'image_url': p.imageUrl,
        }).toList();
        _assignedProducts = assigned;
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

  bool _isAssigned(String productId) {
    return _assignedProducts.any((p) => p['product_id'] == productId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assign Products'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allProducts.length,
              itemBuilder: (context, index) {
                final product = _allProducts[index];
                final isAssigned = _isAssigned(product['id']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: product['image_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product['image_url'],
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.inventory_2, color: AppColors.primary),
                          ),
                    title: Text(
                      product['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('SKU: ${product['sku']}'),
                    trailing: Switch(
                      value: isAssigned,
                      activeColor: AppColors.primary,
                      onChanged: (value) async {
                        if (value) {
                          await _assignProduct(product['id']);
                        } else {
                          await _removeProduct(product['id']);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _assignProduct(String productId) async {
    try {
      await _vendorsRepo.assignProductToVendor(
        vendorId: widget.vendorId,
        productId: productId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product assigned!'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        // PHASE: Handle subscription enforcement errors
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Assign Product',
          error: e,
        );
        if (handled) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal assign: Sila cuba lagi'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeProduct(String productId) async {
    try {
      await _vendorsRepo.removeProductFromVendor(widget.vendorId, productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product removed'), backgroundColor: Colors.orange),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        // PHASE: Handle subscription enforcement errors
        final handled = await SubscriptionEnforcement.maybePromptUpgrade(
          context,
          action: 'Remove Product',
          error: e,
        );
        if (handled) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal remove: Sila cuba lagi'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

