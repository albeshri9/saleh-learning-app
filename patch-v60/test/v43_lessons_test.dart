import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/services/speech/speech_service.dart';
import 'v38_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(support.seed);
  for (final entry in {
    'thaa': thaaFathaTemplate,
    'jeem': jeemFathaTemplate,
    'haa': haaFathaTemplate
  }.entries) {
    test('${entry.key} coverage and cumulative review', () {
      final t = entry.value;
      expect(LetterTraceTemplate.fromId(t.id), same(t));
      expect(t.guideParts.first.id, 'body');
      expect(t.guideParts.last.id, 'fatha');
      expect(t.parts.where((p) => p.isDot).length,
          {'thaa': 3, 'jeem': 1, 'haa': 0}[entry.key]);
      const size = Size(480, 220);
      final ink = [
        for (var i = 0; i < t.parts.length; i++) t.samples(size, i, count: 150)
      ];
      expect(
          validateDottedLetterWriting(
                  WritingSample(strokes: ink, canvasSize: size), t)
              .isValid,
          isTrue);
      expect(
          validateDottedLetterWriting(
                  WritingSample(strokes: [ink.last], canvasSize: size), t)
              .isValid,
          isFalse);
      final data = jsonDecode(
          File('assets/content/lesson_${entry.key}.json').readAsStringSync());
      final reviews = (data['scenes'] as List)
          .firstWhere((s) => s['type'] == 'review')['data'];
      expect(reviews['questions'].length,
          {'thaa': 6, 'jeem': 8, 'haa': 10}[entry.key]);
    });
  }
  test('letter speech names do not accept other letters', () {
    expect(speechMatchesExpected('ثاء', 'ثَا'), isTrue);
    expect(speechMatchesExpected('جيم', 'جَا'), isTrue);
    expect(speechMatchesExpected('حاء', 'حَا'), isTrue);
    expect(speechMatchesExpected('هاء', 'حَا'), isFalse);
    expect(speechMatchesExpected('خاء', 'حَا'), isFalse);
  });
  testWidgets('new scenes fit phone boards', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      for (final id in ['thaa', 'jeem', 'haa']) {
        for (var i = 0; i < 9; i++) {
          await tester.pumpWidget(
              support.app(LessonScreen(lessonId: id, initialScene: i)));
          await support.frames(tester, 12);
          expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$id/$i/$size');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
      }
    }
  });
}
