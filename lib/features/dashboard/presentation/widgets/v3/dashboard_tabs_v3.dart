import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';

/// Dashboard Tab Item
class DashboardTab {
  final String label;
  final IconData icon;

  const DashboardTab({
    required this.label,
    required this.icon,
  });
}

/// Dashboard Tabs V3 - Tab navigation bar with smooth sliding indicator
class DashboardTabsV3 extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<DashboardTab> tabs;

  const DashboardTabsV3({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.tabs = const [
      DashboardTab(label: 'Ringkasan', icon: Icons.dashboard_outlined),
      DashboardTab(label: 'Jualan', icon: Icons.point_of_sale_outlined),
      DashboardTab(label: 'Stok', icon: Icons.inventory_2_outlined),
      DashboardTab(label: 'Insight', icon: Icons.lightbulb_outline),
    ],
  });

  @override
  State<DashboardTabsV3> createState() => _DashboardTabsV3State();
}

class _DashboardTabsV3State extends State<DashboardTabsV3>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _indicatorAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _indicatorAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.value = 1.0;
  }

  @override
  void didUpdateWidget(DashboardTabsV3 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _previousIndex = oldWidget.selectedIndex;
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / widget.tabs.length;

          return Stack(
            children: [
              // Sliding indicator
              AnimatedBuilder(
                animation: _indicatorAnimation,
                builder: (context, child) {
                  final currentLeft = widget.selectedIndex * tabWidth;
                  final previousLeft = _previousIndex * tabWidth;
                  final left = previousLeft + (currentLeft - previousLeft) * _indicatorAnimation.value;

                  return Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Tab items
              Row(
                children: List.generate(widget.tabs.length, (index) {
                  final tab = widget.tabs[index];
                  final isSelected = index == widget.selectedIndex;

                  return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (!isSelected) {
                            HapticFeedback.selectionClick();
                          }
                          widget.onTabSelected(index);
                        },
                        borderRadius: BorderRadius.circular(10),
                        splashColor: AppColors.primary.withOpacity(0.15),
                        highlightColor: AppColors.primary.withOpacity(0.08),
                        child: _TabItem(
                          tab: tab,
                          isSelected: isSelected,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final DashboardTab tab;
  final bool isSelected;

  const _TabItem({
    required this.tab,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : Colors.grey.shade500;
    final icon = isSelected ? _getFilledIcon(tab.icon) : tab.icon;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            tab.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Get filled version of outlined icon
  IconData _getFilledIcon(IconData icon) {
    if (icon == Icons.dashboard_outlined) return Icons.dashboard;
    if (icon == Icons.point_of_sale_outlined) return Icons.point_of_sale;
    if (icon == Icons.inventory_2_outlined) return Icons.inventory_2;
    if (icon == Icons.lightbulb_outline) return Icons.lightbulb;
    return icon;
  }
}
