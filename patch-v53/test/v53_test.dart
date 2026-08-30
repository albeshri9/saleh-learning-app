import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/design/widgets/classroom_background.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: RepaintBoundary(
          key: const ValueKey('v53-capture'),
          child: Scaffold(body: child),
        ),
      ),
    );

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('v53 background switcher always fills the whole viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 590);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const ClassroomBackground(
      asset: 'assets/backgrounds/courtyard_v38.png',
      child: SizedBox.expand(),
    )));
    await tester.pump();

    final switcher = find.byKey(
      const ValueKey('full-screen-background-switcher'),
    );
    expect(tester.getSize(switcher), const Size(1280, 590));
    final layoutStack = tester.widgetList<Stack>(
      find.descendant(of: switcher, matching: find.byType(Stack)),
    );
    expect(layoutStack.any((stack) => stack.fit == StackFit.expand), true);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1280, 590), const Size(568, 320)]) {
    testWidgets('v53 welcome is balanced without overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(const WorldScreen()));
      await _frames(tester);
      expect(find.text('نقرأ'), findsOneWidget);
      expect(find.text('نكتب'), findsOneWidget);
      expect(find.text('نلعب'), findsOneWidget);
      expect(find.text('لنبدأ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (size == const Size(1280, 590)) {
        await expectLater(
          find.byKey(const ValueKey('v53-capture')),
          matchesGoldenFile('goldens/welcome-v53.png'),
        );
      }
    });
  }
}
