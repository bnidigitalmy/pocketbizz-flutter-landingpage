import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product.dart';
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

class _ProductDetailView extends StatelessWidget {
  const _ProductDetailView({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(product.name),
            subtitle: Text(product.description ?? 'No description'),
            trailing: Chip(
              label: Text(product.category ?? 'Uncategorized'),
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
                _DetailRow(label: 'SKU', value: product.sku),
                _DetailRow(label: 'Unit', value: product.unit),
                _DetailRow(
                  label: 'Cost Price',
                  value: 'RM ${product.costPrice.toStringAsFixed(2)}',
                ),
                _DetailRow(
                  label: 'Sale Price',
                  value: 'RM ${product.salePrice.toStringAsFixed(2)}',
                ),
                _DetailRow(
                  label: 'Created At',
                  value: product.createdAt.toLocal().toString(),
                ),
              ],
            ),
          ),
        ),
      ],
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

