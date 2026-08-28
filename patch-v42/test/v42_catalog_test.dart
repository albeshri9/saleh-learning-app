import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/core/design/widgets/toy_icon.dart';
import 'package:saleh_app/features/home/lessons_catalog.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'v38_test.dart' as support;

void main() {
  setUp(support.seed);
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('stages use small artwork and fatha restores compact RTL nodes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      await tester.pumpWidget(support.app(LessonsCatalog(onLesson: (_) {})));
      await support.frames(tester);
      expect(find.byType(LetterGlyph), findsNothing);
      expect(find.byType(ToyIcon), findsWidgets);
      final stage = tester
          .getRect(find.byKey(const ValueKey('stage-card-letters_fatha')));
      expect(stage.width, lessThanOrEqualTo(158));
      expect(stage.height, lessThanOrEqualTo(184));
      await tester.tap(find.text('الحروف بحركة الفتح'));
      await support.frames(tester);
      final cards = [
        for (final id in ['alif', 'baa', 'taa'])
          tester.getRect(find.byKey(ValueKey('lesson-card-$id')))
      ];
      expect(cards[0].center.dx, greaterThan(cards[1].center.dx));
      expect(cards[1].center.dx, greaterThan(cards[2].center.dx));
      for (final rect in cards) {
        expect(rect.width, lessThanOrEqualTo(136));
        expect(rect.height, lessThanOrEqualTo(154));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
      }
      for (final glyph in find.byType(LetterGlyph).evaluate()) {
        expect((glyph.renderObject as RenderBox).size.width,
            lessThanOrEqualTo(62));
        expect((glyph.renderObject as RenderBox).size.height,
            lessThanOrEqualTo(45));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('v42 actual world catalog visual review on both phone sizes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      await tester.pumpWidget(support.app(const WorldScreen()));
      await support.frames(tester, 20);
      await tester.tap(find.text('دروسي'));
      await support.frames(tester, 20);
      await tester.runAsync(() async {
        final context = tester.element(find.byType(LessonsCatalog));
        await precacheImage(
            const AssetImage('assets/ui/icons_v38.png'), context);
        await precacheImage(
            const AssetImage('assets/backgrounds/garden_v36.png'), context);
      });
      await support.frames(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('v38-capture')),
          matchesGoldenFile('goldens/v42-stages-${size.width.toInt()}.png'));
      await tester.tap(find.text('الحروف بحركة الفتح'));
      await support.frames(tester);
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('v38-capture')),
          matchesGoldenFile('goldens/v42-letters-${size.width.toInt()}.png'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  }, tags: ['visual']);
}
