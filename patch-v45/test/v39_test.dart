import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/features/home/learning_journal.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/lesson/lesson_controller.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/character/video/saleh_video_renderer.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';
import 'package:saleh_app/features/lesson/scenes/writing_scene.dart';
import 'package:saleh_app/features/home/learning_destinations.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'v38_test.dart' as support;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  extraTests();
  setUp(() {
    support.seed();
    // Each widget test has its own fake-async zone. Do not reuse a loadString
    // Future captured by a previous zone across provider-container lifetimes.
    rootBundle.evict('assets/content/lesson_packs.json');
    rootBundle.evict('assets/content/lesson_alif.json');
  });
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test('opening a completed lesson never waits for journal bookkeeping',
      () async {
    support.seed(const LessonProgress(
        lessonId: 'alif',
        completed: true,
        completedScenes: ['explain_1', 'write_guided_1']));
    final journal = DeferredJournal();
    final container = ProviderContainer(
        overrides: [journalProvider.overrideWithValue(journal)]);
    final sub = container.listen(lessonControllerProvider('alif'), (_, __) {});
    try {
      final state = await container
          .read(lessonControllerProvider('alif').future)
          .timeout(const Duration(seconds: 1));
      expect(state.sceneIndex, 0);
      final controller =
          container.read(lessonControllerProvider('alif').notifier);
      controller.jumpToScene(state.lesson.scenes.length - 1);
      await controller.completeScene().timeout(const Duration(seconds: 1));
      expect(
          (await container
                  .read(progressRepositoryProvider)
                  .loadLessonProgress('alif'))!
              .completed,
          isTrue);
    } finally {
      journal.done.complete();
      sub.close();
      container.dispose();
    }
  });
  testWidgets('route lifetime does not leave a loading wheel on the start card',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const WorldScreen()),
      GoRoute(
          path: '/lesson/:id',
          builder: (_, __) => const Scaffold(body: Text('lesson opened'))),
    ]);
    await tester.pumpWidget(routed(router));
    await support.frames(tester);
    await tester.tap(find.text('ابدأ رحلتك'));
    await support.frames(tester);
    expect(find.text('lesson opened'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(WorldScreen, skipOffstage: false),
            matching:
                find.byType(CircularProgressIndicator, skipOffstage: false)),
        findsNothing);
    router.pop();
    await support.frames(tester);
    await tester.tap(find.text('ابدأ رحلتك'));
    await support.frames(tester);
    expect(find.text('lesson opened'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}

Widget routed(GoRouter router) => ProviderScope(
        overrides: [
          audioServiceProvider.overrideWithValue(SilentAudioService()),
        ],
        child: MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(fontFamily: 'Tajawal'),
            locale: const Locale('ar'),
            supportedLocales: const [
              Locale('ar')
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ]));

