import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

/// Today's Performance Card
/// Shows today's revenue vs yesterday
/// Quick comparison for SME owners
class TodayPerformanceCard extends StatelessWidget {
  final double todayRevenue;
  final double yesterdayRevenue;
  final double revenueChange;
  final int todaySalesCount;
  final int yesterdaySalesCount;

  const TodayPerformanceCard({
    super.key,
    required this.todayRevenue,
    required this.yesterdayRevenue,
    required this.revenueChange,
    required this.todaySalesCount,
    required this.yesterdaySalesCount,
  });

  Color _getChangeColor() {
    if (revenueChange > 0) {
      return AppColors.success;
    } else if (revenueChange < 0) {
      return Colors.red;
    }
    return Colors.grey;
  }

  IconData _getChangeIcon() {
    if (revenueChange > 0) {
      return Icons.trending_up;
    } else if (revenueChange < 0) {
      return Icons.trending_down;
    }
    return Icons.trending_flat;
  }

  String _getChangeText() {
    if (revenueChange > 0) {
      return '+${revenueChange.toStringAsFixed(1)}%';
    } else if (revenueChange < 0) {
      return '${revenueChange.toStringAsFixed(1)}%';
    }
    return 'Tiada perubahan';
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = _getChangeColor();
    final changeIcon = _getChangeIcon();
    final changeText = _getChangeText();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assessment_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prestasi Hari Ini',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Bandingkan dengan semalam',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Revenue Section
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jualan Hari Ini',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM ${NumberFormat('#,##0.00').format(todayRevenue)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: changeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: changeColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      changeIcon,
                      size: 16,
                      color: changeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      changeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Sales Count Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Hari Ini',
                todaySalesCount.toString(),
                Icons.shopping_cart_rounded,
                AppColors.primary,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              _buildStatItem(
                'Semalam',
                yesterdaySalesCount.toString(),
                Icons.history_rounded,
                Colors.grey[600]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

