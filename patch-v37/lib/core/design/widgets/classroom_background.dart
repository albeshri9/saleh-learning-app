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
        Image.asset(
          asset,
          fit: BoxFit.cover,
          // نحافظ على الأرض والسجادة داخل الكادر الأفقي؛ القص يقع من
          // أعلى الصورة عند اختلاف النسبة بدل اختفاء خط وقوف صالح.
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.high,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0x0AFFF8EC)),
        ),
        child,
      ],
    );
  }
}
