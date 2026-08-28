import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/features/home/learning_destinations.dart';
import 'package:saleh_app/features/home/learning_journal.dart';
import 'package:saleh_app/features/home/profile_editor.dart';
import 'package:saleh_app/features/home/review_games.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/lesson/lesson_controller.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/option_order.dart';
import 'package:saleh_app/features/lesson/widgets/saleh_script_player.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';
import 'package:saleh_app/services/audio/audio_service.dart';

const child = ChildProfile(
    name: 'سارة', gender: ChildGender.female, age: 5, avatar: 'career_8');
Widget app(Widget body, {AudioService? audio}) => ProviderScope(
        overrides: [
          audioServiceProvider.overrideWithValue(audio ?? SilentAudioService())
        ],
        child: MaterialApp(
            theme: ThemeData(fontFamily: 'Tajawal'),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: RepaintBoundary(
                key: const ValueKey('v38-capture'),
                child: Scaffold(body: body))));
Future<void> frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void viewport(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
}

void seed([LessonProgress? progress]) =>
    SharedPreferences.setMockInitialValues({
      'child_profile': jsonEncode(child.toJson()),
      if (progress != null)
        'lesson_progress_alif': jsonEncode(progress.toJson())
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => seed());
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test('retry moves every choice and preserves original answer/image mapping',
      () {
    final rng = Random(7);
    var order = shuffledOptions(4, rng);
    for (var attempt = 0; attempt < 30; attempt++) {
      final next = shuffledOptions(4, rng, order);
      expect(next.toSet(), {0, 1, 2, 3});
      for (var i = 0; i < 4; i++) {
        expect(next.indexOf(i), isNot(order.indexOf(i)));
      }
      order = next;
    }
  });
  test(
      'points are idempotent, concurrent writes survive, and children are isolated',
      () async {
    final journal = LearningJournal('one');
    final lines = [
      [const Offset(10, 10), const Offset(20, 30)]
    ];
    final sample =
        WritingSample(strokes: lines, canvasSize: const Size(100, 100));
    final save = journal.saveDrawing('alif', sample, passed: false);
    lines.clear();
    await Future.wait([
      save,
      journal.award('game:alif:listen', 15),
      journal.award('game:alif:listen', 15),
      journal.award('lesson:alif:write', 10)
    ]);
    final result = await journal.load();
    expect(result.points, 25);
    expect(result.drawings.length, 1);
    expect((result.drawings.single['strokes'] as List).length, 1);
    expect((await LearningJournal('two').load()).points, 0);
  });
  test('lesson resumes unfinished activity and restarts a completed lesson',
      () async {
    for (final completed in [false, true]) {
      seed(LessonProgress(
          lessonId: 'alif', lastSceneIndex: 4, completed: completed));
      final container = ProviderContainer();
      final sub =
          container.listen(lessonControllerProvider('alif'), (_, __) {});
      final state =
          await container.read(lessonControllerProvider('alif').future);
      expect(state.sceneIndex, completed ? 0 : 4);
      sub.close();
      container.dispose();
    }
  });
  testWidgets('profile fits phones without scroll and removes starting point',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [
      const Size(568, 320),
      const Size(667, 375),
      const Size(844, 390),
      const Size(390, 844)
    ]) {
      viewport(tester, size);
      await tester.pumpWidget(app(const ChildProfileEditor(profile: child)));
      await frames(tester);
      expect(find.text('نقطة البداية'), findsNothing);
      for (var i = 0; i < 12; i++) {
        final rect = tester.getRect(find.byKey(ValueKey('career-$i')));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('letter opens lesson directly without activity chooser',
      (tester) async {
    viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const WorldScreen()),
      GoRoute(
          path: '/lesson/:id',
          builder: (_, s) => Scaffold(body: Text('opened ${s.uri}')))
    ]);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ar'),
            supportedLocales: const [
          Locale('ar')
        ],
            localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ])));
    await frames(tester);
    await tester.tap(find.text('دروسي'));
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('letter-node-0')));
    await frames(tester);
    expect(find.text('opened /lesson/alif'), findsOneWidget);
    expect(find.text('الدرس كاملًا'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
  test('older completed activities receive points without reopening lesson',
      () async {
    seed(const LessonProgress(
        lessonId: 'alif',
        completed: true,
        completedScenes: ['welcome_1', 'nasheed_1', 'explain_1', 'success_1']));
    final container = ProviderContainer();
    final sub = container.listen(journalDataProvider, (_, __) {});
    expect((await container.read(journalDataProvider.future)).points, 30);
    container.invalidate(journalDataProvider);
    expect((await container.read(journalDataProvider.future)).points, 30);
    sub.close();
    container.dispose();
  });
  testWidgets(
      'listening game wins after three answers and can close immediately',
      (tester) async {
    viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(app(const ReviewGameScreen(game: ReviewGame.listen)));
    await frames(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('أَ'));
      await tester.pump();
    }
    expect(find.text('أحسنت! أكملت اللعبة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    expect((await LearningJournal('legacy').load()).points, 15);
    expect(tester.takeException(), isNull);
  });
  testWidgets('memory cards match and game closes without disposed ref access',
      (tester) async {
    viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(app(const ReviewGameScreen(game: ReviewGame.memory)));
    await frames(tester);
    // Try each pair from the public cards; matched cards are disabled.
    for (var a = 0; a < 6; a++) {
      for (var b = a + 1; b < 6; b++) {
        await tester.tap(find.byKey(ValueKey('game-card-$a')));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('game-card-$b')));
        await tester.pump(const Duration(seconds: 1));
        if (find.text('أحسنت! أكملت اللعبة').evaluate().isNotEmpty) break;
      }
    }
    // A remaining open card may shift the pairing order; a second pass clears it.
    for (var round = 0;
        round < 8 && find.text('أحسنت! أكملت اللعبة').evaluate().isEmpty;
        round++) {
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byKey(ValueKey('game-card-$i')));
        await tester.pump(const Duration(seconds: 1));
      }
    }
    expect(find.text('أحسنت! أكملت اللعبة'), findsOneWidget);
    await frames(tester);
    expect((await LearningJournal('legacy').load()).points, 15);
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    expect(tester.takeException(), isNull);
  });
  testWidgets('collection game finishes and credits points once',
      (tester) async {
    viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(app(const ReviewGameScreen(game: ReviewGame.collect)));
    await frames(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('أَ').first);
      await frames(tester, 2);
    }
    await frames(tester);
    expect(find.text('أحسنت! أكملت اللعبة'), findsOneWidget);
    expect((await LearningJournal('legacy').load()).points, 15);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'free writing has guide, large area, chosen avatar and RTL milestones',
      (tester) async {
    viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(app(const LessonScreen(lessonId: 'alif', initialScene: 5)));
    await frames(tester, 25);
    expect(
        tester
            .widget<CareerAvatar>(
                find.byKey(const ValueKey('lesson-child-avatar')))
            .index,
        8);
    final canvas =
        tester.widget<FreeWritingCanvas>(find.byType(FreeWritingCanvas));
    expect(canvas.traceTemplate, isNotNull);
    expect(
        tester.getSize(find.byType(FreeWritingCanvas)).width, greaterThan(480));
    expect(tester.getSize(find.byType(FreeWritingCanvas)).height,
        greaterThan(200));
    for (var i = 0; i < 3; i++) {
      expect(
          tester.getCenter(find.byKey(ValueKey('milestone-$i'))).dy,
          lessThan(
              tester.getCenter(find.byKey(ValueKey('milestone-${i + 1}'))).dy));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('farewell waits for real audio position and never fires early',
      (tester) async {
    final audio = _ClockAudio();
    final lesson = await tester.runAsync(() async => Lesson.fromJson(jsonDecode(
            await rootBundle.loadString('assets/content/lesson_alif.json'))
        as Map<String, dynamic>));
    final events = <String>[];
    await tester.pumpWidget(app(
        SalehScriptPlayer(
            lines: lesson!.scenes.last.lines,
            profile: child,
            onEvent: (event) => events.add(event.params['name'] as String)),
        audio: audio));
    await frames(tester, 20);
    audio.position.value = const Duration(seconds: 8);
    await tester.pump();
    expect(events, isNot(contains('farewell')));
    audio.position.value = const Duration(milliseconds: 8650);
    await tester.pump();
    expect(events.where((e) => e == 'farewell').length, 1);
    audio.position.value = const Duration(seconds: 9);
    await tester.pump();
    expect(events.where((e) => e == 'farewell').length, 1);
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 10);
  });
  testWidgets('v38 visual review', (tester) async {
    viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> capture(String name, Widget body) async {
      await tester.pumpWidget(app(body));
      await frames(tester, 25);
      expect(tester.takeException(), isNull, reason: name);
      await expectLater(find.byKey(const ValueKey('v38-capture')),
          matchesGoldenFile('goldens/$name-v38.png'));
      await tester.pumpWidget(const SizedBox());
    }

    SharedPreferences.setMockInitialValues({});
    await capture('welcome', const WorldScreen());
    seed();
    await capture('home', const WorldScreen());
    await capture('profile', const ChildProfileEditor(profile: child));
    await capture('garden', LetterJourney(onAlif: () {}));
    await capture(
        'free', const LessonScreen(lessonId: 'alif', initialScene: 5));
    await capture(
        'pronunciation', const LessonScreen(lessonId: 'alif', initialScene: 3));
    await capture(
        'assessment', const LessonScreen(lessonId: 'alif', initialScene: 6));
    for (final game in ReviewGame.values) {
      await capture('game-${game.name}', ReviewGameScreen(game: game));
    }
    await capture(
        'glow',
        CompletedTracingCanvas(
            letter: 'أَ',
            strokes: alifFathaVideoTemplate.strokes,
            traceTemplate: alifFathaVideoTemplate,
            glow: true));
    await capture(
        'achievements',
        AchievementsView(
            progress: const LessonProgress(lessonId: 'alif'),
            onPortfolio: () {}));
    await tester.runAsync(() => LearningJournal('legacy').saveDrawing(
        'alif',
        WritingSample(canvasSize: const Size(200, 100), strokes: const [
          [Offset(100, 10), Offset(100, 80)],
          [Offset(110, 2), Offset(95, 5), Offset(110, 8), Offset(95, 9)]
        ]),
        passed: true));
    await capture('portfolio', const PortfolioView());
  }, tags: ['visual']);
}

class _ClockAudio implements AudioService, AudioClock {
  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);
  @override
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  @override
  String? activeAsset;
  Completer<void>? _completion;
  @override
  Future<void> play(String assetPath) {
    activeAsset = assetPath;
    playing.value = true;
    position.value = Duration.zero;
    _completion = Completer<void>();
    return _completion!.future;
  }

  @override
  Future<void> stop() async {
    playing.value = false;
    if (_completion?.isCompleted == false) _completion!.complete();
  }

  @override
  Future<void> dispose() async {
    await stop();
    playing.dispose();
    position.dispose();
  }
}
