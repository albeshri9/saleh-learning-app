import 'dart:convert';
import 'package:saleh_app/features/lesson/widgets/saleh_script_player.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/features/home/lessons_catalog.dart';
import 'package:saleh_app/features/home/learning_journal.dart';
import 'package:saleh_app/features/lesson/lesson_controller.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/review_scene.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/speech/speech_service.dart';
import 'v38_test.dart' as support;

Lesson lesson(String id) => Lesson.fromJson(
    jsonDecode(File('assets/content/lesson_$id.json').readAsStringSync()));
Finder glyph(String letter) =>
    find.byWidgetPredicate((w) => w is LetterGlyph && w.letter == letter);

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

  testWidgets('early review answer cancels queued narration and startup retry',
      (tester) async {
    final audio = RecordedAudio();
    final stopped = ValueNotifier(false);
    final review = lesson('taa').scenes[1];
    await tester.pumpWidget(support.app(
        SalehScriptPlayer(
            lines: review.lines, profile: support.child, stopSignal: stopped),
        audio: audio));
    await tester.pump(const Duration(milliseconds: 500));
    expect(audio.assets, ['assets/audio/taa/prior_review.mp3']);
    stopped.value = true;
    await audio.play('assets/audio/taa/assessment_success.mp3');
    await tester.pump(const Duration(seconds: 3));
    expect(audio.assets, [
      'assets/audio/taa/prior_review.mp3',
      'assets/audio/taa/assessment_success.mp3'
    ]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    stopped.dispose();
  });

  test('seven ordered stages, three available letters, cumulative review only',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final programs = await c.read(contentRepositoryProvider).loadPrograms();
    expect(programs.single.stages.map((s) => s.id), [
      'letters_fatha',
      'letters_kasra',
      'letters_damma',
      'sukun',
      'madd',
      'shadda',
      'tanween'
    ]);
    expect(
        programs.single.stages.first.levels.single.lessons
            .map((l) => l.lessonId),
        ['alif', 'baa', 'taa']);
    for (final id in ['baa', 'taa']) {
      final l = await c.read(contentRepositoryProvider).loadLesson(id);
      expect(l.scenes.length, 9);
      final review = l.scenes.singleWhere((s) => s.type == SceneType.review);
      final expected = id == 'baa' ? ['alif'] : ['alif', 'baa'];
      expect(review.data['priorLessonIds'], expected);
      expect((review.data['questions'] as List).map((q) => q['reviewLessonId']),
          expected);
      expect(review.canSkip, isFalse);
      expect(lessonSceneAllowsGlobalNext(review.type), isFalse);
      expect(
          l.scenes
              .where((s) => s.type == SceneType.freeWriting)
              .single
              .data['lessonId'],
          id);
    }
  });

  test(
      'new lessons resume independently, restart after completion and isolate awards',
      () async {
    final c = ProviderContainer();
    final keep = c.listen(allLessonProgressProvider, (_, __) {});
    addTearDown(() {
      keep.close();
      c.dispose();
    });
    final repo = c.read(progressRepositoryProvider);
    await repo.saveLessonProgress(
        const LessonProgress(lessonId: 'baa', lastSceneIndex: 5));
    await repo.saveLessonProgress(const LessonProgress(
        lessonId: 'taa', lastSceneIndex: 7, completed: true));
    for (final id in ['baa', 'taa']) {
      final sub = c.listen(lessonControllerProvider(id), (_, __) {});
      final state = await c.read(lessonControllerProvider(id).future);
      expect(state.sceneIndex, id == 'baa' ? 5 : 0);
      final controller = c.read(lessonControllerProvider(id).notifier);
      controller.jumpToScene(1);
      controller.recordAnswer(correct: false);
      expect(c.read(lessonControllerProvider(id)).value!.totalQuestions, 0);
      sub.close();
    }
    c.invalidate(allLessonProgressProvider);
    final records = await c.read(allLessonProgressProvider.future);
    expect(records['baa']!.completed, isFalse);
    expect(records['taa']!.completed, isTrue);
    final journal = c.listen(journalDataProvider, (_, __) {});
    expect(
        (await c.read(journalDataProvider.future))
            .awards['lesson:taa:complete'],
        20);
    expect((await LearningJournal('other-child').load()).points, 0);
    journal.close();
  });

  test('recognition accepts letter transcriptions but not unrelated words', () {
    for (final text in ['با', 'بَ', 'باء']) {
      expect(speechMatchesExpected(text, 'با'), isTrue);
    }
    for (final text in ['تا', 'تَ', 'تاء']) {
      expect(speechMatchesExpected(text, 'تا'), isTrue);
    }
    expect(speechMatchesExpected('بطة', 'با'), isFalse);
    expect(speechMatchesExpected('تاج', 'تا'), isFalse);
    expect(speechMatchesExpected('با', 'تا'), isFalse);
  });

  for (final template in [baaFathaTemplate, taaFathaTemplate]) {
    test('${template.id}: right-to-left, dots, fatha, free-writing coverage',
        () {
      const size = Size(480, 220);
      final parts = template.guideParts;
      expect(parts.first.id, 'body');
      expect(parts.last.id, 'fatha');
      expect(parts.first.centerline.first.dx,
          greaterThan(parts.first.centerline.last.dx));
      expect(parts.where((p) => p.isDot).length,
          template == baaFathaTemplate ? 1 : 2);
      final ink = [
        for (var i = 0; i < parts.length; i++)
          template.samples(size, i, count: 100)
      ];
      expect(
          validateDottedLetterWriting(
                  WritingSample(strokes: ink, canvasSize: size), template)
              .isValid,
          isTrue);
      expect(
          validateDottedLetterWriting(
                  WritingSample(
                      strokes: [ink.first, ink.last], canvasSize: size),
                  template)
              .isValid,
          isFalse);
      expect(
          validateDottedLetterWriting(
                  WritingSample(strokes: [
                    [const Offset(10, 110), const Offset(470, 110)]
                  ], canvasSize: size),
                  template)
              .isValid,
          isFalse);
      for (final viewport in [
        const Size(24, 24),
        const Size(52, 52),
        const Size(130, 64)
      ]) {
        final painter = LetterGlyphPainter(template, Colors.red);
        final bounds = Offset.zero & viewport;
        for (final part in template.parts) {
          final outline =
              part.outlinePath(painter.fittedRect(viewport)).getBounds();
          expect(bounds.inflate(.01).contains(outline.topLeft), isTrue);
          expect(bounds.inflate(.01).contains(outline.bottomRight), isTrue);
        }
      }
    });

    testWidgets('${template.id}: finger traces complete each dot separately',
        (tester) async {
      var completed = 0;
      final strokes = <int>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 480,
                      height: 220,
                      child: GuidedTracingCanvas(
                          letter: template == baaFathaTemplate ? 'بَ' : 'تَ',
                          strokes: template.strokes,
                          traceTemplate: template,
                          onStrokeCompleted: strokes.add,
                          onAllCompleted: () => completed++))))));
      final origin = tester.getTopLeft(find.byType(GuidedTracingCanvas));
      final size = tester.getSize(find.byType(GuidedTracingCanvas));
      for (var i = 0; i < template.parts.length; i++) {
        final points = template.samples(size, i, count: 240);
        if (template.guideParts[i].isDot) {
          await tester.tapAt(origin + points.first);
        } else {
          final gesture = await tester.startGesture(origin + points.first);
          for (final point in points.skip(1)) {
            await gesture.moveTo(origin + point);
          }
          await gesture.up();
        }
        await tester.pump(const Duration(milliseconds: 100));
        expect(strokes.contains(i), isTrue, reason: 'part $i');
      }
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets(
      'Taa review requires both previous letters, retries and changes audio',
      (tester) async {
    final scene = lesson('taa').scenes[1];
    final audio = RecordedAudio();
    final channel = SceneChannel();
    var completed = 0;
    final api = SceneApi(
        profile: support.child,
        channel: channel,
        completeScene: () => completed++,
        recordAttempt: () {},
        recordAnswer: ({required bool correct}) {},
        triggerSaleh: (_) {},
        replayScene: () {},
        replayGeneration: 0);
    await tester.pumpWidget(support.app(
        SizedBox(
            width: 550,
            height: 290,
            child: ReviewScene(scene: scene, api: api)),
        audio: audio));
    await tester.tap(glyph('تَ'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(audio.assets.last, 'assets/audio/taa/prior_review_retry.mp3');
    expect(completed, 0);
    await tester.tap(glyph('أَ'));
    await tester.pump();
    expect(audio.assets.last, 'assets/audio/taa/assessment_success.mp3');
    await tester.tap(find.text('السؤال التالي'));
    await tester.pump();
    expect(audio.assets.last, 'assets/audio/taa/prior_review_3.mp3');
    expect(completed, 0);
    await tester.tap(glyph('بَ'));
    await tester.pump();
    expect(audio.assets.last, 'assets/audio/taa/prior_review_success.mp3');
    await tester.tap(find.text('نبدأ الحرف الجديد'));
    await tester.pump();
    expect(completed, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    channel.dispose();
    await audio.dispose();
  });

  testWidgets(
      'catalog fits small landscape and letters open immediately with tiny badge',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      support.seed(const LessonProgress(lessonId: 'alif', completed: true));
      String? selected;
      await tester.pumpWidget(
          support.app(LessonsCatalog(onLesson: (id) => selected = id)));
      await support.frames(tester);
      final first = tester.getRect(find.text('الحروف بحركة الفتح'));
      final second = tester.getRect(find.text('الحروف بحركة الكسر'));
      expect(first.center.dx, greaterThan(second.center.dx));
      await tester.tap(find.text('الحروف بحركة الفتح'));
      await support.frames(tester);
      expect(tester.getSize(find.byKey(const ValueKey('lesson-complete-alif'))),
          const Size(20, 20));
      expect(glyph('أَ'), findsOneWidget);
      for (final id in ['alif', 'baa', 'taa']) {
        await tester.ensureVisible(find.byKey(ValueKey('lesson-card-$id')));
        await tester.tap(find.byKey(ValueKey('lesson-card-$id')));
        await tester.pump();
        expect(selected, id);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('all new lesson scenes keep right rail and fit phones',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      for (final id in ['baa', 'taa']) {
        for (var index = 0; index < 9; index++) {
          await tester.pumpWidget(
              support.app(LessonScreen(lessonId: id, initialScene: index)));
          await support.frames(tester, 12);
          expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '$id scene $index size $size');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
      }
    }
  });

  testWidgets('v41 visual review of catalog and every new interaction',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(support.app(LessonsCatalog(onLesson: (_) {})));
    await support.frames(tester);
    await expectLater(find.byKey(const ValueKey('v38-capture')),
        matchesGoldenFile('goldens/v41-stages.png'));
    await tester.tap(find.text('الحروف بحركة الفتح'));
    await support.frames(tester);
    await expectLater(find.byKey(const ValueKey('v38-capture')),
        matchesGoldenFile('goldens/v41-letters.png'));
    await tester.pumpWidget(const SizedBox());
    for (final id in ['baa', 'taa']) {
      for (final index in [1, 3, 4, 5, 6, 7]) {
        await tester.pumpWidget(
            support.app(LessonScreen(lessonId: id, initialScene: index)));
        await support.frames(tester, 25);
        if (index == 3) await support.frames(tester, 40);
        if (index == 5) {
          for (var pass = 0; pass < 2; pass++) {
            tester
                .widget<WatchLetterAnimation>(find.byType(WatchLetterAnimation))
                .onFinished!();
            await tester.pump();
          }
        }
        expect(tester.takeException(), isNull);
        await expectLater(find.byKey(const ValueKey('v38-capture')),
            matchesGoldenFile('goldens/v41-$id-$index.png'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    }
  }, tags: ['visual']);
}

class RecordedAudio extends SilentAudioService {
  final assets = <String>[];
  @override
  Future<void> play(String path) async {
    assets.add(path);
  }
}
