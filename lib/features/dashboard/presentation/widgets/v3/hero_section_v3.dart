import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/date_time_helper.dart';
import '../v2/dashboard_v2_format.dart';
import 'animated_counter.dart';

/// Hero Section V3 - The always-visible top section
/// Contains greeting, key metrics, and quick actions
/// With stagger animations on load
class HeroSectionV3 extends StatefulWidget {
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

  @override
  State<HeroSectionV3> createState() => _HeroSectionV3State();
}

class _HeroSectionV3State extends State<HeroSectionV3>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    if (widget.yesterdayInflow == null || widget.yesterdayInflow == 0) return null;
    return ((widget.todayInflow - widget.yesterdayInflow!) / widget.yesterdayInflow!) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final profitColor = widget.todayProfit >= 0 ? AppColors.success : Colors.red;
    final changePercent = _inflowChangePercent;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
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
                        widget.userName,
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
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onNotificationTap();
                      },
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Colors.grey.shade700,
                        size: 26,
                      ),
                    ),
                    if (widget.unreadNotifications > 0)
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
                            widget.unreadNotifications > 9 ? '9+' : '${widget.unreadNotifications}',
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
                  child: _AnimatedMetricCard(
                    label: 'Masuk',
                    numericValue: widget.todayInflow,
                    icon: Icons.savings_rounded,
                    iconColor: AppColors.success,
                    changePercent: changePercent,
                    delay: const Duration(milliseconds: 100),
                  ),
                ),
                const SizedBox(width: 12),
                // Untung (Profit)
                Expanded(
                  child: _AnimatedMetricCard(
                    label: 'Untung',
                    numericValue: widget.todayProfit,
                    icon: Icons.trending_up_rounded,
                    iconColor: profitColor,
                    valueColor: profitColor,
                    subtitle: 'bersih',
                    delay: const Duration(milliseconds: 200),
                  ),
                ),
                const SizedBox(width: 12),
                // Transaction Count
                Expanded(
                  child: _AnimatedMetricCard(
                    label: 'Transaksi',
                    numericValue: widget.todayTransactionCount.toDouble(),
                    isCurrency: false,
                    icon: Icons.receipt_long_rounded,
                    iconColor: Colors.blue,
                    isCompact: true,
                    delay: const Duration(milliseconds: 300),
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
                    onTap: widget.onAddSale,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    label: '+ Stok',
                    icon: Icons.inventory_2_rounded,
                    color: Colors.blue,
                    onTap: widget.onAddStock,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickActionButton(
                    label: 'Produksi',
                    icon: Icons.factory_rounded,
                    color: Colors.purple,
                    onTap: widget.onStartProduction,
                  ),
                ),
                const SizedBox(width: 10),
                _QuickActionButton(
                  label: 'Lagi',
                  icon: Icons.grid_view_rounded,
                  color: Colors.grey.shade600,
                  onTap: widget.onMoreActions,
                  isCompact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }
}

/// Animated Metric Card with stagger delay and counter animation
class _AnimatedMetricCard extends StatefulWidget {
  final String label;
  final double numericValue;
  final IconData icon;
  final Color iconColor;
  final Color? valueColor;
  final double? changePercent;
  final String? subtitle;
  final bool isCompact;
  final bool isCurrency;
  final Duration delay;

  const _AnimatedMetricCard({
    required this.label,
    required this.numericValue,
    required this.icon,
    required this.iconColor,
    this.valueColor,
    this.changePercent,
    this.subtitle,
    this.isCompact = false,
    this.isCurrency = true,
    this.delay = Duration.zero,
  });

  @override
  State<_AnimatedMetricCard> createState() => _AnimatedMetricCardState();
}

class _AnimatedMetricCardState extends State<_AnimatedMetricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        setState(() => _started = true);
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.all(widget.isCompact ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.iconColor.withOpacity(0.15)),
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
                      color: widget.iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 16),
                  ),
                  const Spacer(),
                  if (widget.changePercent != null)
                    _ChangeIndicator(changePercent: widget.changePercent!),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              // Animated counter
              _started
                  ? AnimatedCounter(
                      value: widget.numericValue,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontSize: widget.isCompact ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: widget.valueColor ?? AppColors.textPrimary,
                      ),
                      formatter: widget.isCurrency
                          ? (v) => DashboardV2Format.currency(v)
                          : (v) => v.toInt().toString(),
                    )
                  : Text(
                      widget.isCurrency ? 'RM 0' : '0',
                      style: TextStyle(
                        fontSize: widget.isCompact ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: widget.valueColor ?? AppColors.textPrimary,
                      ),
                    ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade500,
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

/// Change percentage indicator with animation
class _ChangeIndicator extends StatelessWidget {
  final double changePercent;

  const _ChangeIndicator({required this.changePercent});

  @override
  Widget build(BuildContext context) {
    final isPositive = changePercent >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(10 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              '${changePercent.abs().toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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

class _QuickActionButton extends StatefulWidget {
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
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 12 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: widget.isCompact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(widget.icon, color: widget.color, size: 18),
              if (!widget.isCompact) ...[
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
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
