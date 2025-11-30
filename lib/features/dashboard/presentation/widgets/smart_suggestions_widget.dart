import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Smart Suggestions Widget
/// Provides actionable insights and recommendations
/// Helps SME owners make better decisions
class SmartSuggestionsWidget extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? todayStats;

  const SmartSuggestionsWidget({
    super.key,
    this.stats,
    this.todayStats,
  });

  List<Map<String, dynamic>> _getSuggestions() {
    final suggestions = <Map<String, dynamic>>[];

    // Check today's revenue
    final todayRevenue = todayStats?['todayRevenue'] ?? 0.0;
    final yesterdayRevenue = todayStats?['yesterdayRevenue'] ?? 0.0;

    if (todayRevenue == 0 && yesterdayRevenue > 0) {
      suggestions.add({
        'icon': Icons.trending_down,
        'title': 'Tiada Jualan Hari Ini',
        'message': 'Belum ada jualan hari ini. Fokus pada promosi!',
        'action': 'Buat Jualan',
        'color': Colors.orange,
        'route': '/sales/create',
      });
    } else if (todayRevenue < yesterdayRevenue * 0.5) {
      suggestions.add({
        'icon': Icons.insights,
        'title': 'Jualan Menurun',
        'message': 'Jualan hari ini lebih rendah dari semalam. Pertimbangkan promosi.',
        'action': 'Lihat Analitik',
        'color': Colors.blue,
        'route': '/sales',
      });
    }

    // Check pending bookings
    final pendingBookings = stats?['pending'] ?? 0;
    if (pendingBookings > 5) {
      suggestions.add({
        'icon': Icons.event_busy,
        'title': 'Banyak Tempahan Tertunggak',
        'message': 'Anda ada $pendingBookings tempahan yang perlu disahkan.',
        'action': 'Urus Tempahan',
        'color': AppColors.warning,
        'route': '/bookings',
      });
    }

    // Check low stock
    final lowStockCount = todayStats?['lowStockCount'] ?? 0;
    if (lowStockCount > 0) {
      suggestions.add({
        'icon': Icons.inventory_2,
        'title': 'Stok Perlu Diisi',
        'message': 'Ada $lowStockCount item stok rendah. Buat purchase order sekarang.',
        'action': 'Buat PO',
        'color': Colors.red,
        'route': '/shopping-list',
      });
    }

    // Check if no sales today but has bookings
    if (todayRevenue == 0 && pendingBookings > 0) {
      suggestions.add({
        'icon': Icons.lightbulb,
        'title': 'Tip: Tukar Tempahan ke Jualan',
        'message': 'Anda ada tempahan yang boleh ditukar kepada jualan untuk meningkatkan revenue.',
        'action': 'Lihat Tempahan',
        'color': AppColors.primary,
        'route': '/bookings',
      });
    }

    // Default suggestion if no specific issues
    if (suggestions.isEmpty) {
      suggestions.add({
        'icon': Icons.rocket_launch,
        'title': 'Prestasi Baik!',
        'message': 'Teruskan momentum! Pertimbangkan untuk expand produk atau servis.',
        'action': 'Lihat Produk',
        'color': AppColors.success,
        'route': '/products',
      });
    }

    return suggestions.take(2).toList(); // Show max 2 suggestions
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _getSuggestions();

    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  Icons.lightbulb_outline_rounded,
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
                      'Cadangan Pintar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Insight untuk bisnes anda',
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
          const SizedBox(height: 16),
          ...suggestions.map((suggestion) => _buildSuggestionCard(
                context,
                suggestion,
              )),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(
    BuildContext context,
    Map<String, dynamic> suggestion,
  ) {
    final color = suggestion['color'] as Color;
    final route = suggestion['route'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                suggestion['icon'] as IconData,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion['title'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestion['message'] as String,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed(route);
              },
              icon: Icon(Icons.arrow_forward, size: 16, color: color),
              label: Text(
                suggestion['action'] as String,
                style: TextStyle(color: color),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

