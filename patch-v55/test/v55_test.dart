import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/foundation_track.dart';
import 'package:saleh_app/features/lesson/scenes/checkpoint_scene.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/services/audio/first_launch_narration.dart';
import 'package:saleh_app/services/speech/speech_service.dart';

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('PDF-reference templates include exact non-circular dots', () {
    expect(khaaFathaTemplate.id, 'khaa_fatha_pdf_v1');
    for (final template in [
      khaaFathaTemplate,
      dhalFathaTemplate,
      zayFathaTemplate,
    ]) {
      final dot = template.parts.singleWhere((part) => part.isDot);
      expect(dot.smoothOutline, false, reason: template.id);
      // Arial's guide dot is the four-corner diamond from حروف.pdf.
      expect(dot.outline.length, greaterThanOrEqualTo(4), reason: template.id);
      expect(dot.id, 'dot1');
    }
  });

  test('checkpoint writing is free writing only in both writing tracks', () {
    final package = json('assets/content/lesson_checkpoint_group_2.json');
    final scene = (package['scenes'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((item) => item['type'] == 'checkpoint');
    final data = scene['data'] as Map<String, dynamic>;
    for (final track in [FoundationTrack.readWrite, FoundationTrack.writing]) {
      final tasks = checkpointTaskFlow(data,
          random: math.Random(55), foundationTrack: track);
      final writing = tasks.where((task) => task['phase'] == 'writing');
      expect(writing, isNotEmpty);
      expect(writing.every((task) => task['type'] == 'free'), true);
    }
  });

  test('Alif sound accepts common device transcriptions of the same sound', () {
    for (final heard in ['آ', 'أ', 'ا', 'آه', 'اا', 'الألف']) {
      expect(speechMatchesExpected(heard, 'آ'), true, reason: heard);
    }
  });

  test('group-two narration uses the approved model and exact template', () {
    final manifest = json('tool/v55_narration.json');
    expect(manifest['voiceId'], 'zAHOVUiYXuxggpSljiCQ');
    expect(manifest['modelId'], 'eleven_v3');
    expect(manifest['generationsCount'], 1);
    final clips = (manifest['clips'] as List).cast<Map>();
    expect(clips, hasLength(76));
    for (final id in ['dal', 'dhal', 'raa', 'zay', 'seen']) {
      final letterClips = clips.where((clip) => clip['letterId'] == id);
      expect(letterClips, hasLength(15), reason: id);
      expect(
          letterClips.map((clip) => clip['key']).toSet(),
          containsAll([
            'welcome',
            'nasheed_intro',
            'explain_1',
            'explain_2',
            'explain_3',
            'explain_4',
            'explain_5',
            'explain_6',
            'pronounce_intro',
            'writing_demo',
            'writing_try',
            'free_intro',
            'assessment_letter',
            'assessment_word',
            'closing',
          ]));
    }
    final startup =
        clips.singleWhere((clip) => clip['key'] == 'first_launch_welcome_v55');
    expect(startup['text'], contains('في برنامج تَعلًَمْ مَعَ صالِحْ'));
  });

  test('startup and one-shot tap assets are versioned for v55', () {
    expect(
        FirstLaunchNarration.preferenceKey, 'first_launch_welcome_v55_played');
    expect(FirstLaunchNarration.asset,
        'assets/audio/first_launch_welcome_v55.mp3');
    expect(File('assets/audio/ui_tap_single_v55.mp3').lengthSync(),
        greaterThan(1000));
  });
}
