import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/core/design/widgets/app_button.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/curriculum.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/domain/repositories/content_repository.dart';
import 'package:saleh_app/domain/repositories/progress_repository.dart';
import 'package:saleh_app/features/home/learning_journal.dart';
import 'package:saleh_app/features/lesson/foundation_track.dart';
import 'package:saleh_app/features/lesson/lesson_controller.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/reading_assessment_scene.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/speech/speech_service.dart';

class _Audio implements AudioService {
  _Audio(this.events);
  final List<String> events;
  final List<String> played = [];
  Completer<void>? _active;

  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);

  @override
  Future<void> play(String assetPath) {
    events.add('play:$assetPath');
    played.add(assetPath);
    _active?.complete();
    _active = Completer<void>();
    playing.value = true;
    return _active!.future;
  }

  @override
  Future<void> stop() async {
    events.add('stop-audio');
    playing.value = false;
    _active?.complete();
    _active = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    playing.dispose();
  }
}

class _Speech implements SpeechService {
  _Speech(this.events);
  final List<String> events;
  final List<String> requested = [];
  final Queue<Future<SpeechResult> Function(String)> responses = Queue();

  @override
  Future<SpeechResult> listenFor(String expected) async {
    events.add('listen:$expected');
    requested.add(expected);
    if (responses.isNotEmpty) return responses.removeFirst()(expected);
    // The existing single-letter service may reject a multi-letter transcript.
    // The reading scene must assess the transcript, not trust this old boolean.
    return SpeechResult(correct: false, recognizedWords: expected);
  }

  @override
  Future<void> dispose() async => events.add('stop-speech');
}

class _Harness {
  _Harness() {
    audio = _Audio(events);
    speech = _Speech(events);
  }

  final List<String> events = [];
  final List<bool> answers = [];
  final List<String> reactions = [];
  final SceneChannel channel = SceneChannel();
  late final _Audio audio;
  late final _Speech speech;
  int attempts = 0;
  int completed = 0;
  int skipped = 0;

  Future<void> mount(WidgetTester tester,
      {required List<List<String>> items,
      Size size = const Size(600, 340)}) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
      channel.dispose();
      await audio.dispose();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(audio),
        speechServiceProvider.overrideWithValue(speech),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const ValueKey('test-reading-board'),
              width: size.width,
              height: size.height,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ReadingAssessmentScene(
                  scene: Scene(id: 'reading', type: SceneType.reading, data: {
                    'items': items,
                    'pairPromptAudio': 'pairs.mp3',
                    'triplePromptAudio': 'triples.mp3',
                    'successAudio': 'success.mp3',
                    'retryAudio': 'retry.mp3',
                  }),
                  api: SceneApi(
                    profile: const ChildProfile(
                        name: 'صالح', gender: ChildGender.male),
                    channel: channel,
                    completeScene: () => completed++,
                    skipScene: () => skipped++,
                    recordAttempt: () => attempts++,
                    recordAnswer: ({required bool correct}) =>
                        answers.add(correct),
                    triggerSaleh: reactions.add,
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
    await tester.pump();
  }
}

const _integrationLesson = Lesson(
  id: 'reading_test',
  title: 'اقرأ الحرفين معًا',
  mastery: MasteryRules(minScore: .8, requiredSceneIds: ['read']),
  scenes: [
    Scene(id: 'read', type: SceneType.reading, data: {
      'items': [
        ['سَ', 'ذَ']
      ],
    }),
  ],
);

class _ReadingContent implements ContentRepository {
  @override
  Future<Lesson> loadLesson(String lessonId) async => _integrationLesson;

  @override
  Future<List<Program>> loadPrograms() async => [];
}

class _ReadingProgress implements ProgressRepository {
  _ReadingProgress([this.saved]);
  LessonProgress? saved;

  @override
  Future<ChildProfile?> loadProfile() async =>
      const ChildProfile(name: 'صالح', gender: ChildGender.male);

  @override
  Future<LessonProgress?> loadLessonProgress(String lessonId) async => saved;

  @override
  Future<void> saveLessonProgress(LessonProgress progress) async =>
      saved = progress;

  @override
  Future<void> saveProfile(ChildProfile profile) async {}
}

class _ReadingJournal extends LearningJournal {
  _ReadingJournal() : super('reading-test');

