import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/core/design/widgets/app_button.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/features/home/family_store.dart';
import 'package:saleh_app/features/home/learner_chooser.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/explanation_scene.dart';
import 'package:saleh_app/features/lesson/scenes/mcq_scene.dart';
import 'package:saleh_app/features/lesson/scenes/pronunciation_scene.dart';
import 'package:saleh_app/features/lesson/scenes/writing_scene.dart';
import 'package:saleh_app/features/lesson/widgets/saleh_script_player.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/speech/speech_service.dart';
import 'v38_test.dart' as support;
import 'v44_test.dart' as fixtures;

class ManualAudio implements AudioService {
  final played = <String>[];
  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);
  Completer<void>? _pending;
  void finish() {
    playing.value = false;
    if (_pending?.isCompleted == false) _pending!.complete();
  }

  @override
  Future<void> play(String path) {
    finish();
    played.add(path);
    playing.value = true;
    _pending = Completer<void>();
    return _pending!.future;
  }

  @override
  Future<void> stop() async => finish();
  @override
  Future<void> dispose() async {
    finish();
  }
}

class ThreeAttempts extends MockSpeechService {
  int calls = 0;
  @override
  Future<SpeechResult> listenFor(String expected) async =>
      SpeechResult(correct: ++calls >= 3);
}

SceneApi api(SceneChannel channel,
        {VoidCallback? complete, VoidCallback? record, VoidCallback? replay}) =>
    SceneApi(
        profile: support.child,
        channel: channel,
        completeScene: complete ?? () {},
        recordAttempt: record ?? () {},
        recordAnswer: ({required bool correct}) {},
        triggerSaleh: (_) {},
        replayScene: replay ?? () {},
        replayGeneration: 0);
Finder action(String label) => find.widgetWithText(LessonActionButton, label);
Finder glyph(String letter) =>
    find.byWidgetPredicate((w) => w is LetterGlyph && w.letter == letter);
Scene scene(String id, SceneType type) =>
    fixtures.lesson(id).scenes.singleWhere((s) => s.type == type);

