import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/features/home/profile_editor.dart';
import 'package:saleh_app/features/home/world_screen.dart';

Widget app(Widget child) => ProviderScope(
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
          key: const ValueKey('capture'), child: Scaffold(body: child)),
    ));

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Tajawal')
          ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('age is required and profession avatars replace emoji',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const ChildProfileEditor()));
    await frames(tester);
    expect(
        tester
            .widget<JourneyButton>(find.byKey(const ValueKey('save-profile')))
            .onTap,
        isNull);
    expect(find.byType(CareerAvatar), findsNWidgets(12));
    await tester.enterText(find.byKey(const ValueKey('child-name')), 'سارة');
    await tester.pump();
    expect(
        tester
            .widget<JourneyButton>(find.byKey(const ValueKey('save-profile')))
            .onTap,
        isNull);
    await tester.tap(find.byKey(const ValueKey('child-age')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 سنوات').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<JourneyButton>(find.byKey(const ValueKey('save-profile')))
            .onTap,
        isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'parent question stays visible after wrong answer and outside tap',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const StableParentGate()),
            child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final question = tester
        .widget<Text>(find.byKey(const ValueKey('parent-question')))
        .data!;
    await tester.tap(find.byKey(const ValueKey('digit-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text(question), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(StableParentGate), findsOneWidget);
    const words = [
      'صفر',
      'واحد',
      'اثنان',
      'ثلاثة',
      'أربعة',
      'خمسة',
      'ستة',
      'سبعة',
      'ثمانية',
      'تسعة'
    ];
    final digits =
        question.split(' — ').map((w) => words.indexOf(w).toString());
    for (final digit in digits) {
      await tester.tap(find.byKey(ValueKey('digit-$digit')));
      await tester.pumpAndSettle();
      expect(find.text(question), findsOneWidget);
    }
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.byType(StableParentGate), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing profile preserves identity and progress namespace',
      (tester) async {
    const old = ChildProfile(
        id: 'existing-child',
        name: 'محمد',
        gender: ChildGender.male,
        age: 6,
        avatar: 'career_2');
    ChildProfile? result;
    await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<ChildProfile>(
                  context: context,
                  builder: (_) => const ChildProfileEditor(profile: old));
            },
            child: const Text('edit')))));
    await tester.tap(find.text('edit'));
    await frames(tester);
    await tester.enterText(find.byKey(const ValueKey('child-name')), 'صالح');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pumpAndSettle();
    expect(result!.id, old.id);
    expect(result!.name, 'صالح');
    expect(result!.age, 6);
  });

  testWidgets('v37 onboarding, editor, home and parent visual review',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const WorldScreen()));
    await frames(tester);
    await expectLater(find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/welcome-v37.png'));
    await tester.tap(find.text('لنبدأ'));
    await frames(tester);
    await expectLater(find.byType(ChildProfileEditor),
        matchesGoldenFile('goldens/profile-v37.png'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    SharedPreferences.setMockInitialValues({
      'child_profile': jsonEncode(const ChildProfile(
              name: 'عبدالله', gender: ChildGender.male, avatar: 'career_1')
          .toJson())
    });
    await tester.pumpWidget(app(const WorldScreen()));
    await frames(tester);
    await expectLater(find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/home-v37.png'));
    await tester.tap(find.text('للأهل'));
    await frames(tester);
    await expectLater(find.byType(StableParentGate),
        matchesGoldenFile('goldens/parent-v37.png'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, tags: ['visual']);
}
