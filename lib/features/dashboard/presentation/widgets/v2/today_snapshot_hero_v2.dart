import 'package:flutter/material.dart';
import 'package:pocketbizz/core/theme/app_colors.dart';
import 'dashboard_v2_format.dart';

class TodaySnapshotHeroV2 extends StatelessWidget {
  final double inflow;
  final double productionCost; // Kos Pengeluaran
  final double profit;
  final double expense; // Belanja (untuk info sahaja)

  const TodaySnapshotHeroV2({
    super.key,
    required this.inflow,
    required this.productionCost,
    required this.profit,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final profitColor = profit >= 0 ? AppColors.success : Colors.red;
    final bgGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF0FDFA), // teal-50 (soft)
        Color(0xFFEFF6FF), // blue-50 (soft)
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Expanded(
                child: Text(
                  'Hari Ini',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Tooltip(
                message: 'Masuk termasuk tempahan & consignment',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.20)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Termasuk tempahan & vendor',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 1: Masuk & Kos
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Masuk',
                  value: DashboardV2Format.currency(inflow),
                  icon: Icons.savings_rounded,
                  accent: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Kos',
                  value: DashboardV2Format.currency(productionCost),
                  icon: Icons.factory_rounded,
                  accent: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Untung & Belanja
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: profitColor.withOpacity(0.22)),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: profitColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.auto_graph_rounded, color: profitColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Untung', style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              DashboardV2Format.currency(profit),
                              style: TextStyle(
                                color: profitColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Masuk - Kos',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: 'Jumlah duit keluar hari ini (untuk info sahaja)',
                  child: _MetricTile(
                    label: 'Belanja',
                    value: DashboardV2Format.currency(expense),
                    icon: Icons.payments_rounded,
                    accent: Colors.red,
                    isInfo: true, // Mark as info only
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isInfo; // For "Belanja" - info only, not part of profit calculation

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.isInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.20)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


