import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/foundation_track.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';
import 'package:saleh_app/features/lesson/scenes/pronunciation_scene.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/speech/speech_service.dart';

import 'v38_test.dart' as support;

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

class _RecordingAudio implements AudioService {
  final played = <String>[];

  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);

  @override
  Future<void> play(String assetPath) async => played.add(assetPath);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async => playing.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checkpoint two samples the cumulative pool with approved counts', () {
    final package = json('assets/content/lesson_checkpoint_group_2.json');
    final scene = (package['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['type'] == 'checkpoint');
    final data = scene['data'] as Map<String, dynamic>;
    const allIds = {
      'alif',
      'baa',
      'taa',
      'thaa',
      'jeem',
      'haa',
      'khaa',
      'dal',
      'dhal',
      'raa',
      'zay',
      'seen',
    };
    const secondGroup = {'dal', 'dhal', 'raa', 'zay', 'seen'};
    expect((data['letters'] as List).map((item) => item['id']).toSet(), allIds);

    final seenRecognition = <String>{};
    for (var seed = 0; seed < 24; seed++) {
      final tasks = checkpointTaskFlow(data, random: math.Random(seed));
      expect(tasks, hasLength(16));

      final recognition =
          tasks.where((task) => task['phase'] == 'letters').toList();
      expect(recognition, hasLength(6));
      expect(recognition.map((task) => task['id']).toSet(), hasLength(6));
      expect(
          recognition.every((task) => (task['options'] as List).length == 12),
          true);
      seenRecognition.addAll(recognition.map(
          (task) => (task['id'] as String).replaceFirst('recognize_', '')));

      final drag = tasks.singleWhere((task) => task['type'] == 'dragMatch');
      final pairs = (drag['pairs'] as List).cast<Map<String, dynamic>>();
      expect(pairs, hasLength(8));
      expect(pairs.map((pair) => pair['letter']).toSet(), hasLength(8));

      final pronunciation =
          tasks.where((task) => task['phase'] == 'pronunciation').toList();
      expect(pronunciation, hasLength(4));
      expect(pronunciation.map((task) => task['id']).toSet(), hasLength(4));

      final writing =
          tasks.where((task) => task['phase'] == 'writing').toList();
      expect(writing, hasLength(5));
      expect(
          writing
              .map((task) => (task['id'] as String).replaceFirst('free_', ''))
              .toSet(),
          secondGroup);
    }
    expect(seenRecognition, allIds);

    final reading = checkpointTaskFlow(
      data,
      random: math.Random(59),
      foundationTrack: FoundationTrack.reading,
    );
    expect(reading, hasLength(11));
    expect(reading.any((task) => task['phase'] == 'writing'), false);

    final writing = checkpointTaskFlow(
      data,
      random: math.Random(59),
      foundationTrack: FoundationTrack.writing,
    );
    expect(writing, hasLength(5));
    expect(writing.every((task) => task['phase'] == 'writing'), true);
  });

  test('every pronunciation letter tap uses a verified three-repeat clip', () {
    for (final id in [
      'alif',
      'baa',
      'taa',
      'thaa',
      'jeem',
      'haa',
      'khaa',
      'dal',
      'dhal',
      'raa',
      'zay',
      'seen',
    ]) {
      final lesson = json('assets/content/lesson_$id.json');
      final scene = (lesson['scenes'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((item) => item['type'] == 'pronunciation');
      final path =
          (scene['data'] as Map<String, dynamic>)['letterTapAudio'] as String;
      expect(path, contains('tap_repeat_3_v59.mp3'), reason: id);
      expect(File(path).lengthSync(), greaterThan(1000), reason: id);
    }
  });

  test('rejected raa 11 and seen 12 recordings are no longer referenced', () {
    final raa = json('assets/content/lesson_raa.json');
    final raaGuided = (raa['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['type'] == 'guidedWriting');
    final raaLines = (raaGuided['lines'] as List).cast<Map<String, dynamic>>();
    expect(raaLines.last['audio'], 'assets/audio/raa/writing_try_v59.mp3');
    expect((raaGuided['data'] as Map)['againAudio'],
        'assets/audio/raa/writing_try_v59.mp3');

    final seen = json('assets/content/lesson_seen.json');
    final seenFree = (seen['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['type'] == 'freeWriting');
    expect(((seenFree['lines'] as List).single as Map)['audio'],
        'assets/audio/seen/free_intro_v59.mp3');

    final checkpoint = json('assets/content/lesson_checkpoint_group_2.json');
    final data = (((checkpoint['scenes'] as List).first as Map)['data'] as Map);
    final seenEntry = (data['letters'] as List)
        .cast<Map>()
        .singleWhere((item) => item['id'] == 'seen');
    expect(seenEntry['freeAudio'], 'assets/audio/seen/free_intro_v59.mp3');
  });

  testWidgets('pronunciation feedback stays in its reserved frame',
      (tester) async {
    final audio = _RecordingAudio();
    final channel = SceneChannel();
    addTearDown(channel.dispose);
    channel.markFinished();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(audio),
        speechServiceProvider.overrideWithValue(const MockSpeechService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 340,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: PronunciationScene(
                  scene: const Scene(
                    id: 'pronunciation',
                    type: SceneType.pronunciation,
                    data: {
                      'letter': 'رَ',
                      'expected': 'رَا',
                      'letterTapAudio': 'tap-three-only.mp3',
                      'successAudio': 'success.mp3',
                    },
                  ),
                  api: SceneApi(
                    profile: const ChildProfile(
                      name: 'صالح',
                      gender: ChildGender.male,
                    ),
                    channel: channel,
                    completeScene: () {},
                    recordAttempt: () {},
                    recordAnswer: ({required bool correct}) {},
                    triggerSaleh: (_) {},
                    replayScene: () {},
                    replayGeneration: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('pronunciation-letter')));
    await tester.pump();
    expect(audio.played, ['tap-three-only.mp3']);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    expect(find.text('أحسنت، نطقك رائع!'), findsOneWidget);
    final footer =
        tester.getRect(find.byKey(const ValueKey('pronunciation-footer')));
    final feedback =
        tester.getRect(find.byKey(const ValueKey('pronunciation-feedback')));
    expect(feedback.top, greaterThanOrEqualTo(footer.top));
    expect(feedback.bottom, lessThanOrEqualTo(footer.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkpoint two fits all twelve recognition choices',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    support.seed();
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      await tester.pumpWidget(support.app(
        const LessonScreen(lessonId: 'checkpoint_group_2', initialScene: 0),
      ));
      await support.frames(tester, 14);
      expect(
          find.byKey(const ValueKey('checkpoint-choice-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
