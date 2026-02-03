import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/sme_dashboard_v2_models.dart';
import '../v2/dashboard_v2_format.dart';

/// Tab Ringkasan (Summary) - Weekly overview and top products
class TabRingkasanV3 extends StatelessWidget {
  final SmeDashboardV2Data? data;
  final VoidCallback onViewAllProducts;

  const TabRingkasanV3({
    super.key,
    required this.data,
    required this.onViewAllProducts,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekly Cashflow
        _buildWeeklyCashflow(),
        const SizedBox(height: 16),
        // Top Products
        _buildTopProducts(),
      ],
    );
  }

  Widget _buildWeeklyCashflow() {
    final inflow = data!.week.inflow;
    final expense = data!.week.expense;
    final net = data!.week.net;
    final netColor = net >= 0 ? AppColors.success : Colors.red;

    // Calculate ratio for progress bar
    final total = inflow + expense;
    final inflowRatio = total > 0 ? inflow / total : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Minggu Ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Inflow row
          _buildCashflowRow(
            label: 'Masuk',
            value: inflow,
            color: AppColors.success,
            ratio: inflowRatio,
          ),
          const SizedBox(height: 12),

          // Expense row
          _buildCashflowRow(
            label: 'Keluar',
            value: expense,
            color: Colors.red,
            ratio: 1 - inflowRatio,
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Net row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bersih',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    DashboardV2Format.currency(net),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    net >= 0 ? Icons.trending_up : Icons.trending_down,
                    color: netColor,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowRow({
    required String label,
    required double value,
    required Color color,
    required double ratio,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              DashboardV2Format.currency(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.8)),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildTopProducts() {
    final topProducts = data!.topProducts.weekTop3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Top 3 Produk Minggu Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (topProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tiada jualan minggu ini',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return _buildProductRow(
                rank: index + 1,
                name: product.name,
                units: product.unitsSold,
                revenue: product.revenue,
              );
            }),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onViewAllProducts,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Lihat Semua Produk'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow({
    required int rank,
    required String name,
    required int units,
    required double revenue,
  }) {
    final rankColors = [Colors.amber, Colors.grey.shade400, Colors.brown.shade300];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: rankColor.withOpacity(0.9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$units unit',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                DashboardV2Format.currency(revenue),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
