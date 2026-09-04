import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';

import 'v38_test.dart' as support;

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

  // Pixel baselines were captured on Windows. Keep them in the existing
  // opt-in visual suite; layout assertions still run on every build host.
  for (final compareGolden in [false, true]) {
    final suffix = compareGolden ? ' (Windows pixel baseline)' : '';
    testWidgets('foundation tracks fit the compact landscape phone$suffix',
        (tester) async {
      support.viewport(tester, const Size(844, 390));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(support.app(const WorldScreen()));
      await support.frames(tester, 14);
      await tester.tap(find.text('تأسيس اللغة العربية'));
      await support.frames(tester, 8);
      expect(tester.takeException(), isNull);
      const screen = Rect.fromLTWH(0, 0, 844, 390);
      for (final id in ['read-write', 'reading', 'writing']) {
        final card = tester.getRect(find.byKey(ValueKey('track-$id')));
        final icon = tester.getRect(find.byKey(ValueKey('track-icon-$id')));
        expect(screen.contains(card.topLeft), isTrue);
        expect(screen.contains(card.bottomRight), isTrue);
        expect(card.contains(icon.center), isTrue);
        expect(icon.size, const Size(48, 48));
      }
      if (compareGolden) {
        await expectLater(
          find.byKey(const ValueKey('v38-capture')),
          matchesGoldenFile('goldens/v58_foundation_tracks_844x390.png'),
        );
      }
    }, tags: compareGolden ? ['visual'] : null);

    testWidgets(
        'dal-through-seen start points sit on their approved paths$suffix',
        (tester) async {
      support.viewport(tester, const Size(1280, 390));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final templates = [
        ('دَ', dalFathaTemplate),
        ('ذَ', dhalFathaTemplate),
        ('رَ', raaFathaTemplate),
        ('زَ', zayFathaTemplate),
        ('سَ', seenFathaTemplate),
      ];
      await tester.pumpWidget(support.app(ColoredBox(
        color: const Color(0xFFF7F3EA),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              for (final entry in templates)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF238D89)),
                      ),
                      child: GuidedTracingCanvas(
                        letter: entry.$1,
                        strokes: entry.$2.strokes,
                        traceTemplate: entry.$2,
                        onStrokeCompleted: (_) {},
                        onAllCompleted: () {},
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final canvases = find.byType(GuidedTracingCanvas);
      expect(canvases, findsNWidgets(5));
      const screen = Rect.fromLTWH(0, 0, 1280, 390);
      final firstSize = tester.getSize(canvases.first);
      for (var i = 0; i < 5; i++) {
        final rect = tester.getRect(canvases.at(i));
        expect(screen.contains(rect.topLeft), isTrue);
        expect(screen.contains(rect.bottomRight), isTrue);
        expect(rect.width, closeTo(firstSize.width, .01));
        expect(rect.height, closeTo(firstSize.height, .01));
      }
      if (compareGolden) {
        await expectLater(
          find.byKey(const ValueKey('v38-capture')),
          matchesGoldenFile('goldens/v58_guides_dal_to_seen_1280x390.png'),
        );
      }
    }, tags: compareGolden ? ['visual'] : null);
  }
}
