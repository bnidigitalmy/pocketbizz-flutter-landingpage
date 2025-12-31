import 'package:flutter/material.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';
import '../../../domain/sme_dashboard_v2_models.dart';
import 'dashboard_v2_format.dart';

class SmartInsightsCardV2 extends StatelessWidget {
  final SmeDashboardV2Data data;
  final VoidCallback onAddSale;
  final VoidCallback onAddExpense;
  final VoidCallback onViewFinishedStock;
  final VoidCallback onViewSales;

  const SmartInsightsCardV2({
    super.key,
    required this.data,
    required this.onAddSale,
    required this.onAddExpense,
    required this.onViewFinishedStock,
    required this.onViewSales,
  });

  @override
  Widget build(BuildContext context) {
    final insights = _buildInsights();
    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Insight Ringkas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...insights.map((i) => _InsightRow(item: i)).toList(),
        ],
      ),
    );
  }

  List<_InsightItem> _buildInsights() {
    final items = <_InsightItem>[];

    if (data.today.inflow <= 0 && data.today.transactions == 0) {
      items.add(
        _InsightItem(
          icon: Icons.trending_down_rounded,
          color: Colors.orange,
          title: 'Belum ada jualan hari ini',
          message: 'Buat 1 transaksi awal untuk mula momentum.',
          actionLabel: 'Buat Jualan',
          onAction: onAddSale,
        ),
      );
    }

    if (data.today.inflow > 0 && data.today.expense > data.today.inflow) {
      items.add(
        _InsightItem(
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
          title: 'Belanja melebihi masuk',
          message:
              'Hari ini belanja ${DashboardV2Format.currency(data.today.expense)} lebih tinggi dari masuk ${DashboardV2Format.currency(data.today.inflow)}.',
          actionLabel: 'Semak Belanja',
          onAction: onAddExpense,
        ),
      );
    }

    if (data.week.net < 0) {
      items.add(
        _InsightItem(
          icon: Icons.waterfall_chart_rounded,
          color: Colors.orange,
          title: 'Net minggu ini negatif',
          message:
              'Net minggu ini ${DashboardV2Format.currency(data.week.net)}. Cuba kurangkan perbelanjaan besar atau tingkatkan jualan.',
          actionLabel: 'Lihat Jualan',
          onAction: onViewSales,
        ),
      );
    }

    final topToday = data.topProducts.todayTop3;
    if (topToday.isNotEmpty && topToday.first.units >= 5) {
      final top = topToday.first;
      final name = top.displayName.isNotEmpty ? top.displayName : top.key;
      items.add(
        _InsightItem(
          icon: Icons.local_fire_department_rounded,
          color: AppColors.success,
          title: 'Produk paling perform hari ini',
          message: '"$name" dah terjual ${DashboardV2Format.units(top.units)} unit. Pastikan stok cukup.',
          actionLabel: 'Semak Stok Siap',
          onAction: onViewFinishedStock,
        ),
      );
    }

    // Show max 2 to keep it snackable.
    return items.take(2).toList();
  }
}

class _InsightItem {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  _InsightItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
}

class _InsightRow extends StatelessWidget {
  final _InsightItem item;

  const _InsightRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, color: item.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: item.color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: item.onAction,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: item.color),
                foregroundColor: item.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(item.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}


