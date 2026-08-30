import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/foundation_track.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

WritingSample sample(LetterTraceTemplate template) {
  const size = Size(520, 280);
  return WritingSample(
    strokes: [
      for (var i = 0; i < template.guideParts.length; i++)
        template.samples(size, i, count: 140),
    ],
    canvasSize: size,
  );
}

void main() {
  test('writing track keeps the checkpoint scene instead of jumping to success',
      () {
    expect(FoundationTrack.writing.allowsLessonScene(SceneType.checkpoint),
        isTrue);
    expect(FoundationTrack.writing.allowsLessonScene(SceneType.explanation),
        isFalse);
    expect(FoundationTrack.reading.allowsLessonScene(SceneType.guidedWriting),
        isFalse);
    expect(FoundationTrack.reading.allowsLessonScene(SceneType.freeWriting),
        isFalse);
  });

  test('checkpoint two is non-empty and strictly follows every selected track',
      () {
    final package = json('assets/content/lesson_checkpoint_group_2.json');
    final scene = (package['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['type'] == 'checkpoint');
    final data = scene['data'] as Map<String, dynamic>;
    final writing = checkpointTaskFlow(data,
        random: math.Random(1), foundationTrack: FoundationTrack.writing);
    final reading = checkpointTaskFlow(data,
        random: math.Random(1), foundationTrack: FoundationTrack.reading);
    final combined = checkpointTaskFlow(data,
        random: math.Random(1), foundationTrack: FoundationTrack.readWrite);
    expect(writing, isNotEmpty);
    expect(writing.map((task) => task['type']).toSet(), {'guided', 'free'});
    expect(reading.any((task) => task['type'] == 'guided'), isFalse);
    expect(reading.any((task) => task['type'] == 'free'), isFalse);
    expect(combined.length, greaterThan(reading.length));
    expect(combined.length, greaterThan(writing.length));
  });

  test('five new lessons, images, audio, and the second checkpoint are bundled',
      () {
    const ids = ['dal', 'dhal', 'raa', 'zay', 'seen'];
    const letters = ['دَ', 'ذَ', 'رَ', 'زَ', 'سَ'];
    final programs = jsonDecode(File('assets/content/programs.json')
        .readAsStringSync()) as List<dynamic>;
    final levels = ((programs.first as Map)['stages'] as List).first['levels']
        as List<dynamic>;
    final group = levels.cast<Map>().firstWhere((item) => item['id'] == 'group_2');
    expect((group['lessons'] as List).map((item) => item['lessonId']),
        [...ids, 'checkpoint_group_2']);

    for (var i = 0; i < ids.length; i++) {
      final lesson = json('assets/content/lesson_${ids[i]}.json');
      expect(lesson['title'], contains(letters[i]));
      expect(jsonEncode(lesson), isNot(contains('الفتحة')));
      expect(jsonEncode(lesson), isNot(contains('فتحة')));
      expect(LetterGlyph.templateFor(letters[i]), isNotNull);
      final template = LetterGlyph.templateFor(letters[i])!;
      expect(validateDottedLetterWriting(sample(template), template).isValid,
          isTrue,
          reason: ids[i]);
      for (final file in Directory('assets/audio/${ids[i]}')
          .listSync()
          .whereType<File>()) {
        expect(file.lengthSync(), greaterThan(1000), reason: file.path);
      }
    }
    expect(File('assets/audio/ui_tap_gentle_v54.mp3').lengthSync(),
        greaterThan(1000));
  });

  test('each new cumulative review has three letters and three unique words',
      () {
    for (final id in ['dal', 'dhal', 'raa', 'zay', 'seen']) {
      final lesson = json('assets/content/lesson_$id.json');
      final review = (lesson['scenes'] as List)
          .cast<Map>()
          .firstWhere((scene) => scene['type'] == 'review')['data'] as Map;
      final questions = (review['questions'] as List).cast<Map>();
      expect(questions, hasLength(6));
      expect(questions.where((question) => question['kind'] == 'letter'),
          hasLength(3));
      expect(questions.where((question) => question['kind'] == 'word'),
          hasLength(3));
      expect(questions.map((q) => q['reviewLessonId']).toSet(), hasLength(6));
    }
  });
}
