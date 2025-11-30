import 'package:flutter/material.dart';
import '../../../data/models/product.dart';
import '../../../data/models/competitor_price.dart';
import '../../../data/repositories/competitor_prices_repository_supabase.dart';
import 'widgets/market_analysis_card.dart';
import 'edit_product_page.dart';

/// Standalone Product Detail Page with Market Analysis
/// Can be used without provider dependency
class ProductDetailPageStandalone extends StatefulWidget {
  final Product product;

  const ProductDetailPageStandalone({super.key, required this.product});

  @override
  State<ProductDetailPageStandalone> createState() => _ProductDetailPageStandaloneState();
}

class _ProductDetailPageStandaloneState extends State<ProductDetailPageStandalone> {
  final _competitorPricesRepo = CompetitorPricesRepositorySupabase();
  List<CompetitorPrice> _competitorPrices = [];
  bool _loadingPrices = true;

  @override
  void initState() {
    super.initState();
    _loadCompetitorPrices();
  }

  Future<void> _loadCompetitorPrices() async {
    setState(() => _loadingPrices = true);
    try {
      final prices = await _competitorPricesRepo.getCompetitorPrices(widget.product.id);
      if (mounted) {
        setState(() {
          _competitorPrices = prices;
          _loadingPrices = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPrices = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Butiran Produk'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProductPage(product: widget.product),
                ),
              ).then((result) {
                if (result == true) {
                  Navigator.pop(context, true); // Refresh product list
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCompetitorPrices,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Product Info Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                                widget.product.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.product.description != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.product.description!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.product.category != null)
                          Chip(
                            label: Text(widget.product.category!),
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Product Details Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Maklumat Produk',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('SKU', widget.product.sku),
                    _buildDetailRow('Unit', widget.product.unit),
                    _buildDetailRow(
                      'Harga Kos',
                      'RM ${widget.product.costPrice.toStringAsFixed(2)}',
                    ),
                    if (widget.product.costPerUnit != null)
                      _buildDetailRow(
                        'Kos Per Unit',
                        'RM ${widget.product.costPerUnit!.toStringAsFixed(2)}',
                      ),
                    _buildDetailRow(
                      'Harga Jualan',
                      'RM ${widget.product.salePrice.toStringAsFixed(2)}',
                    ),
                    if (widget.product.costPerUnit != null)
                      _buildDetailRow(
                        'Profit Margin',
                        '${((widget.product.salePrice - widget.product.costPerUnit!) / widget.product.salePrice * 100).toStringAsFixed(1)}%',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Market Analysis Card
            MarketAnalysisCard(
              product: widget.product,
              competitorPrices: _competitorPrices,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

