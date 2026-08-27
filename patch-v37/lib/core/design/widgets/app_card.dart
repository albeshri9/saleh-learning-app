import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_spacing.dart';

/// بطاقة مستديرة بعمق حقيقي — الوحدة البصرية الأساسية للمحتوى:
/// ظل مزدوج (قريب حاد + بعيد ناعم) وHighlight علوي فاتح خفيف
/// (تدرج عمودي ~2-3%) يمنحها استدارة ملموسة.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.55) ?? color,
            color,
            Color.lerp(color, AppColors.brandBrown, 0.03) ?? color,
          ],
          stops: const [0.0, 0.10, 1.0],
        ),
        borderRadius: AppSpacing.cardRadius,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 3),
        boxShadow: const [
          // ظل قريب حاد — تلامس
          BoxShadow(
            color: Color(0x306B4E3D),
            offset: Offset(0, 3),
            blurRadius: 5,
          ),
          // ظل بعيد ناعم — ارتفاع
          BoxShadow(
            color: Color(0x1C6B4E3D),
            offset: Offset(0, 12),
            blurRadius: 26,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// اتجاه ذيل فقاعة الكلام نحو صالح.
enum SpeechTailDirection {
  /// صالح أسفل الفقاعة (تخطيط الشاشات الواسعة).
  down,

  /// صالح في جهة البداية بجانب الفقاعة (تخطيط الهاتف، RTL-aware).
  start,
}

/// فقاعة كلام صالح — بذيل مثلثي صغير يشير نحوه وظل ناعم.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.color,
    this.tail = SpeechTailDirection.down,
    this.compact = false,
  });

  final Widget child;
  final Color? color;
  final SpeechTailDirection tail;
  final bool compact;

  static const _border = Color(0xFFEFE8DB);

  @override
  Widget build(BuildContext context) {
    final fill = color ?? Colors.white;
    final bubble = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : AppSpacing.lg,
        vertical: compact ? 6 : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            fill,
            Color.lerp(fill, AppColors.brandBrown, 0.025) ?? fill,
          ],
          stops: const [0.0, 0.14, 1.0],
        ),
        borderRadius: AppSpacing.cardRadius,
        border: Border.all(color: _border, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x186B4E3D),
            offset: Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: child,
    );

    final tailWidget = CustomPaint(
      size: const Size(20, 12),
      painter: _BubbleTailPainter(fill: fill, border: _border),
    );

    if (tail == SpeechTailDirection.down) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          bubble,
          Positioned(bottom: -10, child: tailWidget),
        ],
      );
    }
    // ذيل جانبي نحو جهة البداية (صالح): في RTL يشير يمينًا، وفي LTR يسارًا.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      clipBehavior: Clip.none,
      alignment: AlignmentDirectional.centerStart,
      children: [
        bubble,
        PositionedDirectional(
          start: -10,
          child: RotatedBox(quarterTurns: isRtl ? 3 : 1, child: tailWidget),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  _BubbleTailPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    // مثلث ناعم متماثل رأسه للأسفل (يُدار بـ RotatedBox عند الحاجة).
    final fillPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(
          size.width * 0.62, size.height * 0.35, size.width / 2, size.height)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.35, 0, 0)
      ..close();
    final paint = Paint()
      ..isAntiAlias = true
      ..color = fill;
    canvas.drawPath(fillPath, paint);
    // حدود الجانبين فقط — قاعدة الذيل تندمج مع جسم الفقاعة
    final sidePath = Path()
      ..moveTo(size.width, 0)
      ..quadraticBezierTo(
          size.width * 0.62, size.height * 0.35, size.width / 2, size.height)
      ..quadraticBezierTo(size.width * 0.38, size.height * 0.35, 0, 0);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = border;
    canvas.drawPath(sidePath, paint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) =>
      old.fill != fill || old.border != border;
}
