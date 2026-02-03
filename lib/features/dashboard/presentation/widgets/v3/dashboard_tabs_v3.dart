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

/// Dashboard Tabs V3 - Tab navigation bar
class DashboardTabsV3 extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
