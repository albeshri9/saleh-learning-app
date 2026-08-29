import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saleh_app/data/local/local_progress_repository.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/features/home/family_store.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/lesson/character/saleh_character_controller.dart';
import 'package:saleh_app/features/lesson/widgets/saleh_character.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/lesson_controller.dart';
import 'package:saleh_app/features/character/video/saleh_video_renderer.dart';
import 'package:saleh_app/services/audio/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final arabic = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await arabic.load();
  });
  const child = ChildProfile(name: 'عبدالله', gender: ChildGender.male);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'legacy profile and progress survive migration; new children are isolated',
      () async {
    SharedPreferences.setMockInitialValues({
      'child_profile': jsonEncode(child.toJson()),
      'lesson_progress_alif': jsonEncode(
          const LessonProgress(lessonId: 'alif', lastSceneIndex: 4).toJson()),
    });
    final store = FamilyStore();
    expect((await store.load()).single.id, 'legacy');
    final legacy = LocalProgressRepository();
    final other = LocalProgressRepository(profileId: 'second');
    expect((await legacy.loadLessonProgress('alif'))!.lastSceneIndex, 4);
    expect(await other.loadLessonProgress('alif'), isNull);
    await other.saveLessonProgress(
        const LessonProgress(lessonId: 'alif', lastSceneIndex: 2));
    expect((await legacy.loadLessonProgress('alif'))!.lastSceneIndex, 4);
    expect((await other.loadLessonProgress('alif'))!.lastSceneIndex, 2);
  });

  test('gesture releases into speech and reset clears text narration', () {
    final audio = ValueNotifier(true);
    final c = SalehCharacterController(audioPlaying: audio);
    c.beginGesture(SalehPose.waving);
    expect(c.pose, SalehPose.waving);
    c.endGesture();
    expect(c.pose, SalehPose.talking);
    c.beginGesture(SalehPose.encouraging);
    expect(c.pose, SalehPose.encouraging);
    c.endGesture();
    expect(c.pose, SalehPose.talking);
    audio.value = false;
    c.setNarrating(true);
    c.reset();
    expect(c.pose, SalehPose.idle);
    c.dispose();
    audio.dispose();
  });

  test('actual Talking asset decodes multiple distinct frames', () async {
    final data = await rootBundle
        .load('assets/character/saleh_video/saleh_talking_speech_alpha.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    expect(codec.frameCount, greaterThan(40));
    final first = await codec.getNextFrame();
    final a = (await first.image.toByteData())!.buffer.asUint8List();
    first.image.dispose();
    ui.FrameInfo? later;
    for (var i = 0; i < 20; i++) {
      later?.image.dispose();
      later = await codec.getNextFrame();
    }
    final b = (await later!.image.toByteData())!.buffer.asUint8List();
    expect(a, isNot(orderedEquals(b)));
    expect(later.duration.inMilliseconds, greaterThan(0));
    later.image.dispose();
    codec.dispose();
  });

  test('review never jumps ahead of learned content', () {
    expect(reviewScene(null, child), 0);
    expect(
        reviewScene(
            const LessonProgress(lessonId: 'alif', lastSceneIndex: 3), child),
        2);
    expect(
        reviewScene(
            const LessonProgress(lessonId: 'alif', lastSceneIndex: 5), child),
        4);
  });

  testWidgets('home and garden fit small landscape and show real progress',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'child_profile': jsonEncode(child.toJson())});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await font.load();
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
      locale: Locale('ar'),
      supportedLocales: [Locale('ar')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: RepaintBoundary(key: ValueKey('world'), child: WorldScreen()),
    )));
    await _frames(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('تعلم مع صالح'), findsOneWidget);
    await tester.tap(find.text('تأسيس اللغة العربية'));
    await _frames(tester);
    expect(find.byKey(const ValueKey('track-read-write')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-reading')), findsOneWidget);
    expect(find.byKey(const ValueKey('track-writing')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('track-read-write')));
    await _frames(tester);
    expect(find.text('تأسيس اللغة العربية'), findsOneWidget);
    expect(find.text('الحروف بحركة الفتح'), findsOneWidget);
    expect(find.text('قريبًا'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lesson gestures release into actual talking renderer',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'child_profile': jsonEncode(child.toJson())});
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = _HeldAudio();
    final container = ProviderContainer(
        overrides: [audioServiceProvider.overrideWithValue(audio)]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Tajawal'),
          home: const RepaintBoundary(
              key: ValueKey('lesson-preview'),
              child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: LessonScreen(lessonId: 'alif', initialScene: 2))),
        )));
    await _frames(tester);
    expect(
        tester.widget<SalehVideoRenderer>(find.byType(SalehVideoRenderer)).pose,
        SalehPose.talking);
    expect(tester.takeException(), isNull);
    container.read(lessonControllerProvider('alif').notifier).jumpToScene(3);
    await _frames(tester);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('SALEH_CAPTURE')) {
      await expectLater(find.byKey(const ValueKey('lesson-preview')),
          matchesGoldenFile('goldens/lesson-v36.png'));
    }
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await audio.dispose();
  });

  testWidgets('world screenshot', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'child_profile': jsonEncode(child.toJson())});
    tester.view.physicalSize = const Size(1024, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await font.load();
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      theme: ThemeData(fontFamily: 'Tajawal'),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: const RepaintBoundary(key: ValueKey('world'), child: WorldScreen()),
    )));
    await _frames(tester);
    await expectLater(find.byKey(const ValueKey('world')),
        matchesGoldenFile('goldens/world-v36.png'));
    await tester.tap(find.text('تأسيس اللغة العربية'));
    await _frames(tester);
    await expectLater(find.byKey(const ValueKey('world')),
        matchesGoldenFile('goldens/garden-v36.png'));
    await tester.pumpWidget(const SizedBox());
  }, tags: ['visual']);
}

Future<void> _frames(WidgetTester tester) async {
  // Saleh breathes continuously, so this screen never "settles".
  for (var i = 0; i < 30; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _HeldAudio implements AudioService {
  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);
  Completer<void>? _pending;
  @override
  Future<void> play(String path) async {
    await stop();
    playing.value = true;
    _pending = Completer<void>();
    await _pending!.future;
  }

  @override
  Future<void> stop() async {
    playing.value = false;
    final old = _pending;
    _pending = null;
    if (old != null && !old.isCompleted) old.complete();
  }

  @override
  Future<void> dispose() async {
    await stop();
    playing.dispose();
  }
}
