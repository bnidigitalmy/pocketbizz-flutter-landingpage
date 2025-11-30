import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'quick_action_card.dart';

/// Quick Action Grid
/// Optimized for daily use by SME owners
/// Thumb-friendly, mobile-first design
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.flash_on_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Tindakan Pantas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            QuickActionCard(
              label: 'Jualan Baru',
              icon: Icons.point_of_sale_rounded,
              color: AppColors.success,
              onTap: () => Navigator.of(context).pushNamed('/sales/create'),
            ),
            QuickActionCard(
              label: 'Tempahan Baru',
              icon: Icons.add_business_rounded,
              color: AppColors.primary,
              onTap: () => Navigator.of(context).pushNamed('/bookings/create'),
            ),
            QuickActionCard(
              label: 'Urus Stok',
              icon: Icons.inventory_2_rounded,
              color: AppColors.accent,
              onTap: () => Navigator.of(context).pushNamed('/stock'),
            ),
            QuickActionCard(
              label: 'Rancang Produksi',
              icon: Icons.factory_rounded,
              color: Colors.purple,
              onTap: () => Navigator.of(context).pushNamed('/production'),
            ),
            QuickActionCard(
              label: 'Senarai Belian',
              icon: Icons.shopping_cart_rounded,
              color: Colors.blue,
              onTap: () => Navigator.of(context).pushNamed('/shopping-list'),
            ),
            QuickActionCard(
              label: 'Tambah Produk',
              icon: Icons.add_box_rounded,
              color: AppColors.warning,
              onTap: () => Navigator.of(context).pushNamed('/products/add'),
            ),
          ],
        ),
      ],
    );
  }
}

