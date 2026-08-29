import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/home/parent_dashboard.dart';
import 'package:saleh_app/features/lesson/review_order.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/pronunciation_scene.dart';
import 'package:saleh_app/features/lesson/scenes/writing_scene.dart';
import 'package:saleh_app/features/lesson/scenes/review_scene.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/speech/speech_service.dart';
import 'v38_test.dart' as support;
import 'v44_test.dart' as fixtures;

class PendingAudio extends SilentAudioService {
  final played = <String>[];
  final pending = <Completer<void>>[];
  int stops = 0;
  @override
  Future<void> play(String path) {
    played.add(path);
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    finish();
  }

  void finish() {
    for (final c in pending) {
      if (!c.isCompleted) c.complete();
    }
  }
}

class RepeatSpeech extends MockSpeechService {
  int calls = 0;
  @override
  Future<SpeechResult> listenFor(String expected) async {
    calls++;
    return const SpeechResult(correct: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(support.seed);
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test('review tests every prior letter once across glyph and word phases', () {
    final questions = [
      for (final kind in ['letter', 'word'])
        for (final id in ['alif', 'baa', 'taa'])
          {'kind': kind, 'reviewLessonId': id}
    ];
    final orders = <String>{};
    final kindsByLetter = {
      for (final id in ['alif', 'baa', 'taa']) id: <String>{},
    };
    for (var seed = 0; seed < 30; seed++) {
      final result = reviewQuestionOrder(questions, Random(seed));
      expect(result, hasLength(3));
      expect(result.map((q) => q['reviewLessonId']).toSet(),
          {'alif', 'baa', 'taa'});
      final kinds = result.map((q) => q['kind']).toList();
      final firstWord = kinds.indexOf('word');
      if (firstWord >= 0) {
        expect(kinds.skip(firstWord).every((kind) => kind == 'word'), true);
      }
      for (final question in result) {
        kindsByLetter[question['reviewLessonId']]!.add(question['kind']);
      }
      orders.add(result.toString());
    }
    expect(orders.length, greaterThan(2));
    for (final kinds in kindsByLetter.values) {
      expect(kinds, {'letter', 'word'});
    }
  });
  test('Ja ASR spelling variants and repetitions do not accept unrelated words',
      () {
    for (final text in ['جا', 'جاء', 'جَا', 'جاء، جاء', 'جيم', 'الجاء']) {
      expect(speechMatchesExpected(text, 'جَا'), true, reason: text);
    }
    for (final text in ['جمل', 'تاء', 'حاء', 'هذا جمل', 'جاء جمل', '']) {
      expect(speechMatchesExpected(text, 'جَا'), false, reason: text);
    }
  });
  testWidgets('mic interrupts feedback and never waits on playback spinner',
      (tester) async {
    final audio = PendingAudio();
    final speech = RepeatSpeech();
    final channel = SceneChannel();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          audioServiceProvider.overrideWithValue(audio),
          speechServiceProvider.overrideWithValue(speech)
        ],
        child: MaterialApp(
            home: Scaffold(
                body: PronunciationScene(
                    scene: const Scene(
                        id: 'mic',
                        type: SceneType.pronunciation,
                        data: {
                          'letter': 'جَ',
                          'expected': 'جا',
                          'retryAudio': 'retry.mp3'
                        }),
                    api: fixtures.api(channel))))));
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    expect(speech.calls, 1);
    expect(audio.played, ['retry.mp3']);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    expect(speech.calls, 2);
    expect(audio.stops, 2);
    expect(channel.scriptInterrupted.value, true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    audio.finish();
    channel.dispose();
  });
  testWidgets(
      'review starts question after introduction, has no skip, and disposal cancels pending example',
      (tester) async {
    final audio = PendingAudio();
    final channel = SceneChannel();
    var skipped = 0;
    final api = SceneApi(
        profile: support.child,
        channel: channel,
        completeScene: () {},
        skipScene: () => skipped++,
        recordAttempt: () {},
        recordAnswer: ({required bool correct}) {},
        triggerSaleh: (_) {},
        replayScene: () {},
        replayGeneration: 0);
    await tester.pumpWidget(support.app(
        ReviewScene(
            scene: const Scene(id: 'review', type: SceneType.review, data: {
              'questions': [
                {
                  'kind': 'word',
                  'reviewLessonId': 'jeem',
                  'prompt': 'أين جَ؟',
                  'options': ['جَمَل', 'حَبْل'],
                  'optionImages': [
                    'assets/images/assessment/camel_v43.png',
                    'assets/images/assessment/rope_v43.png'
                  ],
                  'correctIndex': 0,
                  'audio': 'question.mp3',
                  'successAudio': 'praise.mp3',
                  'answerAudio': 'example.mp3'
                }
              ]
            }),
            api: api),
        audio: audio));
    expect(audio.played, isEmpty);
    expect(find.text('أين جَ؟'), findsNothing);
    channel.markFinished();
    await tester.pump();
    expect(audio.played, ['question.mp3']);
    await tester.tap(find.text('جَمَل'));
    await tester.pump();
    expect(audio.played.last, 'praise.mp3');
    expect(find.text('تخطي'), findsNothing);
    expect(skipped, 0);
    await tester.pumpWidget(const SizedBox());
    audio.finish();
    await tester.pump(const Duration(seconds: 1));
    expect(audio.played, isNot(contains('example.mp3')));
    channel.dispose();
  });
  testWidgets('free writing keeps identical canvas and ink after feedback',
      (tester) async {
    final audio = PendingAudio();
    final channel = SceneChannel();
    final scene = fixtures
        .lesson('jeem')
        .scenes
        .singleWhere((s) => s.type == SceneType.freeWriting);
    await tester.pumpWidget(support.app(
        SizedBox(
            width: 620,
            height: 330,
            child: WritingScene(scene: scene, api: fixtures.api(channel))),
        audio: audio));
    final canvas = find.byType(FreeWritingCanvas);
    final before = tester.getRect(canvas);
    final points = jeemFathaTemplate.samples(before.size, 0, count: 100);
    final gesture = await tester.startGesture(before.topLeft + points.first);
    for (final p in points.skip(1)) {
      await gesture.moveTo(before.topLeft + p);
    }
    await gesture.up();
    await tester.pump();
    final ink = List.of(
        tester.state<FreeWritingCanvasState>(canvas).sample.strokes.first);
    await tester.tap(find.text('انتهيت'));
    await tester.pump();
    expect(tester.getRect(canvas), before);
    expect(
        tester.state<FreeWritingCanvasState>(canvas).sample.strokes.first, ink);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    audio.finish();
    channel.dispose();
  });
  testWidgets('guided writing can skip demonstration and then skip practice',
      (tester) async {
    final channel = SceneChannel();
    var skipped = 0;
    final api = SceneApi(
        profile: support.child,
        channel: channel,
        completeScene: () {},
        skipScene: () => skipped++,
        recordAttempt: () {},
        recordAnswer: ({required bool correct}) {},
        triggerSaleh: (_) {},
        replayScene: () {},
        replayGeneration: 0);
    final scene = fixtures
        .lesson('haa')
        .scenes
        .singleWhere((s) => s.type == SceneType.guidedWriting);
    await tester.pumpWidget(support.app(WritingScene(scene: scene, api: api)));
    expect(find.byType(WatchLetterAnimation), findsOneWidget);
    await tester.tap(find.text('تخطي الشرح'));
    await tester.pump();
    expect(find.byType(WatchLetterAnimation), findsNothing);
    expect(find.byType(GuidedTracingCanvas), findsOneWidget);
    expect(skipped, 0);
    expect(channel.scriptInterrupted.value, true);
    await tester.tap(find.text('تخطي'));
    await tester.pump();
    expect(skipped, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    channel.dispose();
  });
  testWidgets('parent actions have equal sizes and fit the phone viewport',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      await tester.pumpWidget(support.app(SizedBox(
          height: size.height - 60,
          child: ParentDashboard(
              child: support.child,
              children: const [support.child],
              progress: null,
              onSelect: (_) {},
              onAdd: () {},
              onEdit: () {}))));
      await support.frames(tester);
      final add =
          tester.getRect(find.byKey(const ValueKey('profile-action-add')));
      final edit =
          tester.getRect(find.byKey(const ValueKey('profile-action-edit')));
      final profile = tester
          .getRect(find.byKey(ValueKey('profile-action-${support.child.id}')));
      expect(add.size, edit.size);
      expect(add.size, profile.size);
      expect(add.bottom, lessThan(size.height));
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('V45_VISUAL')) {
        await expectLater(find.byKey(const ValueKey('v38-capture')),
            matchesGoldenFile('goldens/v45-parent-${size.width.toInt()}.png'));
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
  test('adaptive reveal covers every outline point on each curved letter', () {
    for (final template in [
      alifFathaVideoTemplate,
      jeemFathaTemplate,
      haaFathaTemplate
    ]) {
      final rect = template.drawingRect(const Size(600, 280));
      for (final part in template.guideParts.where((p) => !p.isDot)) {
        final samples = part.samples(rect, count: 240);
        final radius = part.revealStrokeWidth(rect) / 2;
        for (final point in part.outline) {
          final p = Offset(rect.left + point.dx * rect.width,
              rect.top + point.dy * rect.height);
          final distance = samples.map((s) => (p - s).distance).reduce(min);
          expect(distance, lessThan(radius),
              reason: '${template.id}/${part.id}');
        }
      }
    }
  });
}
