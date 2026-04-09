import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_colors.dart';
import '../constants/storage_keys.dart';

// ── ThemeMode notifier ────────────────────────────────────────────────────────
final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final box = Hive.box<String>(StorageKeys.preferencesBox);
  final saved = box.get('theme_mode');
  final initial = saved == 'dark'
      ? ThemeMode.dark
      : saved == 'light'
          ? ThemeMode.light
          : ThemeMode.system;
  return ThemeNotifier(initial);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(super.initial);

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    Hive.box<String>(StorageKeys.preferencesBox)
        .put('theme_mode', state == ThemeMode.dark ? 'dark' : 'light');
  }
}

// ── Theme definitions ─────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static const _fontFamily = null; // Uses system default (Roboto on Android)

  static ThemeData get light => _build(brightness: Brightness.light);
  static ThemeData get dark => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isDark ? AppColors.primaryContainerDark : AppColors.primaryLight,
      onPrimaryContainer: isDark ? AppColors.onPrimaryContainerDark : AppColors.onSurface,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? AppColors.secondaryContainerDark : AppColors.secondaryLight,
      onSecondaryContainer: isDark ? AppColors.onSecondaryContainerDark : AppColors.onSurface,
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? AppColors.surfaceDark : AppColors.surface,
      onSurface: isDark ? AppColors.onSurfaceDark : AppColors.onSurface,
      surfaceContainerHighest:
          isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      onSurfaceVariant:
          isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariant,
      outline: isDark ? AppColors.outlineDark : AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor: isDark ? AppColors.onSurfaceDark : AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? AppColors.outlineDark : AppColors.outline,
            width: 1,
          ),
        ),
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariant,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        indicatorColor: isDark
            ? AppColors.primaryContainerDark
            : AppColors.primaryLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
                color: isDark ? AppColors.onPrimaryContainerDark : AppColors.primary);
          }
          return IconThemeData(
              color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? (isDark ? AppColors.onPrimaryContainerDark : AppColors.primary)
              : (isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariant);
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.normal,
            color: color,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
