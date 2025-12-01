import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.trailing,
    this.backgroundColor,
  });

  final String title;
  final String value;
  final IconData? icon;
  final Widget? trailing;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: backgroundColor ?? AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(icon, color: AppColors.primary),
                  ),
                if (icon != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

