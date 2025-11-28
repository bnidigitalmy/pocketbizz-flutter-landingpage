import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF006E7F);
  static const secondary = Color(0xFFF8CB2E);
  static const background = Color(0xFFF5F6FB);
  static const surface = Colors.white;
  static const success = Color(0xFF2EC4B6);
  static const danger = Color(0xFFEF476F);
  static const textPrimary = Color(0xFF1F2933);
  static const textSecondary = Color(0xFF6B7280);
}

class AppTheme {
  static final lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textSecondary,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    useMaterial3: true,
  );

  static final darkTheme = lightTheme;
}

