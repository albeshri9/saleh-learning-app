import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/character/video/saleh_video_clips.dart';
import 'package:saleh_app/features/lesson/widgets/saleh_character.dart';

void main() {
  test('كل حالات صالح تسجل صور WebP المتحركة والملصقات المستخدمة فعليًا', () {
    for (final pose in SalehPose.values) {
      final clip = SalehVideoClips.forPose(pose);
      expect(clip.poster, endsWith('.png'));
      expect(File(clip.poster).existsSync(), isTrue, reason: clip.poster);
      // Idle and thinking use Saleh2DIdle's breathing animation of the poster,
      // not the retired idle video or its animated WebP export.
      if (pose == SalehPose.idle || pose == SalehPose.thinking) continue;
      // The renderer uses animated WebP on Android and iOS; historical WebM
      // source videos are intentionally not required in release source packs.
      expect(clip.iosAnimatedAsset, endsWith('.webp'));
      final animated = File(clip.iosAnimatedAsset);
      expect(animated.existsSync(), isTrue, reason: clip.iosAnimatedAsset);
      final header = animated.readAsBytesSync().take(12).toList();
      expect(String.fromCharCodes(header.take(4)), 'RIFF');
      expect(String.fromCharCodes(header.skip(8)), 'WEBP');
    }
  });

  test('كل حالة تبقى متكررة حتى ينتقل الدرس إلى حالة أخرى', () {
    for (final pose in SalehPose.values) {
      expect(SalehVideoClips.forPose(pose).loop, isTrue, reason: pose.name);
    }
  });
}
