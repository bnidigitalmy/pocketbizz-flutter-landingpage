import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Smart Filters Widget
/// Quick filters and advanced filters for Stock Management
class SmartFiltersWidget extends StatelessWidget {
  final Map<String, bool> quickFilters;
  final Function(String) onQuickFilterToggle;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final VoidCallback onClearAll;

  const SmartFiltersWidget({
    super.key,
    required this.quickFilters,
    required this.onQuickFilterToggle,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = quickFilters.values.any((v) => v) || searchQuery.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Cari bahan...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => onSearchChanged(''),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 12),

        // Quick Filters
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              context,
              label: 'Stok Rendah',
              icon: Icons.warning_amber,
              isActive: quickFilters['lowStock'] ?? false,
              onTap: () => onQuickFilterToggle('lowStock'),
              color: AppColors.warning,
            ),
            _buildFilterChip(
              context,
              label: 'Habis Stok',
              icon: Icons.block,
              isActive: quickFilters['outOfStock'] ?? false,
              onTap: () => onQuickFilterToggle('outOfStock'),
              color: AppColors.error,
            ),
            _buildFilterChip(
              context,
              label: 'Ada Stok',
              icon: Icons.check_circle,
              isActive: quickFilters['inStock'] ?? false,
              onTap: () => onQuickFilterToggle('inStock'),
              color: AppColors.success,
            ),
            if (hasActiveFilters)
              _buildFilterChip(
                context,
                label: 'Clear All',
                icon: Icons.clear_all,
                isActive: false,
                onTap: onClearAll,
                color: Colors.grey,
                isOutlined: true,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
    bool isOutlined = false,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? Colors.white : (isOutlined ? Colors.grey : color),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: color,
      backgroundColor: isOutlined ? Colors.white : color.withOpacity(0.1),
      side: BorderSide(
        color: isActive ? color : (isOutlined ? Colors.grey[300]! : color.withOpacity(0.3)),
      ),
      labelStyle: TextStyle(
        color: isActive ? Colors.white : (isOutlined ? Colors.grey : color),
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

