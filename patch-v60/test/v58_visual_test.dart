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

  testWidgets('foundation tracks fit the compact landscape phone',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(support.app(const WorldScreen()));
    await support.frames(tester, 14);
    await tester.tap(find.text('تأسيس اللغة العربية'));
    await support.frames(tester, 8);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('v38-capture')),
      matchesGoldenFile('goldens/v58_foundation_tracks_844x390.png'),
    );
  });

  testWidgets('dal-through-seen start points sit on their approved paths',
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
    await expectLater(
      find.byKey(const ValueKey('v38-capture')),
      matchesGoldenFile('goldens/v58_guides_dal_to_seen_1280x390.png'),
    );
  });
}
