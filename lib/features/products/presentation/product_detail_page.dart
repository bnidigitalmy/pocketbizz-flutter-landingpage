import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product.dart';
import '../../../data/models/competitor_price.dart';
import '../../../data/repositories/competitor_prices_repository_supabase.dart';
import 'widgets/market_analysis_card.dart';
import '../products_providers.dart';

class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productsModuleDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).pushNamed(
              '/products/$productId/edit',
            ),
          ),
        ],
      ),
      body: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (product) => _ProductDetailView(product: product),
      ),
    );
  }
}

class _ProductDetailView extends StatefulWidget {
  const _ProductDetailView({required this.product});

  final Product product;

  @override
  State<_ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<_ProductDetailView> {
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

  Future<void> _handleCompetitorPriceAdded() async {
    await _loadCompetitorPrices();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadCompetitorPrices,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(widget.product.name),
              subtitle: Text(widget.product.description ?? 'No description'),
              trailing: Chip(
                label: Text(widget.product.category ?? 'Uncategorized'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'SKU', value: widget.product.sku),
                  _DetailRow(label: 'Unit', value: widget.product.unit),
                  _DetailRow(
                    label: 'Cost Price',
                    value: 'RM ${widget.product.costPrice.toStringAsFixed(2)}',
                  ),
                  if (widget.product.costPerUnit != null)
                    _DetailRow(
                      label: 'Cost Per Unit',
                      value: 'RM ${widget.product.costPerUnit!.toStringAsFixed(2)}',
                    ),
                  _DetailRow(
                    label: 'Sale Price',
                    value: 'RM ${widget.product.salePrice.toStringAsFixed(2)}',
                  ),
                  if (widget.product.costPerUnit != null)
                    _DetailRow(
                      label: 'Profit Margin',
                      value: '${((widget.product.salePrice - widget.product.costPerUnit!) / widget.product.salePrice * 100).toStringAsFixed(1)}%',
                    ),
                  _DetailRow(
                    label: 'Created At',
                    value: widget.product.createdAt.toLocal().toString(),
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
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