Future<void> drawTemplate(
    WidgetTester tester, LetterTraceTemplate template) async {
  final rect = tester.getRect(find.byType(FreeWritingCanvas));
  for (var part = 0; part < template.guideParts.length; part++) {
    final points = template.samples(rect.size, part, count: 100);
    final gesture = await tester.startGesture(rect.topLeft + points.first);
    for (final p in points.skip(1)) {
      await gesture.moveTo(rect.topLeft + p);
    }
    await gesture.up();
  }
  await tester.pump();
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

  test('all six lessons use one guide attempt and purpose-correct feedback',
      () {
    for (final id in ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa']) {
      final guided = scene(id, SceneType.guidedWriting);
      expect((guided.data['writing'] as Map)['guidedAttempts'], 1);
      expect(guided.lines.first.male, isNot(contains('مرة')));
      expect(scene(id, SceneType.freeWriting).data['successAudio'],
          'assets/audio/v46/free_praise.mp3');
      expect(scene(id, SceneType.pronunciation).data['successAudio'].toString(),
          contains('pronounce_success'));
      final quiz = scene(id, SceneType.multipleChoice);
      expect(
          quiz.lines.single.male, 'والآن سأراجع معكم ما تعلمناه في هذا اليوم.');
      expect(quiz.data['questionAfterIntro'], true);
      expect((quiz.data['questions'] as List).first['audio'], isNotNull);
      if (id != 'alif') expect(scene(id, SceneType.review).canSkip, false);
    }
    expect(scene('thaa', SceneType.explanation).lines[2].audio,
        'assets/audio/v46/thaa_example.mp3');
    expect(scene('thaa', SceneType.explanation).lines[4].audio,
        'assets/audio/v46/thaa_example.mp3');
    final manifest =
        jsonDecode(File('AUDIO_V46_MANIFEST.json').readAsStringSync()) as Map;
    expect(manifest.length, 9);
    for (final path in manifest.keys) {
      expect(File(path as String).lengthSync(), greaterThan(1000));
    }
  });

  testWidgets('explanation actions wait for completion and hide during replay',
      (tester) async {
    final channel = SceneChannel();
    await tester.pumpWidget(support.app(ExplanationScene(
        scene: scene('thaa', SceneType.explanation),
        api:
            api(channel, replay: () => channel.scriptFinished.value = false))));
    expect(action('فهمت!'), findsNothing);
    expect(action('إعادة الشرح'), findsNothing);
    channel.markFinished();
    await tester.pump();
    expect(action('فهمت!'), findsOneWidget);
    expect(tester.getCenter(action('فهمت!')).dx,
        lessThan(tester.getCenter(action('إعادة الشرح')).dx));
    await tester.tap(action('إعادة الشرح'));
    await tester.pump();
    expect(action('فهمت!'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    channel.dispose();
  });

  testWidgets(
      'pronunciation skip appears after two results; success finishes before continue',
      (tester) async {
    final channel = SceneChannel();
    final speech = ThreeAttempts();
    final audio = ManualAudio();
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
                          'retryAudio': 'retry',
                          'successAudio': 'pronounce_success'
                        }),
                    api: api(channel))))));
    expect(action('تخطي'), findsNothing);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump();
      expect(action('تخطي'), i == 0 ? findsNothing : findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
    expect(audio.playing.value, true);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    expect(audio.played.last, 'pronounce_success');
    expect(action('متابعة'), findsNothing);
    audio.finish();
    await tester.pump();
    await tester.pump();
    expect(action('متابعة'), findsOneWidget);
    expect(tester.getCenter(action('متابعة')).dx, lessThan(400));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    channel.dispose();
  });

  testWidgets('guide plays once; repeat is optional and completion stays left',
      (tester) async {
    final channel = SceneChannel();
    var complete = 0;
    var attempts = 0;
    await tester.pumpWidget(support.app(SizedBox(
        width: 600,
        height: 340,
        child: WritingScene(
            scene: scene('haa', SceneType.guidedWriting),
            api: api(channel,
                complete: () => complete++, record: () => attempts++)))));
    tester
        .widget<WatchLetterAnimation>(find.byType(WatchLetterAnimation))
        .onFinished!();
    await tester.pump();
    expect(find.byType(WatchLetterAnimation), findsNothing);
    tester
        .widget<GuidedTracingCanvas>(find.byType(GuidedTracingCanvas))
        .onAllCompleted();
    await tester.pump();
    expect(complete, 0);
    expect(action('فهمت طريقة الكتابة'), findsOneWidget);
    expect(action('تكرار الكتابة بالدليل'), findsOneWidget);
    expect(action('مرة أخرى'), findsNothing);
    expect(action('تخطي'), findsNothing);
    expect(tester.getCenter(action('فهمت طريقة الكتابة')).dx,
        lessThan(tester.getCenter(action('تكرار الكتابة بالدليل')).dx));
    await tester.tap(action('تكرار الكتابة بالدليل'));
    await tester.pump();
    expect(find.byType(GuidedTracingCanvas), findsOneWidget);
    expect(complete, 0);
    tester
        .widget<GuidedTracingCanvas>(find.byType(GuidedTracingCanvas))
        .onAllCompleted();
    await tester.pump();
    await tester.tap(action('فهمت طريقة الكتابة'));
    await tester.pump();
    expect(complete, 1);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    channel.dispose();
  });

  testWidgets(
      'free success is readable, interrupts intro, preserves canvas and waits for audio',
      (tester) async {
    final channel = SceneChannel();
    final audio = ManualAudio();
    var complete = 0;
    await tester.pumpWidget(support.app(
        SizedBox(
            width: 620,
            height: 360,
            child: WritingScene(
                scene: scene('jeem', SceneType.freeWriting),
                api: api(channel, complete: () => complete++))),
        audio: audio));
    unawaited(audio.play('old-intro'));
    final rect = tester.getRect(find.byType(FreeWritingCanvas));
    await drawTemplate(tester, jeemFathaTemplate);
    await tester.tap(action('انتهيت'));
    await tester.pump();
    await tester.pump();
    expect(channel.scriptInterrupted.value, true);
    expect(audio.played.last, 'assets/audio/v46/free_praise.mp3');
    expect(find.text('ممتاز! أحسنتم كتابة الحرف'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final panel = tester
        .getRect(find.byKey(const ValueKey('free-writing-feedback-panel')));
    expect(panel.top, greaterThanOrEqualTo(rect.bottom));
    expect(panel.bottom, lessThanOrEqualTo(rect.bottom + 44));
    expect(tester.getRect(find.byType(FreeWritingCanvas)), rect);
    await tester.pump(const Duration(seconds: 5));
    expect(complete, 0);
    audio.finish();
    await tester.pump();
    expect(complete, 1);
    await tester.pumpWidget(const SizedBox());
    channel.dispose();
  });

  testWidgets(
      'assessment introduces once before question and never exposes review skip',
      (tester) async {
    final channel = SceneChannel();
    final audio = ManualAudio();
    final quiz = scene('jeem', SceneType.multipleChoice);
    await tester.pumpWidget(support.app(
        Stack(children: [
          McqScene(scene: quiz, api: api(channel)),
          Offstage(
              child: SalehScriptPlayer(
                  lines: quiz.lines,
                  profile: support.child,
                  stopSignal: channel.scriptInterrupted,
                  onFinished: channel.markFinished))
        ]),
        audio: audio));
    await tester.pump(const Duration(milliseconds: 500));
    expect(audio.played, ['assets/audio/v46/assessment_intro.mp3']);
    await tester.tap(glyph('جَ'));
    await tester.pump();
    expect(audio.played.length, 1);
    audio.finish();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(audio.played, [
      'assets/audio/v46/assessment_intro.mp3',
      'assets/audio/jeem_v44/assessment_1.mp3'
    ]);
    await tester.tap(glyph('جَ'));
    await tester.pump();
    expect(tester.getCenter(action('السؤال التالي')).dx, lessThan(400));
    await tester.tap(action('السؤال التالي'));
    await tester.pump();
    await tester.tap(find.text('جَمَل'));
    await tester.pump();
    expect(tester.getCenter(action('إنهاء التقويم')).dx, lessThan(400));
    await tester.pumpWidget(const SizedBox());
    audio.finish();
    channel.dispose();
  });

  testWidgets(
      'multiple children choose once per launch and selected repository is isolated',
      (tester) async {
    const second = ChildProfile(
        id: 'second',
        name: 'عبدالله',
        gender: ChildGender.male,
        age: 4,
        avatar: 'career_0');
    SharedPreferences.setMockInitialValues({
      'family_v36': jsonEncode([support.child.toJson(), second.toJson()]),
      'child_profile': jsonEncode(support.child.toJson()),
      'active_child_v36': support.child.id,
      'child_second_lesson_alif': jsonEncode(
          const LessonProgress(lessonId: 'alif', lastSceneIndex: 5).toJson()),
      'child_${support.child.id}_lesson_alif': jsonEncode(
          const LessonProgress(lessonId: 'alif', lastSceneIndex: 2).toJson()),
    });
    final visible = ValueNotifier(true);
    await tester.pumpWidget(support.app(ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, show, __) =>
            show ? const WorldScreen() : const SizedBox())));
    await support.frames(tester);
    expect(find.text('من يتعلم اليوم؟'), findsOneWidget);
    expect(find.byKey(const ValueKey('learner-choice-second')), findsOneWidget);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WorldScreen)));
    await tester.tap(find.byKey(const ValueKey('learner-choice-second')));
    await support.frames(tester);
    expect(find.byType(LearnerChooser), findsNothing);
    expect(container.read(activeChildIdProvider), 'second');
    expect(await FamilyStore().activeId(), 'second');
    expect(
        (await container
                .read(progressRepositoryProvider)
                .loadLessonProgress('alif'))
            ?.lastSceneIndex,
        5);
    expect((await container.read(childProfileProvider.future)).name, 'عبدالله');
    visible.value = false;
    await tester.pump();
    visible.value = true;
    await support.frames(tester);
    expect(find.byType(LearnerChooser), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(support.app(const WorldScreen()));
    await support.frames(tester);
    expect(find.text('من يتعلم اليوم؟'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    visible.dispose();
  });

  testWidgets('single child goes directly home', (tester) async {
    await tester.pumpWidget(support.app(const WorldScreen()));
    await support.frames(tester);
    expect(find.byType(LearnerChooser), findsNothing);
    expect(find.text('ابدأ رحلتك'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'full phone lesson keeps feedback below the unchanged white canvas',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = ManualAudio();
    await tester.pumpWidget(support.app(
        const LessonScreen(lessonId: 'thaa', initialScene: 6),
        audio: audio));
    await support.frames(tester);
    final rect = tester.getRect(find.byType(FreeWritingCanvas));
    await drawTemplate(tester, thaaFathaTemplate);
    await tester.tap(action('انتهيت'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byType(FreeWritingCanvas)), rect);
    expect(find.text('ممتاز! أحسنتم كتابة الحرف'), findsOneWidget);
    final panel = tester
        .getRect(find.byKey(const ValueKey('free-writing-feedback-panel')));
    expect(panel.top, greaterThanOrEqualTo(rect.bottom));
    expect(panel.bottom, lessThanOrEqualTo(rect.bottom + 44));
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('V46_VISUAL')) {
      await expectLater(find.byKey(const ValueKey('v38-capture')),
          matchesGoldenFile('goldens/v46-free-success.png'));
    }
    await tester.pumpWidget(const SizedBox());
    audio.finish();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('guided completion and learner cards fit small and large phones',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      await tester.pumpWidget(
          support.app(const LessonScreen(lessonId: 'thaa', initialScene: 5)));
      await support.frames(tester);
      tester
          .widget<WatchLetterAnimation>(find.byType(WatchLetterAnimation))
          .onFinished!();
      await tester.pump();
      tester
          .widget<GuidedTracingCanvas>(find.byType(GuidedTracingCanvas))
          .onAllCompleted();
      await tester.pump();
      expect(tester.takeException(), isNull);
      final left = tester.getRect(action('فهمت طريقة الكتابة'));
      final right = tester.getRect(action('تكرار الكتابة بالدليل'));
      expect(left.right, lessThanOrEqualTo(right.left));
      expect(left.bottom, lessThanOrEqualTo(size.height));
      if (const bool.fromEnvironment('V46_VISUAL')) {
        await expectLater(find.byKey(const ValueKey('v38-capture')),
            matchesGoldenFile('goldens/v46-guide-${size.width.toInt()}.png'));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(support.app(LearnerChooser(children: const [
        support.child,
        ChildProfile(
            id: 'two',
            name: 'عبدالله',
            gender: ChildGender.male,
            avatar: 'career_0',
            age: 4)
      ], onSelect: (_) {})));
      await support.frames(tester);
      final first = tester
          .getRect(find.byKey(ValueKey('learner-choice-${support.child.id}')));
      final second =
          tester.getRect(find.byKey(const ValueKey('learner-choice-two')));
      expect(first.size, second.size);
      expect(first.bottom, lessThan(size.height));
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('V46_VISUAL')) {
        await expectLater(find.byKey(const ValueKey('v38-capture')),
            matchesGoldenFile('goldens/v46-chooser-${size.width.toInt()}.png'));
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}
