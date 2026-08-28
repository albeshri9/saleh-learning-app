import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/design/widgets/letter_glyph.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/models/timeline_event.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/review_scene.dart';
import 'package:saleh_app/features/lesson/scenes/explanation_scene.dart';
import 'package:saleh_app/features/lesson/scenes/pronunciation_scene.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'v38_test.dart' as support;

Lesson lesson(String id) => Lesson.fromJson(
    jsonDecode(File('assets/content/lesson_$id.json').readAsStringSync()));
SceneApi api(SceneChannel channel) => SceneApi(
    profile: support.child,
    channel: channel,
    completeScene: () {},
    recordAttempt: () {},
    recordAnswer: ({required bool correct}) {},
    triggerSaleh: (_) {},
    replayScene: () {},
    replayGeneration: 0);
Finder glyph(String text) =>
    find.byWidgetPredicate((w) => w is LetterGlyph && w.letter == text);

class ControlledAudio extends SilentAudioService {
  final assets = <String>[];
  final feedback = Completer<void>();
  @override
  Future<void> play(String path) {
    assets.add(path);
    return path == 'retry.mp3' ? feedback.future : Future.value();
  }
}

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
  test('all cumulative reviews are audio-only and have explicit repeat audio',
      () {
    for (final id in ['baa', 'taa', 'thaa', 'jeem', 'haa']) {
      final review =
          lesson(id).scenes.singleWhere((s) => s.type == SceneType.review);
      expect(review.title, 'المراجعة القبلية');
      final questions = review.data['questions'] as List;
      expect(review.lines.length, 1);
      expect(review.lines.single.audio, 'assets/audio/v45/review_intro.mp3');
      for (final q in questions) {
        expect(q['showPrompt'], false);
        expect(File(q['audio'] as String).existsSync(), true);
      }
    }
  });
  test('Jeem uses corrected sound-name clips and preserves correct old clips',
      () {
    final l = lesson('jeem');
    final lines = l.scenes.expand((s) => s.lines);
    for (final line in lines) {
      expect(line.male, isNot(contains('الجيم')));
    }
    final manifest =
        jsonDecode(File('AUDIO_V44_MANIFEST.json').readAsStringSync()) as Map;
    expect(manifest.length, 12);
    for (final path in manifest.keys) {
      expect(File(path as String).lengthSync(), greaterThan(1000));
    }
    final explain =
        l.scenes.singleWhere((s) => s.type == SceneType.explanation);
    expect(explain.lines[2].audio, 'assets/audio/jeem/explain_3.mp3');
    expect(explain.lines[4].audio, 'assets/audio/jeem/explain_5.mp3');
    final haaReview =
        lesson('haa').scenes.singleWhere((s) => s.type == SceneType.review);
    expect(
        (haaReview.data['questions'] as List).firstWhere((q) =>
            q['reviewLessonId'] == 'jeem' && q['kind'] == 'letter')['audio'],
        'assets/audio/jeem_v44/assessment_1.mp3');
  });
  for (final leave in [false, true]) {
    testWidgets(
        'review waits for feedback then repeats unless disposed: $leave',
        (tester) async {
      final audio = ControlledAudio();
      final channel = SceneChannel();
      const scene = Scene(id: 'review', type: SceneType.review, data: {
        'retryAudio': 'retry.mp3',
        'questions': [
          {
            'prompt': 'أين حرف تَ؟',
            'showPrompt': true,
            'options': ['تَ', 'أَ', 'بَ'],
            'correctIndex': 0,
            'audio': 'question.mp3'
          }
        ]
      });
      await tester.pumpWidget(support
          .app(ReviewScene(scene: scene, api: api(channel)), audio: audio));
      channel.markFinished();
      await tester.pump();
      expect(audio.assets, ['question.mp3']);
      audio.assets.clear();
      expect(find.text('أين حرف تَ؟'), findsNothing);
      expect(glyph('تَ'), findsOneWidget);
      await tester.tap(glyph('أَ'));
      await tester.pump(const Duration(seconds: 2));
      expect(audio.assets, ['retry.mp3']);
      if (leave) await tester.pumpWidget(const SizedBox());
      audio.feedback.complete();
      await tester.pump();
      await tester.pump();
      expect(
          audio.assets, leave ? ['retry.mp3'] : ['retry.mp3', 'question.mp3']);
      if (!leave) {
        await tester.tap(glyph('بَ'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        expect(audio.assets,
            ['retry.mp3', 'question.mp3', 'retry.mp3', 'question.mp3']);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      channel.dispose();
      await audio.dispose();
    });
  }
  testWidgets('explanation and pronunciation use identical stable letter sizes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      for (final id in ['alif', 'baa', 'taa', 'thaa', 'jeem', 'haa']) {
        final l = lesson(id);
        final channel = SceneChannel();
        final explain =
            l.scenes.firstWhere((s) => s.type == SceneType.explanation);
        final pronounce =
            l.scenes.firstWhere((s) => s.type == SceneType.pronunciation);
        Widget board(Widget child) => Center(
            child: SizedBox(
                width: size.width * .62,
                height: size.height * .65,
                child: child));
        await tester.pumpWidget(support
            .app(board(ExplanationScene(scene: explain, api: api(channel)))));
        await support.frames(tester, 4);
        final before =
            tester.getSize(find.byKey(const ValueKey('explanation-letter')));
        channel.emit(const TimelineEvent(
            action: TimelineAction.show, target: 'example'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(
            tester
                .getCenter(find.byKey(const ValueKey('explanation-letter')))
                .dx,
            greaterThan(size.width / 2));
        expect(tester.getSize(find.byKey(const ValueKey('explanation-letter'))),
            before);
        expect(tester.takeException(), isNull);
        if (id == 'jeem' && const bool.fromEnvironment('V44_VISUAL')) {
          await expectLater(
              find.byKey(const ValueKey('v38-capture')),
              matchesGoldenFile(
                  'goldens/v44-explanation-${size.width.toInt()}.png'));
        }
        await tester.pumpWidget(support.app(
            board(PronunciationScene(scene: pronounce, api: api(channel)))));
        await tester.pump();
        expect(
            tester.getSize(find.byKey(const ValueKey('pronunciation-letter'))),
            before);
        expect(tester.takeException(), isNull);
        final letterRect =
            tester.getRect(find.byKey(const ValueKey('pronunciation-letter')));
        final instructionRect =
            tester.getRect(find.text('اضغط وانطق ${pronounce.data['letter']}'));
        expect(letterRect.bottom, lessThanOrEqualTo(instructionRect.top));
        if (id == 'jeem' && const bool.fromEnvironment('V44_VISUAL')) {
          await expectLater(
              find.byKey(const ValueKey('v38-capture')),
              matchesGoldenFile(
                  'goldens/v44-pronunciation-${size.width.toInt()}.png'));
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        channel.dispose();
      }
    }
  });
}
