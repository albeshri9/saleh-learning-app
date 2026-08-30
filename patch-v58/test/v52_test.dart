import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/games/game_catalog.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/services/audio/first_launch_narration.dart';

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

WritingSample templateSample(LetterTraceTemplate template, Size size) =>
    WritingSample(
      strokes: [
        for (var i = 0; i < template.guideParts.length; i++)
          template.samples(size, i, count: 120),
      ],
      canvasSize: size,
    );

void main() {
  test('checkpoint uses the seven approved inclusive praise phrases and audio', () {
    final package = json('assets/content/lesson_checkpoint_group_1.json');
    final data = ((package['scenes'] as List).first as Map)['data'] as Map;
    final feedback = (data['successFeedbacks'] as List).cast<Map>();
    expect(feedback.map((item) => item['text']), [
      'أحسنتم، إجابة صحيحة.',
      'ممتاز، إجابة صحيحة.',
      'يا سلام، إجابة صحيحة.',
      'بارك الله فيكم، إجابة صحيحة.',
      'رائع جدًا، إجابة صحيحة.',
      'ما شاء الله، إجابة صحيحة.',
      'أحسنتم يا أبطال.',
    ]);
    for (final item in feedback) {
      expect(File(item['audio'] as String).lengthSync(), greaterThan(1000));
    }
  });

  test('first-launch introduction is bundled and versioned once-only', () {
    expect(
        FirstLaunchNarration.preferenceKey, 'first_launch_welcome_v55_played');
    expect(FirstLaunchNarration.asset,
        'assets/audio/first_launch_welcome_v55.mp3');
    expect(File(FirstLaunchNarration.asset).lengthSync(), greaterThan(10000));
  });

  test('the complete pre-phase-one games catalog is restored', () {
    expect(gameCatalog, hasLength(36));
    for (final world in GameWorld.values) {
      expect(gameCatalog.where((game) => game.world == world), hasLength(12));
    }
  });

  test('baa requires its body, one lower dot, and the fatha', () {
    const size = Size(480, 220);
    final valid = templateSample(baaFathaTemplate, size);
    expect(validateDottedLetterWriting(valid, baaFathaTemplate).isValid, true);

    final strokes = valid.strokes.map((stroke) => stroke.toList()).toList();
    final dot = baaFathaTemplate.guideParts.indexWhere((part) => part.isDot);
    final withTwoLowerDots = WritingSample(
      strokes: [
        ...strokes,
        [...strokes[dot]]
      ],
      canvasSize: size,
    );
    final extra =
        validateDottedLetterWriting(withTwoLowerDots, baaFathaTemplate);
    expect(extra.isValid, false);
    expect(extra.missingParts, contains('extraDots'));

    final withoutFatha = WritingSample(
      strokes: strokes.sublist(0, strokes.length - 1),
      canvasSize: size,
    );
    expect(
      validateDottedLetterWriting(withoutFatha, baaFathaTemplate).isValid,
      false,
    );
  });

  test('all dotted letters reject a missing fatha or an extra dot', () {
    const size = Size(480, 220);
    for (final template in [
      baaFathaTemplate,
      taaFathaTemplate,
      thaaFathaTemplate,
      jeemFathaTemplate,
      khaaFathaTemplate,
    ]) {
      final valid = templateSample(template, size);
      expect(validateDottedLetterWriting(valid, template).isValid, true,
          reason: template.id);
      final strokes = valid.strokes.map((stroke) => stroke.toList()).toList();
      expect(
        validateDottedLetterWriting(
          WritingSample(
            strokes: strokes.sublist(0, strokes.length - 1),
            canvasSize: size,
          ),
          template,
        ).isValid,
        false,
        reason: '${template.id}: missing fatha',
      );
      final dot = template.guideParts.indexWhere((part) => part.isDot);
      expect(
        validateDottedLetterWriting(
          WritingSample(
            strokes: [
              ...strokes,
              [...strokes[dot]]
            ],
            canvasSize: size,
          ),
          template,
        ).isValid,
        false,
        reason: '${template.id}: extra dot',
      );
    }
  });

  test('alif requires both hamza and fatha in child-friendly writing', () {
    const size = Size(480, 260);
    final valid = templateSample(alifFathaVideoTemplate, size);
    expect(validateAlifFathaChildFriendly(valid).isValid, true);
    expect(
      validateAlifFathaChildFriendly(WritingSample(
        strokes: valid.strokes.sublist(0, valid.strokes.length - 1),
        canvasSize: size,
      )).isValid,
      false,
    );
  });
}
