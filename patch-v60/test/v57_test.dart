import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('selected soft wooden tap is the v57 one-shot UI sound', () {
    final source =
        File('lib/services/audio/interaction_audio.dart').readAsStringSync();
    final asset = File('assets/audio/ui_tap_single_v57.wav');
    expect(source, contains('assets/audio/ui_tap_single_v57.wav'));
    expect(asset.existsSync(), true);
    expect(asset.lengthSync(), 7540);
  });

  test('assessment speech uses the definite article for dal through seen', () {
    const expected = <String, String>{
      'dal': 'الدَّا',
      'dhal': 'الذَّا',
      'raa': 'الرَّا',
      'zay': 'الزَّا',
      'seen': 'السَّا',
    };
    final manifest = json('AUDIO_V55_MANIFEST.json');
    final clips = (manifest['clips'] as List).cast<Map<String, dynamic>>();

    for (final entry in expected.entries) {
      final assessment = clips.where((clip) =>
          clip['letterId'] == entry.key &&
          (clip['key'] == 'assessment_letter' ||
              clip['key'] == 'assessment_word'));
      expect(assessment.length, 2, reason: entry.key);
      for (final clip in assessment) {
        expect(clip['text'] as String, contains('حرف ${entry.value}'));
        final asset = File(clip['asset'] as String);
        expect(asset.existsSync(), true, reason: clip['asset'] as String);
        expect(asset.lengthSync(), clip['bytes']);
      }
    }
  });

  test('prior-review prompts no longer contain bare dal-through-seen names',
      () {
    final bare = RegExp(r'حرف (دَا|ذَا|رَا|زَا|سَا)');
    for (final id in ['dal', 'dhal', 'raa', 'zay', 'seen']) {
      final content = File('assets/content/lesson_$id.json').readAsStringSync();
      expect(bare.hasMatch(content), false, reason: id);
    }
  });
}
