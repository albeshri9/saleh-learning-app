import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/home/profile_editor.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/lesson/foundation_track.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';

import 'v38_test.dart' as support;

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(support.seed);

  test('the three foundation tracks expose only their approved lesson scenes',
      () {
    final lesson = Lesson.fromJson(json('assets/content/lesson_khaa.json'));
    final readWrite = lessonSceneIndicesForTrack(
      lesson,
      FoundationTrack.readWrite,
    ).map((index) => lesson.scenes[index].type);
    final reading = lessonSceneIndicesForTrack(
      lesson,
      FoundationTrack.reading,
    ).map((index) => lesson.scenes[index].type);
    final writing = lessonSceneIndicesForTrack(
      lesson,
      FoundationTrack.writing,
    ).map((index) => lesson.scenes[index].type);

    expect(readWrite, contains(SceneType.guidedWriting));
    expect(readWrite, contains(SceneType.freeWriting));
    expect(reading, isNot(contains(SceneType.guidedWriting)));
    expect(reading, isNot(contains(SceneType.freeWriting)));
    expect(writing.toSet(), {
      SceneType.guidedWriting,
      SceneType.freeWriting,
      SceneType.success,
    });
  });

  test('checkpoint tasks follow the same selected track without writing skip',
      () {
    final checkpoint = json('assets/content/lesson_checkpoint_group_1.json');
    final data = ((checkpoint['scenes'] as List).first
        as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final readWrite = checkpointTaskFlow(data,
        random: Random(51), foundationTrack: FoundationTrack.readWrite);
    final reading = checkpointTaskFlow(data,
        random: Random(51), foundationTrack: FoundationTrack.reading);
    final writing = checkpointTaskFlow(data,
        random: Random(51), foundationTrack: FoundationTrack.writing);

    expect(readWrite.where((task) => task['type'] == 'guided'), isEmpty);
    expect(readWrite.where((task) => task['type'] == 'free'), hasLength(7));
    expect(reading.any((task) => task['type'] == 'guided'), false);
    expect(reading.any((task) => task['type'] == 'free'), false);
    expect(writing, hasLength(7));
    expect(writing.every((task) => task['type'] == 'free'), true);
  });

  test('all new checkpoint narration is present and non-empty', () {
    final checkpoint = json('assets/content/lesson_checkpoint_group_1.json');
    final data = ((checkpoint['scenes'] as List).first
        as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final files = <String>[
      data['dragMatchPromptAudio'] as String,
      data['wrongAudio'] as String,
      for (final item in (data['successFeedbacks'] as List).cast<Map>())
        item['audio'] as String,
      ((((checkpoint['scenes'] as List)[1] as Map)['lines'] as List).first
          as Map)['audio'] as String,
    ];
    // Prompt + wrong answer + seven approved praise clips + closing.
    expect(files.toSet(), hasLength(10));
    for (final path in files) {
      expect(File(path).lengthSync(), greaterThan(1000), reason: path);
    }
  });

  testWidgets('foundation opens three professional track cards',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(support.app(const WorldScreen()));
    await support.frames(tester, 14);
    await tester.tap(find.text('تأسيس اللغة العربية'));
    await support.frames(tester, 8);
    expect(find.byKey(const ValueKey('track-read-write')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-reading')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-writing')), findsOneWidget);
    expect(find.text('تأسيس في القراءة والكتابة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected writing track is carried to the opened lesson',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const WorldScreen()),
      GoRoute(
          path: '/lesson/:id',
          builder: (_, state) => Scaffold(body: Text('${state.uri}'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ));
    await support.frames(tester, 14);
    await tester.tap(find.text('تأسيس اللغة العربية'));
    await support.frames(tester, 6);
    await tester.tap(find.byKey(const ValueKey('track-writing')));
    await support.frames(tester, 6);
    await tester.tap(find.text('الحروف بحركة الفتح'));
    await support.frames(tester, 6);
    await tester.tap(find.byKey(const ValueKey('lesson-card-alif')));
    await support.frames(tester, 6);
    expect(find.text('/lesson/alif?mode=writing'), findsOneWidget);
    router.dispose();
  });

  testWidgets('age selector dismisses name focus on its first tap',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(support.app(const ChildProfileEditor()));
    await tester.tap(find.byKey(const ValueKey('child-name')));
    await tester.enterText(find.byKey(const ValueKey('child-name')), 'صالح');
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.tap(find.byKey(const ValueKey('child-age')));
    await tester.pumpAndSettle();
    final nameEditor = tester.widget<EditableText>(find.descendant(
      of: find.byKey(const ValueKey('child-name')),
      matching: find.byType(EditableText),
    ));
    expect(nameEditor.focusNode.hasFocus, false);
    expect(find.text('3 سنوات'), findsWidgets);
  });
}
