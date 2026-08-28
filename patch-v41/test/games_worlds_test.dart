import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/app/providers.dart';

import 'package:saleh_app/features/games/game_board.dart';
import 'package:saleh_app/features/games/game_catalog.dart';
import 'package:saleh_app/features/games/game_screen.dart';
import 'package:saleh_app/features/games/game_session.dart';
import 'package:saleh_app/features/games/game_store.dart';
import 'package:saleh_app/features/games/games_hub.dart';
import 'package:saleh_app/features/home/learning_journal.dart';
import 'package:saleh_app/services/audio/audio_service.dart';

GameSpec game(String id) => gameCatalog.firstWhere((e) => e.id == id);
Widget host(Widget child) => ProviderScope(
    overrides: [audioServiceProvider.overrideWithValue(SilentAudioService())],
    child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(fontFamily: 'Tajawal'),
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(844, 390), disableAnimations: true),
            child: child)));

void solve(GameSession s) {
  switch (s.game.kind) {
    case PlayKind.choose:
      s.choose(s.items.firstWhere((e) => e.id == s.data.answer.first));
    case PlayKind.collect:
      for (final id in s.data.answer) {
        s.choose(s.items.firstWhere((e) => e.id == id));
      }
    case PlayKind.order:
      for (final id in s.data.answer) {
        s.choose(s.items.firstWhere((e) => e.id == id));
      }
      s.checkOrder();
    case PlayKind.memory:
      for (final item in s.items.where((e) => e.id.startsWith('p'))) {
        s.choose(item);
        s.choose(s.items.firstWhere((e) => e.id == 't${item.id.substring(1)}'));
      }
    case PlayKind.counter:
      s.adjustCount(s.data.target - s.count);
      s.checkCount();
    case PlayKind.distribute:
      for (var i = 0; i < 3; i++) {
        for (var n = 0; n < s.data.b; n++) {
          s.distribute(i);
        }
      }
      s.checkDistribution();
    case PlayKind.value:
      s.adjustValue(true, s.data.target ~/ s.data.a);
      s.adjustValue(false, s.data.target % s.data.a);
      s.checkValue();
    case PlayKind.sort:
      for (final item in s.items) {
        s.sortInto(item, s.data.a == 1 ? item.tone : item.shape!);
      }
    case PlayKind.puzzle || PlayKind.mosaic:
      for (var i = 0; i < 4; i++) {
        s.putPiece(i, i);
      }
    case PlayKind.mirror:
      for (var i = 0; i < 6; i++) {
        if (s.data.grid[i] == 1) s.toggleMirror((i ~/ 2) * 2 + (1 - i % 2));
      }
      s.checkMirror();
    case PlayKind.maze:
      for (final cell in s.data.grid.skip(1)) {
        s.move(cell);
      }
    case PlayKind.pipes:
      for (var i = 0; i < 4; i++) {
        while (s.rotations[i] % 2 != 0) {
          s.rotate(i);
        }
      }
      s.checkPipes();
    case PlayKind.bridge:
      for (var i = 0; i < s.data.target; i++) {
        s.bridge(1);
      }
      s.checkCount();
    case PlayKind.robot:
      break;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test('catalog has 36 unique games, 12 per world and valid answer identities',
      () {
    expect(gameCatalog.map((e) => e.id).toSet().length, 36);
    for (final w in GameWorld.values) {
      expect(gameCatalog.where((e) => e.world == w).length, 12);
    }
    for (final g in gameCatalog) {
      for (var r = 0; r < 3; r++) {
        final d = roundFor(g, r);
        expect(d.prompt, isNotEmpty);
        expect(d.items.map((e) => e.id).toSet().length, d.items.length);
        for (final id in d.answer) {
          expect(d.items.any((e) => e.id == id), isTrue,
              reason: '${g.id} round $r: $id');
        }
      }
    }
  });
  for (final g in gameCatalog.where((e) => e.kind != PlayKind.robot)) {
    test('${g.id}: three solvable rounds and replay reset', () {
      final s = GameSession(g, random: Random(7));
      for (var r = 0; r < 3; r++) {
        expect(s.roundIndex, r);
        solve(s);
        expect(s.solved, isTrue, reason: '${g.id} round $r');
        if (r < 2) s.next();
      }
      expect(s.complete, isTrue);
      s.retry();
      expect(s.roundIndex, 0);
      expect(s.complete, isFalse);
      expect(s.selected, isEmpty);
      s.dispose();
    });
  }
  test('wrong choice cannot win and shuffling preserves correct identity', () {
    final s = GameSession(game('picture_word'), random: Random(4));
    final wrong = s.items.firstWhere((e) => !s.data.answer.contains(e.id));
    s.choose(wrong);
    expect(s.solved, isFalse);
    expect(s.mistakes, 1);
    s.choose(s.items.firstWhere((e) => s.data.answer.contains(e.id)));
    expect(s.solved, isTrue);
    s.dispose();
  });
  test('collect rejects repeat taps, order supports undo, no row-wrap maze',
      () {
    final s = GameSession(game('letter_basket'));
    final item = s.items.firstWhere((e) => s.data.answer.contains(e.id));
    s.choose(item);
    s.choose(item);
    expect(s.selected.length, 1);
    expect(s.solved, isFalse);
    s.dispose();
    final o = GameSession(game('build_word'));
    o.choose(o.items.first);
    o.undo();
    expect(o.selected, isEmpty);
    o.checkOrder();
    expect(o.solved, isFalse);
    o.dispose();
    expect(adjacent(3, 4, 4), isFalse);
    expect(robotStep(3, 0), -1);
  });
  test(
      'saved progress and awards are isolated and idempotent under concurrency',
      () async {
    final a = GameStore('a'), b = GameStore('b');
    await Future.wait([
      for (var i = 0; i < 4; i++)
        a.save('picture_word',
            nextRound: 0, mistakes: 1, hints: 0, complete: true),
      a.save('maze', nextRound: 1, mistakes: 0, hints: 1, complete: false)
    ]);
    expect((await LearningJournal('a').load()).points, 15);
    expect((await LearningJournal('b').load()).points, 0);
    expect((await a.load())['maze']['round'], 1);
    expect(await b.load(), isEmpty);
    await a.save('picture_word',
        nextRound: 1, mistakes: 0, hints: 0, complete: false);
    expect((await a.load())['picture_word']['completed'], isTrue);
  });
  testWidgets('memory mismatch pauses input, resets and disposes its timer',
      (tester) async {
    final s = GameSession(game('word_memory'));
    s.choose(s.items.firstWhere((e) => e.id == 'p0'));
    s.choose(s.items.firstWhere((e) => e.id == 't4'));
    expect(s.busy, isTrue);
    s.choose(s.items.firstWhere((e) => e.id == 'p7'));
    expect(s.selected.length, 2);
    await tester.pump(const Duration(milliseconds: 951));
    expect(s.busy, isFalse);
    expect(s.selected, isEmpty);
    s.choose(s.items.firstWhere((e) => e.id == 'p0'));
    s.choose(s.items.firstWhere((e) => e.id == 't4'));
    s.dispose();
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets(
      'robot runs real commands and rejects obstacles; pause cancels motion',
      (tester) async {
    final s = GameSession(game('robot'));
    s.addCommand(0);
    s.addCommand(0);
    s.addCommand(1);
    s.addCommand(1);
    s.runRobot();
    await tester.pump(const Duration(seconds: 3));
    expect(s.solved, isTrue);
    s.next();
    s.addCommand(2);
    s.runRobot();
    await tester.pump(const Duration(seconds: 1));
    expect(s.solved, isFalse);
    expect(s.busy, isFalse);
    s.resetRound();
    s.addCommand(1);
    s.runRobot();
    s.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(s.position, 0);
    s.dispose();
  });
  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets('all 36 boards fit ${size.width}x${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final g in gameCatalog) {
        final s = GameSession(g);
        await tester.pumpWidget(host(Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(12), child: GameBoard(s)))));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: g.id);
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      }
    });
  }
  testWidgets('all complete game screens fit small landscape', (tester) async {
    tester.view.physicalSize = const Size(568, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final g in gameCatalog) {
      await tester
          .pumpWidget(host(LearningGameScreen(key: ValueKey(g.id), game: g)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${g.id} intro');
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${g.id} game');
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('full screen starts, completes, saves, reopens and exits',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(host(LearningGameScreen(game: game('picture_word'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    for (var r = 0; r < 3; r++) {
      await tester.tap(find.byKey(ValueKey('item-w$r')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (r < 2) {
        await tester.tap(find.byKey(const ValueKey('next-game-round')));
        await tester.pumpAndSettle();
      }
    }
    expect((await LearningJournal('legacy').load()).points, 15);
    await tester.tap(find.byKey(const ValueKey('next-game-round')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-w0')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('world hub and representative boards visual review',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(const Scaffold(body: GamesHub())));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/games-worlds-hub.png'));
    for (final id in ['picture_word', 'build_word', 'feed_rabbit', 'robot']) {
      await tester.pumpWidget(
          host(LearningGameScreen(key: ValueKey(id), game: game(id))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: id);
      await expectLater(
          find.byType(Scaffold), matchesGoldenFile('goldens/games-$id.png'));
    }
    await tester.pumpWidget(const SizedBox());
  }, tags: ['visual']);
}
