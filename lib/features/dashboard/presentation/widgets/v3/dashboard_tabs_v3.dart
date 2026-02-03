import 'package:flutter/material.dart';
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
                    child: GestureDetector(
                      onTap: () => widget.onTabSelected(index),
                      behavior: HitTestBehavior.opaque,
                      child: _TabItem(
                        tab: tab,
                        isSelected: isSelected,
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

class _TabItem extends StatefulWidget {
  final DashboardTab tab;
  final bool isSelected;

  const _TabItem({
    required this.tab,
    required this.isSelected,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.isSelected ? _getFilledIcon(widget.tab.icon) : widget.tab.icon,
                  key: ValueKey(widget.isSelected),
                  size: 18,
                  color: widget.isSelected
                      ? AppColors.primary
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: widget.isSelected
                        ? AppColors.primary
                        : Colors.grey.shade500,
                  ),
                  child: Text(
                    widget.tab.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get filled version of outlined icon
  IconData _getFilledIcon(IconData icon) {
    // Map outlined icons to filled versions
    if (icon == Icons.dashboard_outlined) return Icons.dashboard;
    if (icon == Icons.point_of_sale_outlined) return Icons.point_of_sale;
    if (icon == Icons.inventory_2_outlined) return Icons.inventory_2;
    if (icon == Icons.lightbulb_outline) return Icons.lightbulb;
    return icon;
  }
}
