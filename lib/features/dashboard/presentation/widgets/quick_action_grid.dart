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
              label: 'Stok Gudang',
              icon: Icons.warehouse_rounded,
              color: AppColors.primary,
              onTap: () => Navigator.of(context).pushNamed('/inventory'),
            ),
            QuickActionCard(
              label: 'Rancang Produksi',
              icon: Icons.factory_rounded,
              color: Colors.purple,
              onTap: () => Navigator.of(context).pushNamed('/production'),
            ),
            QuickActionCard(
              label: 'Stok Siap',
              icon: Icons.inventory_2_rounded,
              color: AppColors.success,
              onTap: () => Navigator.of(context).pushNamed('/finished-products'),
            ),
            QuickActionCard(
              label: 'Penghantaran',
              icon: Icons.local_shipping_rounded,
              color: Colors.blue,
              onTap: () => Navigator.of(context).pushNamed('/deliveries'),
            ),
            QuickActionCard(
              label: 'Tuntutan',
              icon: Icons.receipt_long_rounded,
              color: Colors.orange,
              onTap: () => Navigator.of(context).pushNamed('/claims'),
            ),
            QuickActionCard(
              label: 'Perbelanjaan',
              icon: Icons.payments_rounded,
              color: AppColors.warning,
              onTap: () => Navigator.of(context).pushNamed('/expenses'),
            ),
          ],
        ),
      ],
    );
  }
}