  @override
  Future<void> award(String id, int points) async {}
}

Future<void> _integrationFrames(WidgetTester tester) async {
  // Saleh uses an animated image; settling all animation is intentionally not
  // possible, so advance a finite number of frames and allow asset IO to run.
  for (var frame = 0; frame < 12; frame++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapIntegratedAction(WidgetTester tester, String label) async {
  final action = find.ancestor(
      of: find.text(label), matching: find.byType(LessonActionButton));
  await tester.tap(action);
  await _integrationFrames(tester);
}

Future<void> _tapMic(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('reading-mic')));
  await tester.pump();
  await tester.pump();
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  // The shared lesson button intentionally wraps its painted label in an
  // IgnorePointer; tap its real outer pointer target, not the decorative text.
  final action =
      find.ancestor(of: finder, matching: find.byType(LessonActionButton));
  await tester.tap(action.evaluate().isEmpty ? finder : action);
  await tester.pumpAndSettle();
}

void _inside(Rect child, Rect parent, String description) {
  expect(child.left, greaterThanOrEqualTo(parent.left - .01),
      reason: '$description left');
  expect(child.top, greaterThanOrEqualTo(parent.top - .01),
      reason: '$description top');
  expect(child.right, lessThanOrEqualTo(parent.right + .01),
      reason: '$description right');
  expect(child.bottom, lessThanOrEqualTo(parent.bottom + .01),
      reason: '$description bottom');
}

void _feedbackInsideBoard(WidgetTester tester, String message) {
  final board =
      tester.getRect(find.byKey(const ValueKey('test-reading-board')));
  final feedback =
      tester.getRect(find.byKey(const ValueKey('reading-feedback')));
  _inside(feedback, board, 'feedback frame');
  _inside(tester.getRect(find.text(message)), feedback, 'feedback text');
}

void main() {
  test('reading is interactive and absent from the writing-only track', () {
    expect(lessonSceneAllowsGlobalNext(SceneType.reading), isFalse);
    expect(
        lessonSceneIndicesForTrack(_integrationLesson, FoundationTrack.reading),
        [0]);
    expect(
        lessonSceneIndicesForTrack(
            _integrationLesson, FoundationTrack.readWrite),
        [0]);
    expect(
        lessonSceneIndicesForTrack(_integrationLesson, FoundationTrack.writing),
        isEmpty);
  });

  for (final skipped in [false, true]) {
    test(
        'reading controller persists ${skipped ? 'skip without mastery' : 'real success'}',
        () async {
      final progress = _ReadingProgress();
      final container = ProviderContainer(overrides: [
        contentRepositoryProvider.overrideWithValue(_ReadingContent()),
        progressRepositoryProvider.overrideWithValue(progress),
        journalProvider.overrideWithValue(_ReadingJournal()),
      ]);
      final subscription = container.listen(
          lessonControllerProvider('reading_test'), (_, __) {});
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      await container.read(lessonControllerProvider('reading_test').future);
      final controller =
          container.read(lessonControllerProvider('reading_test').notifier);
      if (!skipped) controller.recordAnswer(correct: true);
      await controller.completeScene(skipped: skipped);
      expect(
          container
              .read(lessonControllerProvider('reading_test'))
              .value!
              .finished,
          isTrue);
      expect(progress.saved?.mastered, !skipped);
      expect(progress.saved?.completedScenes, skipped ? isEmpty : ['read']);
    });
  }

  test('an earlier completion must not make a skipped replay newly mastered',
      () async {
    final progress = _ReadingProgress(const LessonProgress(
        lessonId: 'reading_test',
        completed: true,
        mastered: false,
        score: .5,
        completedScenes: ['read']));
    final container = ProviderContainer(overrides: [
      contentRepositoryProvider.overrideWithValue(_ReadingContent()),
      progressRepositoryProvider.overrideWithValue(progress),
      journalProvider.overrideWithValue(_ReadingJournal()),
    ]);
    final subscription =
        container.listen(lessonControllerProvider('reading_test'), (_, __) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    await container.read(lessonControllerProvider('reading_test').future);
    final controller =
        container.read(lessonControllerProvider('reading_test').notifier);
    // One card passed this run, but the user skipped the rest of the assessment.
    controller.recordAnswer(correct: true);
    await controller.completeScene(skipped: true);
    expect(progress.saved?.mastered, isFalse);
  });

  for (final skipped in [false, true]) {
    testWidgets(
        'single reading scene exits after ${skipped ? 'skip' : 'completion'}',
        (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final progress = _ReadingProgress();
      final audio = SilentAudioService();
      final router = GoRouter(initialLocation: '/reading', routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('after-reading'))),
        GoRoute(
            path: '/reading',
            builder: (_, __) => const LessonScreen(lessonId: 'reading_test')),
      ]);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 600));
        router.dispose();
        await audio.dispose();
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_ReadingContent()),
          progressRepositoryProvider.overrideWithValue(progress),
          journalProvider.overrideWithValue(_ReadingJournal()),
          audioServiceProvider.overrideWithValue(audio),
          speechServiceProvider.overrideWithValue(_Speech([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await _integrationFrames(tester);
      expect(find.byKey(const ValueKey('reading-mic')), findsOneWidget);
      // A reading test has a full board, not the four lesson-step tabs.
      expect(find.text('أسمع'), findsNothing);
      expect(find.text('أكتب'), findsNothing);
      if (skipped) {
        await tester.tap(find.byKey(const ValueKey('reading-skip-item')));
        await _integrationFrames(tester);
      } else {
        await _tapMic(tester);
        await _integrationFrames(tester);
        await _tapIntegratedAction(tester, 'متابعة');
      }
      await _tapIntegratedAction(tester, 'تم');
      expect(find.text('after-reading'), findsOneWidget);
      expect(find.byType(LessonScreen), findsNothing);
      expect(progress.saved?.mastered, !skipped);
      expect(tester.takeException(), isNull);
    });
  }

  test('shuffles complete cards without changing glyph order; pairs first', () {
    final original = <List<String>>[
      ['أَ', 'كَ', 'لَ'],
      ['بَ', 'حَ'],
      ['دَ', 'خَ'],
      ['فَ', 'تَ', 'حَ'],
      ['زَ', 'سَ'],
      ['تَ', 'أَ'],
    ];
    final serialized = original.map((item) => item.join()).toList();
    final orders = <String>{};
    for (var seed = 0; seed < 16; seed++) {
      final result = readingAssessmentItems({'items': original},
          random: math.Random(seed));
      expect(result, hasLength(6));
      expect(result.take(4).every((item) => item.length == 2), isTrue);
      expect(result.skip(4).every((item) => item.length == 3), isTrue);
      expect(result.map((item) => item.join()).toSet(), serialized.toSet());
      expect(original.map((item) => item.join()).toList(), serialized,
          reason: 'Do not mutate source content');
      orders.add(result.map((item) => item.join()).join('|'));
    }
    expect(orders.length, greaterThan(1));
  });

  for (final size in [const Size(320, 220), const Size(600, 340)]) {
    for (final letters in [
      ['سَ', 'ذَ'],
      ['فَ', 'تَ', 'حَ'],
    ]) {
      testWidgets('fits ${letters.length} RTL glyphs and feedback at $size',
          (tester) async {
        final harness = _Harness();
        harness.speech.responses.add((_) async =>
            const SpeechResult(correct: true, recognizedWords: 'خطأ'));
        await harness.mount(tester, items: [letters], size: size);
        expect(tester.takeException(), isNull);
        final board =
            tester.getRect(find.byKey(const ValueKey('test-reading-board')));
        Rect? prior;
        for (var index = 0; index < letters.length; index++) {
          final card = find.byKey(ValueKey('reading-glyph-$index'));
          final glyph = tester.widget<LetterGlyph>(
              find.descendant(of: card, matching: find.byType(LetterGlyph)));
          expect(glyph.letter, letters[index]);
          final rect = tester.getRect(card);
          _inside(rect, board, 'glyph card $index');
          if (prior != null) {
            expect(rect.center.dx, lessThan(prior.center.dx),
                reason: 'The first spoken glyph must be the rightmost');
            expect(rect.width, closeTo(prior.width, .01));
            expect(rect.top, closeTo(prior.top, .01));
          }
          prior = rect;
        }

        await _tapMic(tester);
        _feedbackInsideBoard(tester, 'حاولوا مرة أخرى');
        final failureStyle = tester.widget<Text>(find.text('حاولوا مرة أخرى'));
        expect(failureStyle.style?.color, const Color(0xFFBB4559));
        await tester.pumpAndSettle();
        await _tapMic(tester);
        _feedbackInsideBoard(tester, 'أحسنتم يا أبطال.');
        final successStyle =
            tester.widget<Text>(find.text('أحسنتم يا أبطال.'));
        expect(successStyle.style?.color, const Color(0xFF388575));
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('أحسنتم يا أبطال.'), findsOneWidget,
            reason: 'Feedback must persist until the child continues');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('mic stops narrator before listening; scores transcript not bool',
      (tester) async {
    final harness = _Harness();
    harness.speech.responses.add((_) async =>
        const SpeechResult(correct: true, recognizedWords: 'ذا سا'));
    await harness.mount(tester, items: [
      ['سَ', 'ذَ']
    ]);
    expect(harness.audio.playing.value, isTrue);
    expect(harness.audio.played, ['pairs.mp3']);
    harness.channel.scriptInterrupted.value = false;
    await _tapMic(tester);
    expect(harness.channel.scriptInterrupted.value, isTrue);
    expect(harness.events.indexOf('stop-audio'),
        lessThan(harness.events.indexOf('listen:سَ ذَ')));
    expect(harness.answers, [false],
        reason: 'A wrong order cannot pass even if the old service said true');
    expect(harness.audio.played.last, 'retry.mp3');
    expect(harness.completed, 0);
    expect(find.text('متابعة'), findsNothing);

    await tester.pumpAndSettle();
    final eventCount = harness.events.length;
    await _tapMic(tester);
    expect(harness.events[eventCount], 'stop-audio');
    expect(harness.answers, [false, true],
        reason:
            'The exact transcript must pass even when old correct is false');
    expect(harness.attempts, 2);
    expect(harness.reactions, ['idle', 'happyOnce']);
    expect(harness.audio.played.last, 'success.mp3');
    expect(find.byKey(const ValueKey('reading-skip-item')), findsNothing);
    expect(find.text('متابعة'), findsOneWidget);

    await _tapAndSettle(tester, find.text('متابعة'));
    expect(find.textContaining('أكملتم قراءة 1 تدريبًا'), findsOneWidget);
    expect(harness.completed, 0);
    await _tapAndSettle(tester, find.text('تم'));
    expect(harness.completed, 1);
    expect(harness.skipped, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pairs precede triples in UI and use the respective prompt',
      (tester) async {
    final harness = _Harness();
    await harness.mount(tester, items: [
      ['فَ', 'تَ', 'حَ'],
      ['بَ', 'حَ'],
    ]);
    expect(find.textContaining('اقرأ الحرفين معًا'), findsOneWidget);
    expect(harness.audio.played.last, 'pairs.mp3');
    await _tapMic(tester);
    await _tapAndSettle(tester, find.text('متابعة'));
    expect(find.textContaining('اقرأ ثلاثة أحرف معًا'), findsOneWidget);
    expect(harness.audio.played.last, 'triples.mp3');
    await _tapMic(tester);
    await _tapAndSettle(tester, find.text('متابعة'));
    await _tapAndSettle(tester, find.text('تم'));
    expect(harness.answers, [true, true]);
    expect(harness.completed, 1);
    expect(harness.skipped, 0);
  });

  testWidgets('skipping final item is recorded as skip, never mastery',
      (tester) async {
    final harness = _Harness();
    await harness.mount(tester,
        items: [
          ['بَ', 'حَ'],
          ['فَ', 'تَ', 'حَ'],
        ],
        size: const Size(320, 220));
    await _tapMic(tester);
    await _tapAndSettle(tester, find.text('متابعة'));
    await _tapAndSettle(
        tester, find.byKey(const ValueKey('reading-skip-item')));
    expect(find.textContaining('قرأتم 1 من 2'), findsOneWidget);
    expect(find.text('تدريب ما تخطيته'), findsOneWidget);
    expect(harness.completed, 0);
    expect(harness.answers, [true]);
    await _tapAndSettle(tester, find.text('تم'));
    expect(harness.skipped, 1);
    expect(harness.completed, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skipped cards can be retried and genuinely completed',
      (tester) async {
    final harness = _Harness();
    await harness.mount(tester, items: [
      ['بَ', 'حَ']
    ]);
    await _tapAndSettle(
        tester, find.byKey(const ValueKey('reading-skip-item')));
    await _tapAndSettle(tester, find.text('تدريب ما تخطيته'));
    expect(find.textContaining('لنتدرب معًا'), findsOneWidget);
    await _tapMic(tester);
    await _tapAndSettle(tester, find.text('متابعة'));
    await _tapAndSettle(tester, find.text('تم'));
    expect(harness.answers, [true]);
    expect(harness.completed, 1);
    expect(harness.skipped, 0);
  });

  testWidgets('a late speech result cannot mark a skipped card successful',
      (tester) async {
    final harness = _Harness();
    final speechResult = Completer<SpeechResult>();
    harness.speech.responses.add((_) => speechResult.future);
    await harness.mount(tester, items: [
      ['بَ', 'حَ']
    ]);
    await _tapMic(tester);
    expect(find.text('أسمعكم الآن…'), findsOneWidget);
    await _tapAndSettle(
        tester, find.byKey(const ValueKey('reading-skip-item')));
    speechResult
        .complete(const SpeechResult(correct: true, recognizedWords: 'بَ حَ'));
    await tester.pumpAndSettle();
    expect(harness.answers, isEmpty);
    expect(harness.audio.played, ['pairs.mp3']);
    expect(find.textContaining('قرأتم 0 من 1'), findsOneWidget);
    await _tapAndSettle(tester, find.text('تم'));
    expect(harness.completed, 0);
    expect(harness.skipped, 1);
    expect(tester.takeException(), isNull);
  });
}
