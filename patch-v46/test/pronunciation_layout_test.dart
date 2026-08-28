import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/domain/models/child_profile.dart';
import 'package:saleh_app/domain/models/lesson.dart';
import 'package:saleh_app/features/lesson/scene_registry.dart';
import 'package:saleh_app/features/lesson/scenes/pronunciation_scene.dart';

void main() {
  testWidgets('الحرف في الوسط والتخطي يسارًا دون تجاوز المساحة',
      (tester) async {
    final font = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await font.load();
    final channel = SceneChannel();
    addTearDown(channel.dispose);
    for (final height in [300.0, 420.0]) {
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              theme: ThemeData(fontFamily: 'Tajawal'),
              home: Scaffold(
                body: Center(
                    child: RepaintBoundary(
                  key: const ValueKey('preview'),
                  child: SizedBox(
                    width: 600,
                    height: height,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: PronunciationScene(
                        scene: const Scene(
                            id: 'pronunciation',
                            type: SceneType.pronunciation,
                            data: {'letter': 'أَ'}),
                        api: SceneApi(
                            profile: const ChildProfile(
                                name: 'محمد', gender: ChildGender.male),
                            channel: channel,
                            completeScene: () {},
                            recordAttempt: () {},
                            recordAnswer: ({required bool correct}) {},
                            triggerSaleh: (_) {},
                            replayScene: () {},
                            replayGeneration: 0),
                      ),
                    ),
                  ),
                )),
              ))));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final bounds = tester.getRect(find.byKey(const ValueKey('preview')));
      final letter =
          tester.getRect(find.byKey(const ValueKey('pronunciation-letter')));
      expect(letter.center.dx, closeTo(bounds.center.dx, 1));
      final instructions = tester.getRect(find.text('اضغط وانطق أَ'));
      expect(letter.center.dy, closeTo((bounds.top + instructions.top) / 2, 1));
      expect(find.text('تخطي'), findsNothing);
      expect(letter.bottom,
          lessThan(tester.getTopLeft(find.text('اضغط وانطق أَ')).dy));
      await expectLater(find.byKey(const ValueKey('preview')),
          matchesGoldenFile('goldens/pronunciation-${height.toInt()}.png'));
    }
  }, tags: ['visual']);
}
