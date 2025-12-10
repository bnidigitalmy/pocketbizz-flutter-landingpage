import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standard PocketBizz Floating Action Button
/// Consistent teal background with white text and icon
class PocketBizzFAB extends StatelessWidget {
  const PocketBizzFAB({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon = Icons.add,
    this.location = FloatingActionButtonLocation.endFloat,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final FloatingActionButtonLocation location;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

