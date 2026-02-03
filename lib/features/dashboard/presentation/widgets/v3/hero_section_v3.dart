import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_time_helper.dart';
import '../v2/dashboard_v2_format.dart';

/// Hero Section V3 - The always-visible top section
/// Contains greeting, key metrics, and quick actions
class HeroSectionV3 extends StatelessWidget {
  final String userName;
  final double todayInflow;
  final double todayProfit;
  final int todayTransactionCount;
  final double? yesterdayInflow;
  final VoidCallback onAddSale;
  final VoidCallback onAddStock;
  final VoidCallback onStartProduction;
  final VoidCallback onMoreActions;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;

  const HeroSectionV3({
    super.key,
    required this.userName,
    required this.todayInflow,
    required this.todayProfit,
    required this.todayTransactionCount,
    this.yesterdayInflow,
    required this.onAddSale,
    required this.onAddStock,
    required this.onStartProduction,
    required this.onMoreActions,
    required this.onNotificationTap,
    this.unreadNotifications = 0,
  });

  String get _greeting {
    final hour = DateTimeHelper.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 18) return 'Selamat Petang';
    return 'Selamat Malam';
  }

  String get _greetingEmoji {
    final hour = DateTimeHelper.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 18) return '🌤️';
    return '🌙';
  }

  double? get _inflowChangePercent {
    if (yesterdayInflow == null || yesterdayInflow == 0) return null;
    return ((todayInflow - yesterdayInflow!) / yesterdayInflow!) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final profitColor = todayProfit >= 0 ? AppColors.success : Colors.red;
    final changePercent = _inflowChangePercent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.08),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with greeting and notification
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$_greeting, ',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _greetingEmoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy', 'ms').format(DateTimeHelper.now()),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification Bell
                Stack(
                  children: [
                    IconButton(
                      onPressed: onNotificationTap,
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Colors.grey.shade700,
                        size: 26,
                      ),
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Key Metrics Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Masuk (Inflow)
                Expanded(
                  child: _MetricCard(
                    label: 'Masuk',
                    value: DashboardV2Format.currency(todayInflow),
                    icon: Icons.savings_rounded,
                    iconColor: AppColors.success,
                    changePercent: changePercent,
                  ),
                ),
                const SizedBox(width: 12),
                // Untung (Profit)
                Expanded(
                  child: _MetricCard(
                    label: 'Untung',
                    value: DashboardV2Format.currency(todayProfit),
                    icon: Icons.trending_up_rounded,
                    iconColor: profitColor,
                    valueColor: profitColor,
                    subtitle: 'bersih',
                  ),
                ),
                const SizedBox(width: 12),
                // Transaction Count
                Expanded(
                  child: _MetricCard(
                    label: 'Transaksi',
                    value: '$todayTransactionCount',
                    icon: Icons.receipt_long_rounded,
                    iconColor: Colors.blue,
                    isCompact: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    label: '+ Jual',
                    icon: Icons.add_shopping_cart_rounded,
                    color: AppColors.primary,
                    onTap: onAddSale,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    label: '+ Stok',
                    icon: Icons.inventory_2_rounded,
                    color: Colors.blue,
                    onTap: onAddStock,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    label: 'Produksi',
                    icon: Icons.factory_rounded,
                    color: Colors.purple,
                    onTap: onStartProduction,
                  ),
                ),
                const SizedBox(width: 10),
                _QuickActionButton(
                  label: 'Lagi',
                  icon: Icons.grid_view_rounded,
                  color: Colors.grey.shade600,
                  onTap: onMoreActions,
                  isCompact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;
  final double? changePercent;
  final String? subtitle;
  final bool isCompact;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.valueColor,
    this.changePercent,
    this.subtitle,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const Spacer(),
              if (changePercent != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: changePercent! >= 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        changePercent! >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 10,
                        color: changePercent! >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${changePercent!.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: changePercent! >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isCompact;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(icon, color: color, size: 18),
              if (!isCompact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
