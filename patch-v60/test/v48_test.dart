import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/models/curriculum.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/features/home/lessons_catalog.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/services/speech/speech_service.dart';

import 'v38_test.dart' as support;

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(support.seed);

  test('Khaa uses the approved body, one upper dot and complete guide', () {
    expect(LetterGlyph.templateFor('خَ'), same(khaaFathaTemplate));
    expect(LetterTraceTemplate.fromId('khaa_fatha_pdf_v1'),
        same(khaaFathaTemplate));
    expect(khaaFathaTemplate.guideParts.map((part) => part.id),
        ['body', 'dot1', 'fatha']);
    expect(khaaFathaTemplate.parts.where((part) => part.isDot).length, 1);
    const size = Size(480, 220);
    final strokes = [
      for (var i = 0; i < khaaFathaTemplate.guideParts.length; i++)
        khaaFathaTemplate.samples(size, i, count: 150),
    ];
    expect(
        validateDottedLetterWriting(
                WritingSample(strokes: strokes, canvasSize: size),
                khaaFathaTemplate)
            .isValid,
        isTrue);
  });

  test('Khaa content and checkpoint cover all seven letters', () {
    final lesson = json('assets/content/lesson_khaa.json');
    final review = (lesson['scenes'] as List)
        .firstWhere((scene) => scene['type'] == 'review')['data'] as Map;
    expect(review['priorLessonIds'],
        ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa']);
    expect((review['questions'] as List).length, 12);
    expect(jsonEncode(lesson), isNot(contains('فتحة')));
    final spoken = (lesson['scenes'] as List)
        .expand((scene) => (scene['lines'] as List).map((line) => line['male']))
        .join(' ');
    expect(spoken, isNot(contains('حرف الخاء')));
    expect(speechMatchesExpected('خاء', 'خَا'), isTrue);

    final checkpoint = json('assets/content/lesson_checkpoint_group_1.json');
    final scene = Scene.fromJson(
        (checkpoint['scenes'] as List).first as Map<String, dynamic>);
    expect(scene.type, SceneType.checkpoint);
    expect((scene.data['tasks'] as List).length, 16);
    expect((scene.data['letters'] as List).map((item) => item['letter']),
        ['أَ', 'بَ', 'تَ', 'ثَ', 'جَ', 'حَ', 'خَ']);
    expect(
        scene.data['successAudio'], 'assets/audio/taa/assessment_success.mp3');
    expect(scene.data['wrongAudio'],
        'assets/audio/checkpoint_1/retry_only_v51.mp3');
  });

  test('only necessary v48 recordings were generated and are nonempty', () {
    final manifest = json('AUDIO_V48_MANIFEST.json');
    expect(manifest.length, 18);
    for (final path in manifest.keys) {
      expect(File(path).lengthSync(), greaterThan(1000), reason: path);
    }
    expect(manifest.keys.where((path) => path.contains('success')), isEmpty);
  });

  test('checkpoint unlocks after Khaa and gates the following group', () {
    const lessons = [
      LessonRef(lessonId: 'khaa', title: 'الخاء'),
      LessonRef(lessonId: 'checkpoint_group_1', title: 'الاختبار'),
      LessonRef(lessonId: 'dal', title: 'الدال'),
    ];
    expect(lessonIsUnlocked(lessons, 1, const {}), isFalse);
    expect(
        lessonIsUnlocked(lessons, 1, const {
          'khaa': LessonProgress(lessonId: 'khaa', completed: true),
        }),
        isTrue);
    expect(
        lessonIsUnlocked(lessons, 2, const {
          'khaa': LessonProgress(lessonId: 'khaa', completed: true),
          'checkpoint_group_1': LessonProgress(
              lessonId: 'checkpoint_group_1', completed: true, mastered: false),
        }),
        isFalse);
    expect(
        lessonIsUnlocked(lessons, 2, const {
          'checkpoint_group_1': LessonProgress(
              lessonId: 'checkpoint_group_1', completed: true, mastered: true),
        }),
        isTrue);
  });

  testWidgets('Khaa and checkpoint boards fit supported landscape sizes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      for (final target in const [
        ('khaa', 3),
        ('khaa', 5),
        ('checkpoint_group_1', 0),
      ]) {
        await tester.pumpWidget(support
            .app(LessonScreen(lessonId: target.$1, initialScene: target.$2)));
        await support.frames(tester, 12);
        expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: '${target.$1}/${target.$2}/$size');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    }
  });
}