void extraTests() {
  testWidgets('finish, badge, reopen and exit work repeatedly with real routes',
      (tester) async {
    support.seed(const LessonProgress(lessonId: 'alif', lastSceneIndex: 6));
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const WorldScreen()),
      GoRoute(
          path: '/lesson/:id',
          builder: (_, __) => const LessonScreen(lessonId: 'alif')),
    ]);
    await tester.pumpWidget(routed(router));
    await support.frames(tester);
    await tester.tap(find.text('أكمل رحلتك'));
    await support.frames(tester, 20);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(LessonScreen)));
    await container
        .read(lessonControllerProvider('alif').notifier)
        .completeScene();
    await support.frames(tester);
    expect(
        (await container
                .read(progressRepositoryProvider)
                .loadLessonProgress('alif'))!
            .completed,
        isTrue);
    await tester.tap(find.text('العودة للرئيسية'));
    await support.frames(tester, 20);
    expect(find.byKey(const ValueKey('home-lesson-complete')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('نبدأ رحلة الألف من جديد'));
    await support.frames(tester, 20);
    expect(
        container.read(lessonControllerProvider('alif')).value!.sceneIndex, 0);
    await tester.tap(find.byTooltip('الرئيسية'));
    await support.frames(tester, 20);
    await tester.tap(find.text('تأسيس اللغة العربية'));
    await support.frames(tester);
    await tester.tap(find.text('الحروف بحركة الفتح'));
    await support.frames(tester);
    for (var attempt = 0; attempt < 2; attempt++) {
      expect(
          find.byKey(const ValueKey('lesson-complete-alif')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lesson-card-alif')));
      await support.frames(tester, 20);
      expect(find.byType(LessonScreen), findsOneWidget);
      await tester.tap(find.byTooltip('الرئيسية'));
      await support.frames(tester, 20);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  testWidgets(
      'right rail, taller board and same Saleh dimensions in every scene',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(568, 320),
      const Size(667, 375),
      const Size(844, 390)
    ]) {
      support.viewport(tester, size);
      Size? teacher;
      for (var scene = 0; scene < 8; scene++) {
        await tester.pumpWidget(
            support.app(LessonScreen(lessonId: 'alif', initialScene: scene)));
        await support.frames(tester, 20);
        final board =
            tester.getRect(find.byKey(const ValueKey('lesson-board')));
        final rail =
            tester.getRect(find.byKey(const ValueKey('lesson-steps-right')));
        expect(rail.left, greaterThan(board.right));
        expect(board.height, greaterThan(size.height - 75));
        expect(board.width / board.height, lessThan(2));
        final character = tester.widget<SalehVideoRenderer>(
            find.byKey(const ValueKey('lesson-saleh')));
        final dimensions = Size(character.width!, character.height!);
        teacher ??= dimensions;
        expect(dimensions, teacher);
        for (var i = 0; i < 4; i++) {
          final stop = tester.getRect(find.byKey(ValueKey('milestone-$i')));
          expect(stop.left, greaterThan(board.right));
          expect(stop.height, greaterThanOrEqualTo(44));
        }
        expect(tester.takeException(), isNull, reason: '$size scene $scene');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    }
  });
  testWidgets('completed writing glows only on letter without panel decoration',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        support.app(const LessonScreen(lessonId: 'alif', initialScene: 4)));
    await support.frames(tester, 20);
    for (var i = 0; i < 2; i++) {
      tester
          .widget<WatchLetterAnimation>(find.byType(WatchLetterAnimation))
          .onFinished!();
      await tester.pump();
    }
    tester
        .widget<GuidedTracingCanvas>(find.byType(GuidedTracingCanvas))
        .onAllCompleted();
    await tester.pump();
    expect(
        tester
            .widget<CompletedTracingCanvas>(find.byType(CompletedTracingCanvas))
            .glow,
        isTrue);
    final decoration = tester.widgetList<DecoratedBox>(find.descendant(
        of: find.byType(WritingScene), matching: find.byType(DecoratedBox)));
    expect(
        decoration.where((w) =>
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration)
                        .boxShadow
                        ?.any((s) => s.spreadRadius > 0) ==
                    true ||
                (w.decoration as BoxDecoration).gradient is RadialGradient)),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('v39 lesson visual review', (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scene in [2, 3, 4, 5, 6, 7]) {
      await tester.pumpWidget(
          support.app(LessonScreen(lessonId: 'alif', initialScene: scene)));
      await support.frames(tester, 25);
      if (scene == 4) {
        for (var i = 0; i < 2; i++) {
          tester
              .widget<WatchLetterAnimation>(find.byType(WatchLetterAnimation))
              .onFinished!();
          await tester.pump();
        }
        tester
            .widget<GuidedTracingCanvas>(find.byType(GuidedTracingCanvas))
            .onAllCompleted();
        await support.frames(tester);
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('v38-capture')),
          matchesGoldenFile('goldens/scene-$scene-v39.png'));
      await tester.pumpWidget(const SizedBox());
    }
    await tester.pumpWidget(support.app(LetterJourney(
        progress: const LessonProgress(lessonId: 'alif', completed: true),
        onAlif: () {})));
    await support.frames(tester);
    await expectLater(find.byKey(const ValueKey('v38-capture')),
        matchesGoldenFile('goldens/garden-v39.png'));
  }, tags: ['visual']);
}

class DeferredJournal extends LearningJournal {
  DeferredJournal() : super('legacy');
  final done = Completer<void>();
  @override
  Future<void> award(String id, int points) => done.future;
}
