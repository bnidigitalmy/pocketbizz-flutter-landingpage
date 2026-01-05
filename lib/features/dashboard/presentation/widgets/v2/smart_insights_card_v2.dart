import 'package:flutter/material.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';
import '../../../domain/sme_dashboard_v2_models.dart';
import '../../../domain/dashboard_mood_engine.dart';
import '../../../domain/dashboard_ux_copy.dart';
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

  DashboardMode get _mode => DashboardMoodEngine.getCurrentMode();
  
  bool get _hasUrgentIssues {
    // Check for urgent issues: stok = 0, order overdue, batch expired
    // TODO: Implement actual checks from data
    return false;
  }
  
  MoodTone get _mood => DashboardMoodEngine.getMoodTone(
    mode: _mode,
    hasUrgentIssues: _hasUrgentIssues,
  );

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
              Expanded(
                child: Text(
                  _mood == MoodTone.urgent 
                      ? 'Perhatian Diperlukan'
                      : '✨ Cadangan Untuk Hari Ini',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    final maxSuggestions = DashboardMoodEngine.getMaxSuggestions(_mode);

    // No sales today
    if (data.today.inflow <= 0 && data.today.transactions == 0) {
      items.add(
        _InsightItem(
          icon: Icons.trending_down_rounded,
          color: DashboardUXCopy.getSuggestionColor(type: 'no_sales', mood: _mood),
          title: DashboardUXCopy.getSuggestionTitle(type: 'no_sales', mood: _mood),
          message: DashboardUXCopy.getSuggestionMessage(
            type: 'no_sales',
            mood: _mood,
          ),
          actionLabel: DashboardUXCopy.getCTAText(action: 'add_sale', mood: _mood),
          onAction: onAddSale,
        ),
      );
    }

    // Expense exceeds inflow
    if (data.today.inflow > 0 && data.today.expense > data.today.inflow) {
      items.add(
        _InsightItem(
          icon: Icons.warning_amber_rounded,
          color: DashboardUXCopy.getSuggestionColor(type: 'high_expense', mood: _mood),
          title: DashboardUXCopy.getSuggestionTitle(type: 'high_expense', mood: _mood),
          message: DashboardUXCopy.getSuggestionMessage(
            type: 'high_expense',
            mood: _mood,
            data: {
              'expense': data.today.expense,
              'inflow': data.today.inflow,
            },
          ),
          actionLabel: DashboardUXCopy.getCTAText(action: 'view_expense', mood: _mood),
          onAction: onAddExpense,
        ),
      );
    }

    // Week net negative
    if (data.week.net < 0) {
      items.add(
        _InsightItem(
          icon: Icons.waterfall_chart_rounded,
          color: DashboardUXCopy.getSuggestionColor(type: 'high_expense', mood: _mood),
          title: DashboardUXCopy.getSuggestionTitle(type: 'high_expense', mood: _mood),
          message: DashboardUXCopy.getSuggestionMessage(
            type: 'high_expense',
            mood: _mood,
            data: {'net': data.week.net},
          ),
          actionLabel: DashboardUXCopy.getCTAText(action: 'view_sales', mood: _mood),
          onAction: onViewSales,
        ),
      );
    }

    // Top performing product
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
          actionLabel: DashboardUXCopy.getCTAText(action: 'view_finished_stock', mood: _mood),
          onAction: onViewFinishedStock,
        ),
      );
    }

    // Limit based on mode (PAGI = 1, TENGAH HARI = 2, etc.)
    return items.take(maxSuggestions).toList();
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


