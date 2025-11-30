import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Urgent Actions Widget
/// Shows critical items that need immediate attention
/// Helps SME owners prioritize their day
class UrgentActionsWidget extends StatelessWidget {
  final int pendingBookings;
  final int pendingPOs;
  final int lowStockCount;
  final VoidCallback onViewBookings;
  final VoidCallback onViewPOs;
  final VoidCallback onViewStock;

  const UrgentActionsWidget({
    super.key,
    required this.pendingBookings,
    required this.pendingPOs,
    required this.lowStockCount,
    required this.onViewBookings,
    required this.onViewPOs,
    required this.onViewStock,
  });

  int get _totalUrgentItems => pendingBookings + pendingPOs + lowStockCount;

  @override
  Widget build(BuildContext context) {
    if (_totalUrgentItems == 0) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 32),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tiada Tindakan Segera',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Semua urusan terkawal! 👍',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.priority_high_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tindakan Segera',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Perlu perhatian sekarang',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_totalUrgentItems',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          
          // Urgent Items List
          if (pendingBookings > 0)
            _buildUrgentItem(
              icon: Icons.event_note_rounded,
              title: 'Tempahan Menunggu',
              count: pendingBookings,
              color: AppColors.warning,
              onTap: onViewBookings,
            ),
          
          if (pendingPOs > 0) ...[
            const SizedBox(height: 12),
            _buildUrgentItem(
              icon: Icons.shopping_bag_rounded,
              title: 'Purchase Order Tertunggak',
              count: pendingPOs,
              color: Colors.blue,
              onTap: onViewPOs,
            ),
          ],
          
          if (lowStockCount > 0) ...[
            const SizedBox(height: 12),
            _buildUrgentItem(
              icon: Icons.inventory_2_rounded,
              title: 'Stok Rendah',
              count: lowStockCount,
              color: Colors.red,
              onTap: onViewStock,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrgentItem({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

