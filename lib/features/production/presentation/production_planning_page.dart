import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/supabase/supabase_client.dart' show supabase;
import '../../../data/repositories/production_repository_supabase.dart';
import '../../../data/repositories/products_repository_supabase.dart';
import '../../../data/repositories/shopping_cart_repository_supabase.dart';
import '../../../data/models/production_batch.dart';
import '../../../data/models/product.dart';
import 'widgets/production_planning_dialog.dart';

/// Production Planning Page - 3-Step Production Planning with Preview
class ProductionPlanningPage extends StatefulWidget {
  const ProductionPlanningPage({super.key});

  @override
  State<ProductionPlanningPage> createState() => _ProductionPlanningPageState();
}

class _ProductionPlanningPageState extends State<ProductionPlanningPage> {
  late final ProductionRepository _productionRepo;
  late final ProductsRepositorySupabase _productsRepo;
  late final ShoppingCartRepository _cartRepo;

  List<Product> _products = [];
  List<ProductionBatch> _batches = [];
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _productionRepo = ProductionRepository(supabase);
    _productsRepo = ProductsRepositorySupabase();
    _cartRepo = ShoppingCartRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final [productsResult, batchesResult] = await Future.wait([
        _productsRepo.listProducts(),
        _productionRepo.getAllBatches(),
      ]);

      setState(() {
        _products = (productsResult as List).cast<Product>();
        _batches = (batchesResult as List).cast<ProductionBatch>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        // Show error in console for debugging
        debugPrint('Error loading production data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error memuat data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }


  void _showPlanningDialog() {
    showDialog(
      context: context,
      builder: (context) => ProductionPlanningDialog(
        products: _products,
        productionRepo: _productionRepo,
        cartRepo: _cartRepo,
        onSuccess: _loadData,
      ),
    );
  }

  String? _getExpiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) return null;

    final today = DateTime.now();
    today.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final expiry = expiryDate.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final twoDaysFromNow = today.add(const Duration(days: 2));

    if (expiry.isBefore(today)) return 'expired';
    if (expiry.isAfter(today) && expiry.isBefore(twoDaysFromNow)) return 'expiring';
    return 'fresh';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Produksi'),
            Text(
              '${_batches.length} rekod',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with Plan Button
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rancang & Rekod Produksi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pilih produk, semak bahan, rekod produksi',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showPlanningDialog(),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('Rancang Produksi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Production History
                Expanded(
                  child: _batches.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _batches.length,
                            itemBuilder: (context, index) {
                              return _buildBatchCard(_batches[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showPlanningDialog,
        icon: const Icon(Icons.add),
        label: const Text('Rancang Produksi'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tiada Rekod Produksi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mulakan dengan merancang produksi pertama',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(ProductionBatch batch) {
    final expiryStatus = _getExpiryStatus(batch.expiryDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.productName ?? 'Unknown',
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
                          Chip(
                            label: Text('${batch.quantity} unit'),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                          ),
                          if (batch.expiryDate != null)
                              Chip(
                                label: Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(batch.expiryDate!),
                                ),
                              backgroundColor: expiryStatus == 'expired'
                                  ? Colors.red.withOpacity(0.1)
                                  : expiryStatus == 'expiring'
                                      ? Colors.orange.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                            ),
                          if (expiryStatus == 'expired')
                            Chip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning, size: 14, color: Colors.red),
                                  SizedBox(width: 4),
                                  Text('Luput', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                              backgroundColor: Colors.red.withOpacity(0.1),
                            ),
                          if (expiryStatus == 'expiring')
                            Chip(
                              label: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text('Hampir Luput', style: TextStyle(color: Colors.orange)),
                                ],
                              ),
                              backgroundColor: Colors.orange.withOpacity(0.1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Kos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'RM ${batch.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (batch.notes != null && batch.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Nota: ${batch.notes}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

