import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/foundation_track.dart';
import 'package:saleh_app/features/lesson/review_order.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';

dynamic readJson(String path) => jsonDecode(File(path).readAsStringSync());

void main() {
  final packs = (readJson('assets/content/lesson_packs.json')['packs'] as List)
      .cast<Map<String, dynamic>>();
  final additions =
      (readJson('pending_content/v60/LESSON_PACKS_ADDITIONS.json')['packs']
              as List)
          .cast<Map<String, dynamic>>();

  test('28 letters, 5 checkpoints and 4 readings are available in trial', () {
    expect(packs.length, 37);
    expect(packs.where((p) => p['kind'] == 'checkpoint').length, 5);
    expect(packs.where((p) => p['kind'] == 'reading').length, 4);
    expect(packs.where((p) => p['letter'] != null).length, 28);
    expect(packs.every((p) => p['status'] == 'available'), isTrue);
    final levels = readJson('assets/content/programs.json')[0]['stages'][0]
        ['levels'] as List;
    expect(levels.length, 5);
    for (var group = 2; group <= 5; group++) {
      final lessons = levels[group - 1]['lessons'] as List;
      expect(
          lessons[lessons.length - 2]['lessonId'], 'checkpoint_group_$group');
      expect(lessons.last['lessonId'], 'reading_group_$group');
    }
  });

  test('active new lessons retain track policies and disjoint review', () {
    for (final pack in additions.where((p) => p['letter'] != null)) {
      final raw =
          readJson(pack['lessonAsset'] as String) as Map<String, dynamic>;
      final lesson = Lesson.fromJson(raw);
      final reading =
          lessonSceneIndicesForTrack(lesson, FoundationTrack.reading)
              .map((i) => lesson.scenes[i].type);
      expect(reading, isNot(contains(SceneType.freeWriting)));
      expect(reading, isNot(contains(SceneType.guidedWriting)));
      final writing =
          lessonSceneIndicesForTrack(lesson, FoundationTrack.writing)
              .map((i) => lesson.scenes[i].type);
      expect(writing,
          containsAll([SceneType.guidedWriting, SceneType.freeWriting]));
      expect(
          writing.every((t) =>
              t == SceneType.guidedWriting ||
              t == SceneType.freeWriting ||
              t == SceneType.success),
          isTrue);
      for (final scene
          in lesson.scenes.where((s) => s.type == SceneType.review)) {
        final questions =
            (scene.data['questions'] as List).cast<Map<String, dynamic>>();
        for (var seed = 0; seed < 20; seed++) {
          final selected = reviewQuestionOrder(questions, Random(seed));
          expect(selected.length, (pack['priorLessonIds'] as List).length);
          expect(selected.map((q) => q['reviewLessonId']).toSet().length,
              selected.length);
          expect(
              (selected.where((q) => q['kind'] == 'letter').length -
                      selected.where((q) => q['kind'] == 'word').length)
                  .abs(),
              lessThanOrEqualTo(1));
        }
      }
    }
  });

  test('active cumulative tests have writing only in writing track', () {
    for (var group = 3; group <= 5; group++) {
      final lesson = Lesson.fromJson(
          readJson('assets/content/lesson_checkpoint_group_$group.json')
              as Map<String, dynamic>);
      final data =
          lesson.scenes.singleWhere((s) => s.type == SceneType.checkpoint).data;
      final writing =
          checkpointTaskFlow(data, foundationTrack: FoundationTrack.writing);
      expect(writing.length, group == 5 ? 4 : 6);
      expect(writing.every((t) => t['type'] == 'free'), isTrue);
      expect(
          checkpointTaskFlow(data, foundationTrack: FoundationTrack.reading)
              .any((t) => t['type'] == 'free' || t['type'] == 'guided'),
          isFalse);
    }
  });

  test('experimental permission cannot be mistaken for auditory approval', () {
    final consent = readJson('EXPERIMENTAL_V60_AUTHORIZATION.json');
    expect(consent['allowUnreviewedAudioInExperimentalIpa'], isTrue);
    expect(consent['auditoryApprovalGranted'], isFalse);
    final clips =
        readJson('pending_content/v60/NARRATION_V60_PENDING.json')['clips']
            as List;
    expect(clips.length, 256);
    expect(clips.every((c) => c['listenedEntirely'] == false), isTrue);
    for (final pack in additions) {
      final lesson = readJson(pack['lessonAsset'] as String);
      expect(lesson['publication']['status'], 'experimental');
      expect(lesson['publication']['mediaQaPassed'], isFalse);
    }
  });
}
