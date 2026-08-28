import 'package:flutter/widgets.dart';

/// مقياس المسافات والزوايا الموحد. لا تستخدم أرقامًا حرة في الواجهات.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 12;
  static const double radiusMd = 20;
  static const double radiusLg = 28;
  static const double radiusPill = 100;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(radiusPill));

  /// أصغر حجم لمس مريح لأصابع الأطفال.
  static const double childTouchTarget = 64;
}

abstract class AppDurations {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 700);
  static const pulse = Duration(milliseconds: 550);
}
