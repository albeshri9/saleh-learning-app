import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.sky,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.highlight,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.display,
        headlineMedium: AppTypography.title,
        titleMedium: AppTypography.subtitle,
        bodyLarge: AppTypography.body,
        // Explicit Arabic metrics on both platforms. Local TextStyles inherit
        // this leading instead of Material's much taller fallback line boxes.
        bodyMedium: AppTypography.body.copyWith(fontSize: 16, height: 1.25),
        labelLarge: AppTypography.button,
        bodySmall: AppTypography.caption,
      ),
      visualDensity: VisualDensity.standard,
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.cardRadius),
      ),
    );
  }
}
