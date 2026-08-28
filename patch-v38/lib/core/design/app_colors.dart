import 'package:flutter/material.dart';

/// لوحة الألوان المركزية — من الهوية البصرية المعتمدة لتطبيق صالح:
/// #AA90E2 · #6CC36C · #FFC857 · #FF8A3D · #8E78FF · #F7F3ED · #6B4E3D
abstract class AppColors {
  // ألوان الهوية المعتمدة
  static const brandPeriwinkle = Color(0xFFAA90E2);
  static const brandGreen = Color(0xFF6CC36C);
  static const brandYellow = Color(0xFFFFC857);
  static const brandOrange = Color(0xFFFF8A3D);
  static const brandViolet = Color(0xFF8E78FF);
  static const brandCream = Color(0xFFF7F3ED);
  static const brandBrown = Color(0xFF6B4E3D);

  // خلفيات — بيئة صف دافئة كريمية (وليست سماء زرقاء)
  static const background = brandCream;
  static const wallTop = Color(0xFFFBF8F2); // أعلى الجدار أفتح
  static const wallArch = Color(0xFFF1E9DC); // قوس/عمق معماري ناعم
  static const rug = Color(0xFFEDD9C4); // سجادة دافئة
  static const rugDeep = Color(0xFFE2C4A8);
  static const board = Color(0xFFFDF9F1); // سطح اللوح الكريمي
  static const boardEdge = brandBrown; // إطار اللوح الخشبي
  static const boardEdgeDark = Color(0xFF553C2E);
  static const surface = Colors.white; // البطاقات

  // نصوص
  static const ink = Color(0xFF4A3B63); // النص الأساسي (بنفسجي داكن دافئ)
  static const inkSoft = Color(0xFF8B7FA3);
  static const onDark = Colors.white;

  // ألوان دلالية للمحتوى التعليمي
  static const letterPrimary =
      Color(0xFFE05252); // الحرف موضوع الدرس (أحمر كما في الهوية)
  static const letterTraced = brandGreen; // المسار المكتمل
  static const letterGuide = Color(0xFFE4DCCE); // الحرف الباهت (الدليل)
  static const highlight = brandYellow; // توهج / إبراز

  // تفاعل
  static const primary = brandViolet;
  static const primaryDark = Color(0xFF6F5AE0);
  static const success = brandGreen;
  static const successDark = Color(0xFF4E9E50);
  static const accentBlue = brandPeriwinkle;
  static const accentBlueDark = Color(0xFF8A6ECC);
  static const orange = brandOrange;
  static const orangeDark = Color(0xFFE0702A);
  static const danger = Color(0xFFE05252);

  static const starGold = brandYellow;

  static const shadow = Color(0x2A6B4E3D); // ظل ناعم دافئ موحد

  // توافق خلفي مؤقت (تستخدمها الشاشة الرئيسية القديمة)
  static const sky = brandPeriwinkle;
  static const skyDeep = brandViolet;
  static const floor = rug;
}
