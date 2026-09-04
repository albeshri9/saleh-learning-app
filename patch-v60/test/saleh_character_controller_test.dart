import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/character/saleh_character_controller.dart';
import 'package:saleh_app/features/lesson/widgets/saleh_character.dart';

void main() {
  group('SalehCharacterController', () {
    late ValueNotifier<bool> audio;
    late SalehCharacterController controller;

    setUp(() {
      audio = ValueNotifier(false);
      controller = SalehCharacterController(audioPlaying: audio);
    });

    tearDown(() {
      controller.dispose();
      audio.dispose();
    });

    test('بلا صوت يبقى صالح idle', () {
      expect(controller.pose, SalehPose.idle);
    });

    test('بداية الصوت ← talking، ونهايته ← عودة إلى idle', () {
      audio.value = true;
      expect(controller.pose, SalehPose.talking);
      audio.value = false;
      expect(controller.pose, SalehPose.idle);
    });

    test('الصوت يحرّك الفم أثناء الإشارة ثم يعيد حالة الإشارة', () {
      controller.setPose(SalehPose.pointing);
      audio.value = true;
      expect(controller.pose, SalehPose.talking);
      audio.value = false;
      expect(controller.pose, SalehPose.pointing);
      audio.value = true;
      controller.reset();
      expect(controller.pose, SalehPose.talking); // الصوت ما زال يعمل
    });

    test('التشجيع يبقى حتى انتقال المشهد ولا ينتهي بانتهاء دورة الفيديو', () {
      controller.setPose(SalehPose.encouraging);
      expect(controller.pose, SalehPose.encouraging);
      controller.notifyPoseCompleted(SalehPose.encouraging);
      expect(controller.pose, SalehPose.encouraging);
      controller.reset();
      expect(controller.pose, SalehPose.idle);
    });

    test('الكلام يحرك الحالات الهادئة ويحافظ على التشجيع والاحتفال', () {
      for (final pose in [SalehPose.thinking, SalehPose.waving]) {
        controller.setPose(pose);
        controller.setNarrating(true);
        expect(controller.pose, SalehPose.talking);
        controller.setNarrating(false);
        expect(controller.pose, pose);
      }
      audio.value = true;
      for (final pose in [SalehPose.encouraging, SalehPose.celebrating]) {
        controller.setPose(pose);
        expect(controller.pose, pose);
      }
    });

    test('talking لا تُقبل كطلب دلالي — الصوت وحده يقودها', () {
      controller.setPose(SalehPose.talking);
      expect(controller.pose, SalehPose.idle);
    });

    test('تغير الصوت يبلغ المستمعين', () {
      var notified = 0;
      controller.addListener(() => notified++);
      audio.value = true;
      expect(notified, 1);
    });
  });
}
