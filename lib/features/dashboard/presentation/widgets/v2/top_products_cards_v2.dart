import 'package:flutter/material.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';
import '../../../domain/sme_dashboard_v2_models.dart';
import 'dashboard_v2_format.dart';

class TopProductsCardsV2 extends StatelessWidget {
  final List<TopProductUnits> todayTop3;
  final List<TopProductUnits> weekTop3;

  const TopProductsCardsV2({
    super.key,
    required this.todayTop3,
    required this.weekTop3,
  });

  @override
  Widget build(BuildContext context) {
    if (todayTop3.isEmpty && weekTop3.isEmpty) {
      return const SizedBox.shrink();
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Column(
        children: [
          _TopListCard(
            title: 'Top Produk Hari Ini',
            subtitle: 'Ikut kuantiti (unit)',
            icon: Icons.bolt_rounded,
            color: Colors.orange,
            items: todayTop3,
          ),
          const SizedBox(height: 12),
          _TopListCard(
            title: 'Top Produk Minggu Ini',
            subtitle: 'Ahad → Sabtu • ikut kuantiti (unit)',
            icon: Icons.calendar_month_rounded,
            color: AppColors.primary,
            items: weekTop3,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TopListCard(
            title: 'Top Produk Hari Ini',
            subtitle: 'Ikut kuantiti (unit)',
            icon: Icons.bolt_rounded,
            color: Colors.orange,
            items: todayTop3,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopListCard(
            title: 'Top Produk Minggu Ini',
            subtitle: 'Ahad → Sabtu • ikut kuantiti (unit)',
            icon: Icons.calendar_month_rounded,
            color: AppColors.primary,
            items: weekTop3,
          ),
        ),
      ],
    );
  }
}

class _TopListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<TopProductUnits> items;

  const _TopListCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              'Belum ada data untuk tempoh ini.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            Column(
              children: items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final display = item.displayName.isNotEmpty ? item.displayName : item.key;
                final rank = idx + 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: idx == items.length - 1 ? 0 : 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.18)),
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          display,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          '${DashboardV2Format.units(item.units)} unit',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}


