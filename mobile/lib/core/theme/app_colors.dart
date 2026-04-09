import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Brand
  static const Color primary = Color(0xFF1A73E8);
  static const Color primaryDark = Color(0xFF1557B0);
  static const Color primaryLight = Color(0xFFD2E3FC);

  static const Color secondary = Color(0xFF34A853);
  static const Color secondaryDark = Color(0xFF1E7E34);
  static const Color secondaryLight = Color(0xFFCEEAD6);

  // Semantic
  static const Color success = Color(0xFF34A853);
  static const Color warning = Color(0xFFFBBC04);
  static const Color error = Color(0xFFEA4335);
  static const Color info = Color(0xFF4285F4);

  // Expense / income
  static const Color expense = Color(0xFFEA4335);
  static const Color income = Color(0xFF34A853);
  static const Color neutral = Color(0xFF9AA0A6);

  // Risk levels
  static const Color riskGreen = Color(0xFF34A853);
  static const Color riskYellow = Color(0xFFFBBC04);
  static const Color riskRed = Color(0xFFEA4335);

  // Neutral shades (light)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  static const Color outline = Color(0xFFDEE0E3);
  static const Color onSurface = Color(0xFF202124);
  static const Color onSurfaceVariant = Color(0xFF5F6368);

  // Neutral shades (dark)
  static const Color surfaceDark = Color(0xFF1A1C1E);
  static const Color surfaceVariantDark = Color(0xFF252729);
  static const Color outlineDark = Color(0xFF3C3F43);
  static const Color onSurfaceDark = Color(0xFFE2E2E6);
  static const Color onSurfaceVariantDark = Color(0xFF8E9099);

  // Dark-mode containers (deep, low-saturation tints)
  static const Color primaryContainerDark = Color(0xFF0C2D6B);
  static const Color onPrimaryContainerDark = Color(0xFFB8D0FF);
  static const Color secondaryContainerDark = Color(0xFF0A3320);
  static const Color onSecondaryContainerDark = Color(0xFFA3DDB7);

  // Category palette (12 colors for chart segments)
  static const List<Color> categoryPalette = [
    Color(0xFFEA4335),
    Color(0xFF1A73E8),
    Color(0xFF34A853),
    Color(0xFFFBBC04),
    Color(0xFF9334E6),
    Color(0xFFFF6D00),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFF8BC34A),
    Color(0xFFFF5722),
  ];
}
