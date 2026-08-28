import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/features/games/game_screen.dart';
import 'package:saleh_app/features/games/game_catalog.dart';
import 'games_worlds_test.dart' as fixtures;

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
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: g.id);
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/gallery-${g.id}.png'));
    }
    await tester.pumpWidget(const SizedBox());
  }, tags: ['visual']);
}
