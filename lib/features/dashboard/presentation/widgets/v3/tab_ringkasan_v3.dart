import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/sme_dashboard_v2_models.dart';
import '../v2/dashboard_v2_format.dart';
import 'dashboard_skeleton_v3.dart';
import 'stagger_animation.dart';

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
      return const TabRingkasanSkeleton();
    }

    return StaggeredColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weekly Cashflow with Chart
        _WeeklyCashflowCard(
          inflow: data!.week.inflow,
          expense: data!.week.expense,
          net: data!.week.net,
        ),
        const SizedBox(height: 16),
        // Top Products
        _buildTopProducts(),
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

/// Animated Weekly Cashflow Card with visual bar chart
class _WeeklyCashflowCard extends StatefulWidget {
  final double inflow;
  final double expense;
  final double net;

  const _WeeklyCashflowCard({
    required this.inflow,
    required this.expense,
    required this.net,
  });

  @override
  State<_WeeklyCashflowCard> createState() => _WeeklyCashflowCardState();
}

class _WeeklyCashflowCardState extends State<_WeeklyCashflowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final netColor = widget.net >= 0 ? AppColors.success : Colors.red;
    final maxValue = widget.inflow > widget.expense ? widget.inflow : widget.expense;

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
          // Header
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
              const Spacer(),
              // Legend
              Row(
                children: [
                  _buildLegend('Masuk', AppColors.success),
                  const SizedBox(width: 12),
                  _buildLegend('Keluar', Colors.red.shade400),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Animated Bar Chart
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Inflow Bar
                    Expanded(
                      child: _buildAnimatedBar(
                        label: 'Masuk',
                        value: widget.inflow,
                        maxValue: maxValue,
                        color: AppColors.success,
                        animValue: _animation.value,
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Expense Bar
                    Expanded(
                      child: _buildAnimatedBar(
                        label: 'Keluar',
                        value: widget.expense,
                        maxValue: maxValue,
                        color: Colors.red.shade400,
                        animValue: _animation.value,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Net row with animated counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: netColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.net >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: netColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Bersih',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.net),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    DashboardV2Format.currency(value),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    required double animValue,
  }) {
    final heightRatio = maxValue > 0 ? (value / maxValue) : 0.0;
    final barHeight = 80 * heightRatio * animValue;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Value label
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Text(
              DashboardV2Format.currencyCompact(val),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        // Bar
        Container(
          width: double.infinity,
          height: barHeight.clamp(4.0, 80.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        // Base line
        Container(
          width: double.infinity,
          height: 2,
          color: Colors.grey.shade300,
        ),
      ],
    );
  }
}
