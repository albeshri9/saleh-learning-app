import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/features/games/game_screen.dart';
import 'package:saleh_app/features/games/game_catalog.dart';
import 'games_worlds_test.dart' as fixtures;
import 'package:saleh_app/features/games/game_store.dart';
import 'package:saleh_app/features/games/games_hub.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets('capture all 36 actual game screens for visual review',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    for (final g in gameCatalog) {
      await tester.pumpWidget(
          fixtures.host(LearningGameScreen(key: ValueKey(g.id), game: g)));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold));
        for (final path in [
          'assets/games/objects.png',
          'assets/games/worlds.png',
          'assets/character/saleh_idle.png'
        ]) {
          await precacheImage(AssetImage(path), context);
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: g.id);
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/gallery-${g.id}.png'));
    }
    await tester.pumpWidget(fixtures.host(LearningGameScreen(
        key: const ValueKey('feedback'),
        game: fixtures.game('letter_basket'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    for (final id in ['w0', 'w2']) {
      await tester.tap(find.byKey(ValueKey('item-$id')));
      await tester.pumpAndSettle();
    }
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('goldens/r2-feedback.png'));
    await tester.tap(find.byKey(const ValueKey('item-w1')));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('goldens/r2-success.png'));
    await GameStore('legacy').save('word_memory',
        nextRound: 3, mistakes: 0, hints: 0, complete: false);
    await tester.pumpWidget(fixtures.host(LearningGameScreen(
        key: const ValueKey('memory-ten'),
        game: fixtures.game('word_memory'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('goldens/r2-memory-ten.png'));
    await tester.pumpWidget(
        fixtures.host(const GamesWorldScreen(world: GameWorld.numbers)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/r2-numbers-menu.png'));
    await tester.pumpWidget(const SizedBox());
  }, tags: ['visual']);
}
