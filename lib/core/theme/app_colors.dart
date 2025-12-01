import 'package:flutter/material.dart';

/// PocketBizz Brand Colors - Matching Official Logo
/// Logo Gradient: Teal/Green (top) to Bright Blue (bottom)
/// Modern, Professional, Trustworthy
class AppColors {
  // Primary Colors - Logo Gradient Colors
  // Top: Vibrant Teal/Light Green (from logo top)
  static const primary = Color(0xFF14B8A6);        // Vibrant Teal (logo top)
  static const primaryDark = Color(0xFF0D9488);    // Deep Teal
  static const primaryLight = Color(0xFF2DD4BF);   // Light Teal
  
  // Accent Colors - Logo Gradient Bottom
  // Bottom: Bright Light Blue (from logo bottom)
  static const accent = Color(0xFF3B82F6);         // Bright Blue (logo bottom)
  static const secondary = Color(0xFF3B82F6);      // Alias for accent (for Material theme)
  static const accentLight = Color(0xFF60A5FA);    // Light Blue
  static const accentDark = Color(0xFF2563EB);      // Deep Blue
  
  // Status Colors
  static const success = Color(0xFF14B8A6);        // Teal (matches primary)
  static const successLight = Color(0xFF2DD4BF);
  static const warning = Color(0xFFF59E0B);        // Amber (for warnings)
  static const warningLight = Color(0xFFFBBF24);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFF87171);
  static const info = Color(0xFF3B82F6);          // Blue (matches accent)
  static const infoLight = Color(0xFF60A5FA);
  
  // Neutral Colors - Clean & Professional
  static const background = Color(0xFFF9FAFB);     // Very light grey
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF3F4F6);
  
  // Text Colors - Professional Charcoal
  static const textPrimary = Color(0xFF1F2937);    // Deep charcoal
  static const textSecondary = Color(0xFF6B7280);  // Medium grey
  static const textHint = Color(0xFF9CA3AF);       // Light grey
  
  // Gradients - PocketBizz Official Logo Gradient
  // Matches logo: Teal/Green (top) to Bright Blue (bottom)
  static const logoGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const warningGradient = LinearGradient(
    colors: [warning, warningLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Premium gradient for special cards - matches logo
  static const premiumGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows - Soft & Modern
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primary.withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> accentButtonShadow = [
    BoxShadow(
      color: accent.withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

