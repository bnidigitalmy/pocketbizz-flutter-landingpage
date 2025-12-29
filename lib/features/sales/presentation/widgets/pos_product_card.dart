import 'package:flutter/material.dart';
import '../../../../data/models/product.dart';
import '../../../../core/widgets/cached_image.dart';

class PosProductCard extends StatelessWidget {
  final Product product;
  final double availableStock;
  final int? cartQuantity;
  final VoidCallback onTap;

  const PosProductCard({
    super.key,
    required this.product,
    required this.availableStock,
    this.cartQuantity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutOfStock = availableStock <= 0;
    final isLowStock = availableStock > 0 && availableStock < 10;
    final hasInCart = cartQuantity != null && cartQuantity! > 0;

    return GestureDetector(
      onTap: isOutOfStock ? null : onTap,
      child: Card(
        elevation: hasInCart ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hasInCart
              ? BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                )
              : BorderSide.none,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: CachedProductImage(
                      imageUrl: product.imageUrl,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
                // Product Info
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'RM ${product.salePrice.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isOutOfStock
                                  ? Icons.error_outline
                                  : isLowStock
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline,
                              size: 12,
                              color: isOutOfStock
                                  ? Colors.red
                                  : isLowStock
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Stok: ${availableStock.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isOutOfStock
                                    ? Colors.red
                                    : isLowStock
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Cart Quantity Badge
            if (hasInCart)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cartQuantity.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            // Out of Stock Overlay
            if (isOutOfStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'HABIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
