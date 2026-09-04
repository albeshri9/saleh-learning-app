// Exercise pending lessons without publishing their assets or approving audio.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/app/providers.dart';
import 'package:saleh_app/core/design/app_theme.dart';
import 'package:saleh_app/core/design/app_viewport.dart';
import 'package:saleh_app/domain/models/curriculum.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/domain/repositories/content_repository.dart';
import 'package:saleh_app/features/lesson/foundation_track.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';
import 'package:saleh_app/services/audio/audio_service.dart';
import 'v38_test.dart' as support;

const _ids = [
  'sheen',
  'saad',
  'daad',
  'tah',
  'zah',
  'ayn',
  'ghayn',
  'faa',
  'qaaf',
  'kaaf',
  'laam',
  'meem',
  'noon',
  'heh',
  'waw',
  'yaa'
];

class _PendingContent implements ContentRepository {
  final Map<String, Lesson> lessons = {
    for (final file in Directory('pending_content/v60/assets/content')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json')))
      ..._parse(file),
  };
  static Map<String, Lesson> _parse(File file) {
    final lesson = Lesson.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    return {lesson.id: lesson};
  }

  @override
  Future<Lesson> loadLesson(String lessonId) async => lessons[lessonId]!;
  @override
  Future<List<Program>> loadPrograms() async => [];
}

class _PendingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/') && !key.contains('..')) {
      final file = File('pending_content/v60/$key');
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        return ByteData.sublistView(bytes);
      }
    }
    return rootBundle.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final content = _PendingContent();
  setUp(support.seed);
  setUpAll(() async {
    final font = FontLoader('Tajawal');
    for (final weight in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      font.addFont(rootBundle.load('assets/fonts/Tajawal-$weight.ttf'));
    }
    await font.load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  test('all pending lessons respect the three foundation tracks', () {
    for (final id in _ids) {
      final lesson = content.lessons[id]!;
      final reading =
          lessonSceneIndicesForTrack(lesson, FoundationTrack.reading)
              .map((i) => lesson.scenes[i].type);
      expect(reading, isNot(contains(SceneType.guidedWriting)), reason: id);
      expect(reading, isNot(contains(SceneType.freeWriting)), reason: id);
      final writing =
          lessonSceneIndicesForTrack(lesson, FoundationTrack.writing)
              .map((i) => lesson.scenes[i].type)
              .toList();
      expect(writing,
          containsAll([SceneType.guidedWriting, SceneType.freeWriting]));
      expect(
          writing.every((t) =>
              t == SceneType.guidedWriting ||
              t == SceneType.freeWriting ||
              t == SceneType.success),
          isTrue);
    }
  });

  test(
      'new checkpoints retain cumulative questions and current-group free writing',
      () {
    for (final group in [3, 4, 5]) {
      final lesson = content.lessons['checkpoint_group_$group']!;
      final data =
          lesson.scenes.singleWhere((s) => s.type == SceneType.checkpoint).data;
      final all = checkpointTaskFlow(data);
      expect(all.where((t) => t['type'] == 'choice').length, 6);
      expect(all.where((t) => t['type'] == 'pronounce').length, 4);
      expect(all.where((t) => t['type'] == 'guided'), isEmpty);
      final writing =
          checkpointTaskFlow(data, foundationTrack: FoundationTrack.writing);
      expect(writing.length, group == 5 ? 4 : 6);
      expect(writing.every((t) => t['type'] == 'free'), isTrue);
      final reading =
          checkpointTaskFlow(data, foundationTrack: FoundationTrack.reading);
      expect(reading.any((t) => t['type'] == 'free' || t['type'] == 'guided'),
          isFalse);
    }
  });

  for (final size in [const Size(568, 320), const Size(844, 390)]) {
    testWidgets('all pending letter scenes fit the real board $size',
        (tester) async {
      support.viewport(tester, size);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = SilentAudioService();
      addTearDown(audio.dispose);
      final bundle = _PendingAssetBundle();
      for (final id in [
        ..._ids,
        'checkpoint_group_3',
        'checkpoint_group_4',
        'checkpoint_group_5'
      ]) {
        final lesson = content.lessons[id]!;
        for (var index = 0; index < lesson.scenes.length; index++) {
          await tester.pumpWidget(ProviderScope(
            overrides: [
              contentRepositoryProvider.overrideWithValue(content),
              audioServiceProvider.overrideWithValue(audio),
            ],
            child: DefaultAssetBundle(
                bundle: bundle,
                child: MaterialApp(
                  theme: AppTheme.light(),
                  locale: const Locale('ar'),
                  supportedLocales: const [Locale('ar')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate
                  ],
                  home: AppViewport(
                      child: LessonScreen(lessonId: id, initialScene: index)),
                )),
          ));
          await support.frames(tester, 8);
          expect(find.byKey(const ValueKey('lesson-board')), findsOneWidget,
              reason: '$id/$index/$size');
          expect(tester.takeException(), isNull, reason: '$id/$index/$size');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        }
      }
    });
  }
}
