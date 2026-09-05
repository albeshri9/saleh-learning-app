import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';
import 'package:saleh_app/features/lesson/scenes/pronunciation_scene.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/audio/fatha_reading_demonstration.dart';
import 'package:saleh_app/services/speech/speech_service.dart';

class _Audio implements AudioService {
  final played = <String>[];
  final events = <String>[];
  Completer<void>? _pending;
  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);

  @override
  Future<void> play(String assetPath) {
    _finish();
    played.add(assetPath);
    events.add('play:$assetPath');
    playing.value = true;
    _pending = Completer<void>();
    return _pending!.future;
  }

  void _finish() {
    playing.value = false;
    _pending?.complete();
    _pending = null;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    _finish();
  }

  @override
  Future<void> dispose() async {
    _finish();
    playing.dispose();
  }
}

class _Speech implements SpeechService {
  _Speech(this.events);
  final List<String> events;
  int attempts = 0;

  @override
  Future<SpeechResult> listenFor(String expected) async {
    attempts++;
    events.add('listen');
    return const SpeechResult(correct: false, recognizedWords: 'سا');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
      'single-letter examples use each current lesson tap recording, never an excerpt source',
      () {
    final glyphs = <String>{};
    final manifest =
        jsonDecode(File('assets/content/lesson_packs.json').readAsStringSync())
            as Map;
    for (final pack in (manifest['packs'] as List)) {
      if (pack['status'] != 'available') continue;
      final data =
          jsonDecode(File(pack['lessonAsset'] as String).readAsStringSync())
              as Map<String, dynamic>;
      for (final scene in ((data['scenes'] as List?) ?? [])) {
        if (scene['type'] != 'pronunciation') continue;
        final letter = scene['data']['letter'] as String;
        glyphs.add(letter);
        expect(fathaTapRepeatAssetFor(letter), scene['data']['letterTapAudio'],
            reason: letter);
        expect(fathaTapRepeatAssetFor(letter), contains('tap_repeat_3_'));
      }
    }
    expect(glyphs, hasLength(28));
    expect(fathaTapRepeatAssets, hasLength(28));
  });

  for (final checkpoint in [false, true]) {
    testWidgets(
        '${checkpoint ? 'checkpoint' : 'lesson'} offers a phoneme example after two failures',
        (tester) async {
      final audio = _Audio();
      final speech = _Speech(audio.events);
      final channel = SceneChannel()..markFinished();
      final answers = <bool>[];
      final api = SceneApi(
        profile: const ChildProfile(name: 'صالح', gender: ChildGender.male),
        channel: channel,
        completeScene: () {},
        recordAttempt: () {},
        recordAnswer: ({required bool correct}) => answers.add(correct),
        triggerSaleh: (_) {},
        replayScene: () {},
        replayGeneration: 0,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
        channel.dispose();
        await audio.dispose();
      });
      final widget = checkpoint
          ? CheckpointScene(
              scene: const Scene(
                  id: 'checkpoint',
                  type: SceneType.checkpoint,
                  data: {
                    'tasks': [
                      {'type': 'pronounce', 'letter': 'قَ', 'expected': 'قا'},
                    ],
                    'letters': [
                      {'letter': 'قَ', 'pronunciationRetryAudio': 'retry.mp3'},
                    ],
                    'wrongAudio': 'retry.mp3',
                  }),
              api: api,
            )
          : PronunciationScene(
              scene: const Scene(
                  id: 'pronounce',
                  type: SceneType.pronunciation,
                  data: {
                    'letter': 'قَ',
                    'expected': 'قا',
                    'letterTapAudio': 'assets/audio/qaaf/tap_repeat_3_v60.mp3',
                    'retryAudio': 'retry.mp3',
                  }),
              api: api,
            );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          audioServiceProvider.overrideWithValue(audio),
          speechServiceProvider.overrideWithValue(speech),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: Center(
                    child: SizedBox(
          width: 420,
          height: 280,
          child:
              Directionality(textDirection: TextDirection.rtl, child: widget),
        )))),
      ));
      await tester.pump();
      final model = find.byKey(ValueKey(checkpoint
          ? 'checkpoint-hear-example'
          : 'pronunciation-hear-example'));
      expect(model, findsNothing);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.mic_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(model, i == 0 ? findsNothing : findsOneWidget);
      }
      final scoreCount = answers.length;
      await tester.tap(model);
      await tester.pump();
      await tester.pump();
      expect(audio.played.last, 'assets/audio/qaaf/tap_repeat_3_v60.mp3');
      expect(speech.attempts, 2);
      expect(answers.length, scoreCount);
      final before = audio.events.length;
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();
      final events = audio.events.skip(before).toList();
      expect(events.indexOf('stop'), lessThan(events.indexOf('listen')));
      expect(tester.takeException(), isNull);
      // The third retry has a short delayed visual reset. Dispose and drain it
      // before Flutter checks pending timers at the end of the test body.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
