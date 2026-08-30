import 'package:flutter/material.dart';

/// خلفية الفصل المعتمدة من المرجع البصري النهائي.
///
/// تمتد الصورة إلى كامل الشاشة، بينما تتولى [SafeArea] داخل الشاشة حماية
/// المحتوى من نتوء الآيفون وأشرطة النظام. التموضع العلوي يحافظ على الجدار
/// الفاتح في الوسط وعلى السجادة أسفل مساحة الدرس في مختلف النسب الأفقية.
class ClassroomBackground extends StatelessWidget {
  const ClassroomBackground(
      {super.key,
      required this.child,
      this.asset = 'assets/backgrounds/classroom_main.jpg'});

  final Widget child;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          key: const ValueKey('full-screen-background-switcher'),
          duration: const Duration(milliseconds: 420),
          reverseDuration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // AnimatedSwitcher uses a loose, centered Stack by default. That
          // briefly showed the scaffold colour as two purple side bars while
          // changing worlds. Every outgoing and incoming background must stay
          // pinned to the complete viewport for the whole transition.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.025, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          ),
          child: SizedBox.expand(
            key: ValueKey(asset),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              // نحافظ على الأرض والسجادة داخل الكادر الأفقي؛ القص يقع من
              // أعلى الصورة عند اختلاف النسبة بدل اختفاء خط وقوف صالح.
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0x0AFFF8EC)),
        ),
        child,
      ],
    );
  }
}
