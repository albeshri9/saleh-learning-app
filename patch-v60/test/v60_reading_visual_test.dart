// Visual audit only: pending reading content is injected through a repository
// override, never registered in active lesson packs or asset manifests.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/core/design/app_theme.dart';
import 'package:saleh_app/core/design/app_viewport.dart';
import 'package:saleh_app/core/design/widgets/app_button.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/curriculum.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/models/progress.dart';
import 'package:saleh_app/domain/repositories/content_repository.dart';
import 'package:saleh_app/domain/repositories/progress_repository.dart';
import 'package:saleh_app/features/home/learning_journal.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/scenes/reading_assessment_scene.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'package:saleh_app/services/speech/speech_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _VisualContent implements ContentRepository {
  _VisualContent(this.lesson);
  final Lesson lesson;

  @override
  Future<Lesson> loadLesson(String lessonId) async => lesson;

  @override
  Future<List<Program>> loadPrograms() async => [];
}

class _VisualProgress implements ProgressRepository {
  @override
  Future<ChildProfile?> loadProfile() async => const ChildProfile(
      name: 'عبدالله',
      id: 'v60-visual-only',
      gender: ChildGender.male,
      avatar: 'career_1',
      age: 5);

  @override
  Future<LessonProgress?> loadLessonProgress(String lessonId) async => null;

  @override
  Future<void> saveLessonProgress(LessonProgress progress) async {}

  @override
  Future<void> saveProfile(ChildProfile profile) async {}
}

class _VisualJournal extends LearningJournal {
  _VisualJournal() : super('v60-visual-only');

  @override
  Future<void> award(String id, int points) async {}
}

class _VisualSpeech implements SpeechService {
  bool wrongNext = false;

