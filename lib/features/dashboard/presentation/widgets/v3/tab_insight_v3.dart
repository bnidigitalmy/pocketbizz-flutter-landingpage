import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../domain/sme_dashboard_v2_models.dart';

/// Insight item model
class InsightItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  InsightItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });
}

/// Tab Insight - Smart suggestions and AI-like insights
class TabInsightV3 extends StatefulWidget {
  final SmeDashboardV2Data? data;
  final bool hasUrgentIssues;
  final VoidCallback onStartProduction;
  final VoidCallback onAddSale;
  final VoidCallback onViewFinishedProducts;

  const TabInsightV3({
    super.key,
    required this.data,
    this.hasUrgentIssues = false,
    required this.onStartProduction,
    required this.onAddSale,
    required this.onViewFinishedProducts,
  });

  @override
  State<TabInsightV3> createState() => _TabInsightV3State();
}

class _TabInsightV3State extends State<TabInsightV3> {
  final Set<String> _dismissedInsights = {};

  List<InsightItem> _generateInsights() {
    final insights = <InsightItem>[];
    final data = widget.data;

    if (data == null) return insights;

    // 1. Production suggestion
    if (data.productionSuggestion.show) {
      insights.add(InsightItem(
        id: 'production_suggestion',
        title: 'Cadangan Produksi',
        description: data.productionSuggestion.message,
        icon: Icons.factory_rounded,
        color: Colors.purple,
        actionLabel: 'Mula Produksi',
        onAction: widget.onStartProduction,
        onDismiss: () => _dismissInsight('production_suggestion'),
      ));
    }

    // 2. No sales today
    if (data.today.inflow == 0) {
      insights.add(InsightItem(
        id: 'no_sales_today',
        title: 'Tiada Jualan',
        description: 'Belum ada jualan hari ini. Jom tambah jualan pertama!',
        icon: Icons.shopping_cart_outlined,
        color: Colors.blue,
        actionLabel: 'Tambah Jualan',
        onAction: widget.onAddSale,
        onDismiss: () => _dismissInsight('no_sales_today'),
      ));
    }

    // 3. Top product insight
    if (data.topProducts.weekTop3.isNotEmpty) {
      final topProduct = data.topProducts.weekTop3.first;
      insights.add(InsightItem(
        id: 'top_product',
        title: 'Produk Terlaris',
        description: '${topProduct.name} adalah produk paling laris minggu ini dengan ${topProduct.unitsSold} unit terjual.',
        icon: Icons.emoji_events_rounded,
        color: Colors.amber,
        actionLabel: 'Pastikan Stok',
        onAction: widget.onViewFinishedProducts,
        onDismiss: () => _dismissInsight('top_product'),
      ));
    }

    // 4. Profit insight
    if (data.week.net > 0) {
      final profitPercent = data.week.inflow > 0
          ? (data.week.net / data.week.inflow * 100).toStringAsFixed(0)
          : '0';
      insights.add(InsightItem(
        id: 'profit_positive',
        title: 'Prestasi Baik!',
        description: 'Margin untung minggu ini adalah $profitPercent%. Teruskan usaha!',
        icon: Icons.trending_up_rounded,
        color: Colors.green,
        onDismiss: () => _dismissInsight('profit_positive'),
      ));
    } else if (data.week.net < 0) {
      insights.add(InsightItem(
        id: 'profit_negative',
        title: 'Perlu Perhatian',
        description: 'Minggu ini dalam kerugian. Semak kos dan tingkatkan jualan.',
        icon: Icons.trending_down_rounded,
        color: Colors.red,
        onDismiss: () => _dismissInsight('profit_negative'),
      ));
    }

    // Filter out dismissed insights
    return insights.where((i) => !_dismissedInsights.contains(i.id)).toList();
  }

  void _dismissInsight(String id) {
    setState(() {
      _dismissedInsights.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();

    if (insights.isEmpty) {
      return _buildNoInsights();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cadangan Hari Ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${insights.length} insight',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        // Insight cards
        ...insights.take(3).map((insight) => _buildInsightCard(insight)),
      ],
    );
  }

  Widget _buildNoInsights() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Tiada Cadangan Buat Masa Ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kami akan beri cadangan apabila ada peluang.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(InsightItem insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: insight.color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: insight.color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: insight.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  insight.icon,
                  color: insight.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  insight.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (insight.onDismiss != null)
                IconButton(
                  onPressed: insight.onDismiss,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          if (insight.actionLabel != null && insight.onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: insight.onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: insight.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  insight.actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
