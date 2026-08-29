import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/core/design/app_theme.dart';
import 'package:saleh_app/core/design/app_viewport.dart';
import 'package:saleh_app/features/home/profile_editor.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/home/learner_chooser.dart';
import 'package:saleh_app/features/home/parent_dashboard.dart';
import 'package:saleh_app/features/home/learning_destinations.dart';
import 'package:saleh_app/features/home/lessons_catalog.dart';
import 'package:saleh_app/features/games/games_hub.dart';
import 'package:saleh_app/features/games/game_catalog.dart';
import 'package:saleh_app/features/games/game_screen.dart';
import 'package:saleh_app/features/games/game_effects.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'v38_test.dart' as support;
import 'v44_test.dart' as lessons;
import 'games_worlds_test.dart' as games;

Widget auditApp(Widget child, {double scale = 1.3, bool ios = false}) =>
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(SilentAudioService()),
        gameEffectsFactoryProvider
            .overrideWithValue(() => games.RecordingGameEffects())
      ],
      child: MaterialApp(
        theme: AppTheme.light().copyWith(
            platform: ios ? TargetPlatform.iOS : TargetPlatform.android),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: ios
                ? const EdgeInsets.fromLTRB(44, 0, 44, 21)
                : const EdgeInsets.only(top: 24, right: 40),
            viewPadding: ios
                ? const EdgeInsets.fromLTRB(44, 0, 44, 21)
                : const EdgeInsets.only(top: 24, right: 40),
            disableAnimations: true,
          ),
          child: AppViewport(child: child!),
        ),
        home: RepaintBoundary(
          key: const ValueKey('audit-capture'),
          child: Scaffold(body: child),
        ),
      ),
    );

Widget page(Widget child) => SafeArea(
    child:
        Column(children: [const SizedBox(height: 54), Expanded(child: child)]));

Future<void> layoutFrames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(support.seed);
  setUpAll(() async {
    final font = FontLoader('Tajawal');
    for (final weight in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      font.addFont(rootBundle.load('assets/fonts/Tajawal-$weight.ttf'));
    }
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  final children = [
    support.child,
    const ChildProfile(
        id: 'two',
        name: 'عبدالرحمن',
        age: 3,
        gender: ChildGender.male,
        avatar: 'career_1')
  ];
  final screens = <String, Widget>{
    'home': const WorldScreen(),
    'gate': const SafeArea(child: StableParentGate()),
    'profile':
        const SafeArea(child: ChildProfileEditor(profile: support.child)),
    'parents': page(ParentDashboard(
        child: support.child,
        children: children,
        progress: null,
        onSelect: (_) {},
        onAdd: () {},
        onEdit: () {})),
    'chooser':
        SafeArea(child: LearnerChooser(children: children, onSelect: (_) {})),
    'achievements': page(AchievementsView(progress: null, onPortfolio: () {})),
    'portfolio': page(const PortfolioView()),
    'curriculum': page(LessonsCatalog(onLesson: (_) {})),
    'games': page(const GamesHub()),
  };
  for (final size in [
    const Size(568, 320),
    const Size(800, 360),
    const Size(960, 600),
    const Size(1280, 800)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('screens fit ${size.width}x${size.height} scale $scale',
          (tester) async {
        support.viewport(tester, size);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final entry in screens.entries) {
          await tester.pumpWidget(auditApp(entry.value, scale: scale));
          await layoutFrames(tester, 8);
          expect(tester.takeException(), isNull, reason: entry.key);
          if (entry.key == 'gate') {
            final keypad =
                tester.getRect(find.byKey(const ValueKey('parent-keypad')));
            for (final digit in [
              '1',
              '2',
              '3',
              '4',
              '5',
              '6',
              '7',
              '8',
              '9',
              '0',
              'مسح',
              '⌫'
            ]) {
              final rect = tester.getRect(find.byKey(ValueKey('digit-$digit')));
              expect(rect.height, greaterThanOrEqualTo(44), reason: digit);
              expect(rect.width, greaterThanOrEqualTo(44), reason: digit);
              expect(keypad.inflate(.1).contains(rect.bottomRight), isTrue,
                  reason: digit);
              expect(find.byKey(ValueKey('digit-$digit')).hitTestable(),
                  findsOneWidget);
            }
          }
          if (['home', 'profile', 'achievements', 'parents']
              .contains(entry.key)) {
            for (final state
                in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
              if (axisDirectionToAxis(state.position.axisDirection) ==
                  Axis.vertical) {
                expect(state.position.maxScrollExtent, 0,
                    reason:
                        '${entry.key} should fit without vertical scrolling');
              }
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
  for (final size in [const Size(568, 320), const Size(800, 360)]) {
    testWidgets('welcome fits $size without hidden start button',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      support.viewport(tester, size);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(auditApp(const WorldScreen(), scale: 2));
      await layoutFrames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('لنبدأ').hitTestable(), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
    for (final id in ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa']) {
      testWidgets('all $id lesson scenes fit $size with large system font',
          (tester) async {
        support.viewport(tester, size);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (var i = 0; i < lessons.lesson(id).scenes.length; i++) {
          await tester.pumpWidget(
              auditApp(LessonScreen(lessonId: id, initialScene: i), scale: 2));
          await layoutFrames(tester, 12);
          expect(tester.takeException(), isNull, reason: '$id scene $i');
          expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
        }
      });
    }
  }
  testWidgets('completed home card fits and remains tappable on small Android',
      (tester) async {
    support.seed(const LessonProgress(lessonId: 'alif', completed: true));
    support.viewport(tester, const Size(568, 320));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(auditApp(const WorldScreen(), scale: 2));
    await layoutFrames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('نبدأ رحلة الألف من جديد').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('home-lesson-complete')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('iPhone safe-area and theme regression', (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in screens.entries) {
      await tester.pumpWidget(auditApp(entry.value, scale: 1, ios: true));
      await layoutFrames(tester, 8);
      expect(tester.takeException(), isNull, reason: entry.key);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('v47 visual audit with real app typography', (tester) async {
    support.viewport(tester, const Size(800, 360));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final entry in {
      ...screens,
      'gate': SafeArea(child: StableParentGate(random: Random(47))),
      'lesson': const LessonScreen(lessonId: 'jeem', initialScene: 3),
    }.entries) {
      await tester.pumpWidget(auditApp(entry.value));
      await layoutFrames(tester);
      await expectLater(find.byKey(const ValueKey('audit-capture')),
          matchesGoldenFile('goldens/v47-${entry.key}.png'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }
  }, tags: ['visual']);
  testWidgets('v47 all game boards visual audit', (tester) async {
    support.viewport(tester, const Size(800, 360));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final game in gameCatalog) {
      await tester.pumpWidget(auditApp(LearningGameScreen(
          key: ValueKey(game.id),
          game: game,
          random: Random(game.id.hashCode))));
      await layoutFrames(tester, 6);
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await layoutFrames(tester, 6);
      expect(tester.takeException(), isNull, reason: game.id);
      await expectLater(find.byKey(const ValueKey('audit-capture')),
          matchesGoldenFile('goldens/v47-game-${game.id}.png'));
      await tester.pumpWidget(const SizedBox());
    }
  }, tags: ['visual']);
}
