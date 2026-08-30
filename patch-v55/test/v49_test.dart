import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/review_order.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';

import 'v38_test.dart' as support;

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(support.seed);

  test('Khaa cumulative review covers six letters once as 3 glyph + 3 words',
      () {
    final lesson = json('assets/content/lesson_khaa.json');
    final review = (lesson['scenes'] as List)
        .firstWhere((scene) => scene['type'] == 'review')['data'] as Map;
    final source = (review['questions'] as List).cast<Map<String, dynamic>>();
    for (var seed = 0; seed < 20; seed++) {
      final selected = reviewQuestionOrder(source, Random(seed));
      expect(selected, hasLength(6));
      expect(selected.where((question) => question['kind'] == 'letter'),
          hasLength(3));
      expect(selected.where((question) => question['kind'] == 'word'),
          hasLength(3));
      expect(selected.map((question) => question['reviewLessonId']).toSet(),
          {'alif', 'baa', 'taa', 'thaa', 'jeem', 'haa'});
    }
  });

  test(
      'checkpoint has seven recognition, one drag board, seven speech and free-writing tasks',
      () {
    final checkpoint = json('assets/content/lesson_checkpoint_group_1.json');
    final data = ((checkpoint['scenes'] as List).first
        as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final tasks = checkpointTaskFlow(data, random: Random(49));
    expect(tasks, hasLength(22));

    final recognition =
        tasks.where((task) => task['phase'] == 'letters').toList();
    expect(recognition, hasLength(7));
    expect(recognition.map((task) => task['letter']).toSet(),
        {'أَ', 'بَ', 'تَ', 'ثَ', 'جَ', 'حَ', 'خَ'});
    for (final task in recognition) {
      expect(task['showPrompt'], false);
      expect((task['options'] as List), hasLength(7));
    }

    final matching = tasks.singleWhere((task) => task['type'] == 'dragMatch');
    expect((matching['pairs'] as List), hasLength(7));
    expect((matching['pairs'] as List).map((pair) => pair['image']).toSet(),
        hasLength(7));

    final pronunciation =
        tasks.where((task) => task['phase'] == 'pronunciation').toList();
    expect(pronunciation, hasLength(7));
    expect(pronunciation.map((task) => task['prompt']).toSet(),
        {'هيا يا أبطال، انطقوا هذا الحرف'});

    final writing = tasks.where((task) => task['phase'] == 'writing').toList();
    expect(writing, hasLength(7));
    expect(writing.where((task) => task['type'] == 'guided'), isEmpty);
    expect(writing.where((task) => task['type'] == 'free'), hasLength(7));
    expect(writing.every((task) => task['traceTemplateId'] != null), true);
    expect(File(data['pronunciationPromptAudio'] as String).lengthSync(),
        greaterThan(1000));
  });

  testWidgets(
      'checkpoint uses its own wide board without lesson milestone rail',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      await tester.pumpWidget(support.app(
          const LessonScreen(lessonId: 'checkpoint_group_1', initialScene: 0)));
      await support.frames(tester, 14);
      expect(find.byKey(const ValueKey('checkpoint-layout')), findsOneWidget);
      expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget);
      expect(find.byKey(const ValueKey('lesson-steps-right')), findsNothing);
      expect(find.text('استمع جيدًا واختر الحرف الصحيح'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