  @override
  Future<SpeechResult> listenFor(String expected) async {
    final wrong = wrongNext;
    wrongNext = false;
    return SpeechResult(
        correct: !wrong, recognizedWords: wrong ? 'غير مطابق' : expected);
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _frames(WidgetTester tester, [int count = 16]) async {
  // Character/background images need real asset IO. Animated Saleh never fully
  // settles, so bound frames rather than waiting on pumpAndSettle indefinitely.
  for (var index = 0; index < count; index++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 12)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _contained(Rect child, Rect parent, String label) {
  expect(child.left, greaterThanOrEqualTo(parent.left - .01), reason: label);
  expect(child.right, lessThanOrEqualTo(parent.right + .01), reason: label);
  expect(child.top, greaterThanOrEqualTo(parent.top - .01), reason: label);
  expect(child.bottom, lessThanOrEqualTo(parent.bottom + .01), reason: label);
}

void _checkFullBoard(WidgetTester tester, int count, [String? feedbackText]) {
  final board = tester.getRect(find.byKey(const ValueKey('lesson-board')));
  final scene = tester.getRect(find.byType(ReadingAssessmentScene));
  _contained(scene, board, 'reading scene inside actual LessonScreen board');
  expect(find.byKey(const ValueKey('lesson-steps-right')), findsNothing);
  expect(find.byKey(const ValueKey('lesson-saleh')), findsOneWidget);
  expect(find.byKey(const ValueKey('lesson-child-avatar')), findsOneWidget);
  Rect? previous;
  for (var index = 0; index < count; index++) {
    final current =
        tester.getRect(find.byKey(ValueKey('reading-glyph-$index')));
    _contained(current, scene, 'glyph $index inside reading scene');
    if (previous != null) {
      expect(current.width, closeTo(previous.width, .01));
      expect(current.top, closeTo(previous.top, .01));
      expect(current.center.dx, lessThan(previous.center.dx));
    }
    previous = current;
  }
  final feedback =
      tester.getRect(find.byKey(const ValueKey('reading-feedback')));
  _contained(feedback, scene, 'feedback slot inside reading scene');
  if (feedbackText != null) {
    expect(find.text(feedbackText), findsOneWidget);
    _contained(tester.getRect(find.text(feedbackText)), feedback,
        'feedback text inside reserved slot');
  }
  expect(tester.takeException(), isNull);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('v60-full-reading-capture')));
  expect(boundary.debugNeedsPaint, isFalse);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final output = File('pending_content/v60/qa/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _mic(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('reading-mic')));
  await _frames(tester, 8);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tajawal = FontLoader('Tajawal');
    for (final weight in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      tajawal.addFont(rootBundle.load('assets/fonts/Tajawal-$weight.ttf'));
    }
    await tajawal.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final configuration in [
    (
      name: 'iphone_844x390',
      size: const Size(844, 390),
      platform: TargetPlatform.iOS,
      safe: const EdgeInsets.fromLTRB(44, 0, 44, 21),
      scale: 1.0,
    ),
    (
      name: 'android_640x360',
      size: const Size(640, 360),
      platform: TargetPlatform.android,
      safe: const EdgeInsets.only(top: 24, right: 40),
      scale: 1.45,
    ),
  ]) {
    testWidgets('full reading board screenshots ${configuration.name}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = configuration.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = await tester.runAsync(() =>
          File('pending_content/v60/assets/content/lesson_reading_group_5.json')
              .readAsString());
      final json = jsonDecode(source!) as Map<String, dynamic>;
      final scene = (json['scenes'] as List).single as Map<String, dynamic>;
      final data = scene['data'] as Map<String, dynamic>;
      final items = (data['items'] as List).cast<List>();
      // Keep actual pending scene fields and real representative reference rows;
      // select only these two cards so screenshots are stable despite shuffling.
      data['items'] = [
        items.firstWhere((row) => row.length == 2),
        items.firstWhere((row) => row.length == 3),
      ];
      final lesson = Lesson.fromJson(json);
      final audio = SilentAudioService();
      final speech = _VisualSpeech();
      final router = GoRouter(initialLocation: '/reading', routes: [
        GoRoute(
            path: '/',
            builder: (_, __) =>
                const Scaffold(body: Text('visual audit done'))),
        GoRoute(
            path: '/reading',
            builder: (_, __) => LessonScreen(lessonId: lesson.id)),
      ]);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        router.dispose();
        await audio.dispose();
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(_VisualContent(lesson)),
          progressRepositoryProvider.overrideWithValue(_VisualProgress()),
          journalProvider.overrideWithValue(_VisualJournal()),
          audioServiceProvider.overrideWithValue(audio),
          speechServiceProvider.overrideWithValue(speech),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light().copyWith(platform: configuration.platform),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('v60-full-reading-capture'),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: configuration.safe,
                viewPadding: configuration.safe,
                textScaler: TextScaler.linear(configuration.scale),
              ),
              child: AppViewport(child: child!),
            ),
          ),
        ),
      ));
      await _frames(tester, 22);
      _checkFullBoard(tester, 2);
      await _capture(tester, '${configuration.name}_pair_idle');

      await _mic(tester);
      _checkFullBoard(tester, 2, 'أحسنتم يا أبطال.');
      await _capture(tester, '${configuration.name}_pair_success');
      final next = find.ancestor(
          of: find.text('متابعة'), matching: find.byType(LessonActionButton));
      await tester.tap(next);
      await _frames(tester, 12);
      _checkFullBoard(tester, 3);
      await _capture(tester, '${configuration.name}_triple_idle');

      speech.wrongNext = true;
      await _mic(tester);
      _checkFullBoard(tester, 3, 'حاولوا مرة أخرى');
      await _capture(tester, '${configuration.name}_triple_retry');
      await _mic(tester);
      _checkFullBoard(tester, 3, 'أحسنتم يا أبطال.');
      await _capture(tester, '${configuration.name}_triple_success');
      expect(tester.takeException(), isNull);
    }, tags: ['visual']);
  }
}
