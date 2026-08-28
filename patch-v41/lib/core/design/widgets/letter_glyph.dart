import 'package:flutter/material.dart';
import '../../../features/lesson/writing/letter_trace_template.dart';

/// Fits the actual ink bounds, including dots and vowel marks, not font metrics.
/// All known lesson letters share their writing template; no glyph is clipped.
class LetterGlyph extends StatelessWidget {
  const LetterGlyph(this.letter,
      {super.key, this.color = const Color(0xFFC54958)});
  final String letter;
  final Color color;

  static LetterTraceTemplate? templateFor(String letter) => switch (letter) {
        'أَ' || 'أ' => alifFathaVideoTemplate,
        'بَ' || 'ب' => baaFathaTemplate,
        'تَ' || 'ت' => taaFathaTemplate,
        _ => additionalLetterGlyphTemplates[letter],
      };

  @override
  Widget build(BuildContext context) {
    final template = templateFor(letter);
    return Semantics(
        label: letter,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: template == null
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Text(letter,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 80,
                              height: 1.8,
                              color: color,
                              fontWeight: FontWeight.bold))))
              : CustomPaint(
                  painter: LetterGlyphPainter(template, color,
                      includeVowel: letter.contains('َ')),
                  child: const SizedBox.expand()),
        ));
  }
}

class LetterGlyphPainter extends CustomPainter {
  const LetterGlyphPainter(this.template, this.color,
      {this.includeVowel = true});
  final LetterTraceTemplate template;
  final Color color;
  final bool includeVowel;

  Rect fittedRect(Size size) {
    final width = size.width.clamp(0.0, size.height * template.aspectRatio);
    final height = width / template.aspectRatio;
    return Rect.fromLTWH(
        (size.width - width) / 2, (size.height - height) / 2, width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = fittedRect(size);
    for (final part in template.parts) {
      if (!includeVowel && part.id == 'fatha') continue;
      canvas.drawPath(part.outlinePath(rect), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(LetterGlyphPainter old) =>
      old.template != template ||
      old.color != color ||
      old.includeVowel != includeVowel;
}
