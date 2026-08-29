import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/features/games/first_phase_scene.dart';
import 'package:saleh_app/features/games/game_art.dart';
import 'package:saleh_app/features/games/game_catalog.dart';
import 'package:saleh_app/features/games/game_screen.dart';
import 'package:saleh_app/features/games/game_store.dart';
import 'package:saleh_app/features/home/learning_journal.dart';
import 'games_worlds_test.dart' as fixtures;

class LifecycleEffects extends fixtures.RecordingGameEffects {
  int stops = 0;
  bool disposed = false;
  @override
  void stop() => stops++;
  @override
  void dispose() => disposed = true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void landscape(WidgetTester tester) {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('first-phase letter faces stay contained in their tiles',
      (tester) async {
    for (final letter in ['أ', 'أَ', 'ب', 'بَ', 'ت', 'تَ']) {
      await tester.pumpWidget(fixtures.host(Center(
          child: SizedBox(
              width: 46,
              height: 46,
              child: ItemFace(GameItem('letter', text: letter))))));
      expect(find.text(letter), findsOneWidget);
      expect(tester.takeException(), isNull, reason: letter);
      final rect = tester.getRect(find.text(letter));
      expect(rect.width, lessThanOrEqualTo(46));
      expect(rect.height, lessThanOrEqualTo(46));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('memory resumes fourth round and awards only after ten cards',
      (tester) async {
    landscape(tester);
    final store = GameStore('legacy');
    await store.save('word_memory',
        nextRound: 3, mistakes: 2, hints: 1, complete: false);
    await tester.pumpWidget(
        fixtures.host(LearningGameScreen(game: fixtures.game('word_memory'))));
    await tester.pumpAndSettle();
    expect(find.text('نكمل اللعب'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    for (final i in [0, 2, 4, 7, 9]) {
      expect(find.byKey(ValueKey('item-p$i')), findsOneWidget);
      expect(find.byKey(ValueKey('item-t$i')), findsOneWidget);
    }
    for (final i in [0, 2, 4, 7]) {
      await tester.tap(find.byKey(ValueKey('item-p$i')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(ValueKey('item-t$i')));
      await tester.pumpAndSettle();
    }
    expect((await LearningJournal('legacy').load()).points, 0);
    expect(find.byKey(const ValueKey('next-game-round')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('item-p9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item-t9')));
    await tester.pumpAndSettle();
    expect((await store.load())['word_memory']['completed'], isTrue);
    expect((await LearningJournal('legacy').load()).points, 15);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('old completed memory stays awarded and reopens at round one',
      (tester) async {
    landscape(tester);
    final store = GameStore('legacy');
    await store.save('word_memory',
        nextRound: 0, mistakes: 1, hints: 0, complete: true);
    final before =
        (await SharedPreferences.getInstance()).getString('games_v1_legacy');
    await tester.pumpWidget(
        fixtures.host(LearningGameScreen(game: fixtures.game('word_memory'))));
    await tester.pumpAndSettle();
    expect(find.text('هيا نبدأ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-p0')), findsOneWidget);
    expect(find.byKey(const ValueKey('item-p2')), findsOneWidget);
    expect(find.byKey(const ValueKey('item-p4')), findsNothing);
    expect((await LearningJournal('legacy').load()).points, 15);
    expect((await SharedPreferences.getInstance()).getString('games_v1_legacy'),
        before);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('game effects stop on backgrounding and dispose on exit',
      (tester) async {
    landscape(tester);
    final effects = LifecycleEffects();
    await tester.pumpWidget(fixtures.host(
        LearningGameScreen(game: fixtures.game('letter_basket')),
        effects: effects));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('item-w0')));
    await tester.pumpAndSettle();
    expect(effects.answers, [true]);
    final stopsBefore = effects.stops;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(effects.stops, greaterThan(stopsBefore));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(effects.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('first-phase catalog exposes exactly five games per world', () {
    for (final world in GameWorld.values) {
      final games = gameCatalog
          .where((game) =>
              game.world == world && firstPhaseGameIds.contains(game.id))
          .toList();
      expect(games, hasLength(5));
      expect(games.every((game) => game.isFirstPhase), isTrue);
    }
  });
}
