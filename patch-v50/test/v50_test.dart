import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/games/first_phase_scene.dart';
import 'package:saleh_app/features/games/game_catalog.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';
import 'package:saleh_app/features/lesson/lesson_screen.dart';

import 'v38_test.dart' as support;

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(support.seed);

  test('Khaa farewell ends the lesson without announcing the checkpoint', () {
    final lesson = json('assets/content/lesson_khaa.json');
    final success = (lesson['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((scene) => scene['id'] == 'success_1');
    final line = (success['lines'] as List).single as Map<String, dynamic>;
    expect(line['male'], contains('إلى اللقاء'));
    expect(line['male'], isNot(contains('الاختبار المرحلي')));
    expect(line['female'], isNot(contains('الاختبار المرحلي')));
    expect(line['audio'], 'assets/audio/khaa/closing_v50.mp3');
    expect(File(line['audio'] as String).lengthSync(), greaterThan(1000));
  });

  test('checkpoint remediation owns seven unique letters and images', () {
    final package = json('assets/content/lesson_checkpoint_group_1.json');
    final data = ((package['scenes'] as List).first
        as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    final letters = (data['letters'] as List).cast<Map<String, dynamic>>();
    expect(letters, hasLength(7));
    expect(letters.map((entry) => entry['letter']).toSet(), hasLength(7));
    expect(letters.map((entry) => entry['image']).toSet(), hasLength(7));
    for (final entry in letters) {
      expect(File(entry['image'] as String).existsSync(), true);
      expect(File(entry['pronunciationRetryAudio'] as String).lengthSync(),
          greaterThan(1000));
    }
  });

  test('only children aged three or four may skip checkpoint free writing', () {
    expect(canSkipCheckpointFreeWriting(3), true);
    expect(canSkipCheckpointFreeWriting(4), true);
    expect(canSkipCheckpointFreeWriting(5), false);
    expect(canSkipCheckpointFreeWriting(8), false);
  });

  test('camel and rope contain real transparent alpha pixels', () async {
    for (final path in [
      'assets/images/assessment/camel_v50.png',
      'assets/images/assessment/rope_v50.png',
    ]) {
      final codec =
          await ui.instantiateImageCodec(File(path).readAsBytesSync());
      final frame = await codec.getNextFrame();
      final bytes =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);
      var transparent = 0;
      final data = bytes!;
      for (var offset = 3; offset < data.lengthInBytes; offset += 4) {
        if (data.getUint8(offset) == 0) transparent++;
      }
      expect(
          transparent, greaterThan(frame.image.width * frame.image.height ~/ 2),
          reason: path);
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('integrated games expose fifteen first-phase games only', () {
    expect(firstPhaseGameIds, hasLength(15));
    expect(firstPhaseGameIds.toSet(), hasLength(15));
    for (final world in GameWorld.values) {
      expect(
          gameCatalog.where((game) =>
              game.world == world && firstPhaseGameIds.contains(game.id)),
          hasLength(5));
    }
  });

  testWidgets('checkpoint board uses the added lower space at both sizes',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(568, 320), const Size(844, 390)]) {
      support.viewport(tester, size);
      await tester.pumpWidget(support.app(
          const LessonScreen(lessonId: 'checkpoint_group_1', initialScene: 0)));
      await support.frames(tester, 14);
      expect(find.byKey(const ValueKey('checkpoint-layout')), findsOneWidget);
      expect(find.byKey(const ValueKey('lesson-steps-right')), findsNothing);
      final board = tester.getRect(find.byKey(const ValueKey('lesson-board')));
      expect(size.height - board.bottom, lessThanOrEqualTo(5));
      final cards = [
        for (var i = 0; i < 7; i++)
          tester.getSize(find.byKey(ValueKey('checkpoint-choice-$i'))),
      ];
      expect(cards.map((card) => card.width).toSet(), hasLength(1));
      expect(cards.map((card) => card.height).toSet(), hasLength(1));
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }
  });
}
