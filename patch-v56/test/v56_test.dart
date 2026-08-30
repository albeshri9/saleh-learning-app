import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/config/experimental_release.dart';
import 'package:saleh_app/domain/models/curriculum.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/home/lessons_catalog.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('experimental review release opens every letter and checkpoint', () {
    expect(ExperimentalRelease.openEveryLessonAndCheckpoint, true);
    final lessons = [
      const LessonRef(lessonId: 'alif', title: 'أ'),
      const LessonRef(lessonId: 'checkpoint_group_1', title: 'اختبار'),
      const LessonRef(lessonId: 'dal', title: 'د'),
      const LessonRef(lessonId: 'checkpoint_group_2', title: 'اختبار'),
    ];
    for (var index = 0; index < lessons.length; index++) {
      expect(
        lessonIsUnlocked(lessons, index, const {},
            experimentalOverride:
                ExperimentalRelease.openEveryLessonAndCheckpoint),
        true,
        reason: lessons[index].lessonId,
      );
    }
  });

  test('experimental review release permits skipping every lesson scene', () {
    expect(ExperimentalRelease.skipEveryLessonSection, true);
    for (final path in [
      'assets/content/lesson_alif.json',
      'assets/content/lesson_dal.json',
      'assets/content/lesson_checkpoint_group_1.json',
      'assets/content/lesson_checkpoint_group_2.json',
    ]) {
      final lesson = Lesson.fromJson(json(path));
      for (final scene in lesson.scenes) {
        expect(lessonSceneCanSkip(scene), true,
            reason: '${lesson.id}/${scene.id}');
      }
    }
  });
}
