import 'package:flutter/material.dart';
import 'app_colors.dart';

/// الطبقة الطباعية الموحدة — خط «تجوال» المعتمد في الهوية البصرية.
abstract class AppTypography {
  static const String fontFamily = 'Tajawal';

  static const display = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.2,
  );

  /// الحرف الكبير موضوع الدرس.
  static const letterHero = TextStyle(
    fontSize: 160,
    fontWeight: FontWeight.w700,
    color: AppColors.letterPrimary,
    height: 1.1,
  );

  static const title = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.3,
  );

  static const subtitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.inkSoft,
    height: 1.4,
  );

  /// كلام صالح داخل فقاعات الحوار.
  static const speech = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
    height: 1.6,
  );

  static const body = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
    height: 1.5,
  );

  static const button = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  static const caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.inkSoft,
  );
}
