import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/home/world_screen.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';

import 'v38_test.dart' as support;

Map<String, dynamic> json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Iterable<Map<String, dynamic>> allMaps(dynamic value) sync* {
  if (value is Map) {
    final map = value.cast<String, dynamic>();
    yield map;
    for (final child in map.values) {
      yield* allMaps(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* allMaps(child);
    }
  }
}

Iterable<String> allStrings(dynamic value) sync* {
  if (value is String) {
    yield value;
  } else if (value is Map) {
    for (final child in value.values) {
      yield* allStrings(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* allStrings(child);
    }
  }
}

String withoutHarakat(String value) =>
    value.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

Rect pointsBounds(Iterable<Offset> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) return Rect.zero;
  var left = iterator.current.dx;
  var right = left;
  var top = iterator.current.dy;
  var bottom = top;
  while (iterator.moveNext()) {
    final point = iterator.current;
    if (point.dx < left) left = point.dx;
    if (point.dx > right) right = point.dx;
    if (point.dy < top) top = point.dy;
    if (point.dy > bottom) bottom = point.dy;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

WritingSample placedTemplateSample(
  LetterTraceTemplate template,
  Size canvas,
  Rect placement, {
  bool includeFatha = true,
  bool duplicateDot = false,
}) {
  final source = <List<Offset>>[
    for (var index = 0; index < template.guideParts.length; index++)
      if (includeFatha || template.guideParts[index].id != 'fatha')
        template.samples(canvas, index, count: 140),
  ];
  final bounds = pointsBounds(source.expand((stroke) => stroke));
  final strokes = source
      .map((stroke) => stroke
          .map((point) => Offset(
                placement.left +
                    ((point.dx - bounds.left) / bounds.width) * placement.width,
                placement.top +
                    ((point.dy - bounds.top) / bounds.height) *
                        placement.height,
              ))
          .toList())
      .toList();
  if (duplicateDot) {
    final dotIndex = template.guideParts.indexWhere((part) => part.isDot);
    if (dotIndex >= 0) {
      final sourceIndex = includeFatha ||
              template.guideParts
                  .take(dotIndex)
                  .every((part) => part.id != 'fatha')
          ? dotIndex
          : dotIndex - 1;
      strokes.add(List<Offset>.from(strokes[sourceIndex]));
    }
  }
  return WritingSample(strokes: strokes, canvasSize: canvas);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(support.seed);

  const praise = [
    'أحسنتم، إجابة صحيحة.',
    'ممتاز، إجابة صحيحة.',
    'يا سلام، إجابة صحيحة.',
    'بارك الله فيكم، إجابة صحيحة.',
    'رائع جدًا، إجابة صحيحة.',
    'ما شاء الله، إجابة صحيحة.',
    'أحسنتم يا أبطال.',
  ];

  test('both checkpoints use only the seven approved praise phrases', () {
    for (final path in [
      'assets/content/lesson_checkpoint_group_1.json',
      'assets/content/lesson_checkpoint_group_2.json',
    ]) {
      final package = json(path);
      final checkpoint = (package['scenes'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((scene) => scene['type'] == 'checkpoint');
      final data = checkpoint['data'] as Map<String, dynamic>;
      final feedback =
          (data['successFeedbacks'] as List).cast<Map<String, dynamic>>();
      expect(feedback.map((item) => item['text']).toList(), praise,
          reason: path);
      expect(feedback.map((item) => item['audio']).toSet(), hasLength(7));
      expect(File(path).readAsStringSync(), isNot(contains('أبدعتم')));
      expect(File(path).readAsStringSync(), isNot(contains('إجابة موفقة')));

      final success = (package['scenes'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((scene) => scene['type'] == 'success');
      final audioFiles = <String>{
        data['dragMatchPromptAudio'] as String,
        data['wrongAudio'] as String,
        for (final item in feedback) item['audio'] as String,
        ((success['lines'] as List).first as Map)['audio'] as String,
      };
      expect(audioFiles, hasLength(10), reason: path);
      for (final audio in audioFiles) {
        expect(File(audio).lengthSync(), greaterThan(1000), reason: audio);
      }
    }
  });

  test('catalog uses the conventional definite names from dal through seen',
      () {
    const titles = {
      'dal': 'حرف الدال',
      'dhal': 'حرف الذال',
      'raa': 'حرف الراء',
      'zay': 'حرف الزاي',
      'seen': 'حرف السين',
    };
    final packs = (json('assets/content/lesson_packs.json')['packs'] as List)
        .cast<Map<String, dynamic>>();
    final programs = allMaps(
      jsonDecode(File('assets/content/programs.json').readAsStringSync()),
    ).toList();
    for (final entry in titles.entries) {
      expect(
        packs.singleWhere((pack) => pack['id'] == entry.key)['title'],
        entry.value,
      );
      expect(
        programs.any((item) =>
            item['lessonId'] == entry.key && item['title'] == entry.value),
        true,
        reason: entry.key,
      );
    }
  });

  test('every sentence from dal through seen uses the definite article', () {
    const expected = {
      'dal': ('الدَا', 'دَا'),
      'dhal': ('الذَا', 'ذَا'),
      'raa': ('الرَا', 'رَا'),
      'zay': ('الزَا', 'زَا'),
      'seen': ('السَا', 'سَا'),
    };
    final forbiddenBare = RegExp(
      r'حرف\s+(دال|ذال|راء|زاي|سين|دا|ذا|را|زا|سا|د|ذ|ر|ز|س)(?=\s|[؟،,.!]|$)',
    );

    for (final entry in expected.entries) {
      final package = json('assets/content/lesson_${entry.key}.json');
      final strings = allStrings(package).toList();
      final violations = strings
          .where((text) => forbiddenBare.hasMatch(withoutHarakat(text)))
          .toList();
      expect(violations, isEmpty, reason: '${entry.key}: $violations');
      expect(
          strings.any((text) => text.contains('حرف ${entry.value.$1}')), true,
          reason: entry.key);
      expect(
        allMaps(package).any((item) =>
            item['spokenLetter'] == entry.value.$2 &&
            item['expected'] == entry.value.$2),
        true,
        reason: '${entry.key}: bare phoneme remains bare only for speech',
      );
    }

    final narrationViolations = allStrings(json('tool/v55_narration.json'))
        .where((text) => forbiddenBare.hasMatch(withoutHarakat(text)))
        .toList();
    expect(narrationViolations, isEmpty);

    for (final path in [
      'tool/build_v54_content.py',
      'tool/build_v55_content.py',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("حرف {item['letter']}")), reason: path);
      expect(source, contains("item['assessment']"), reason: path);
    }
  });

  test('checkpoint free writing accepts the letter anywhere at 50 percent', () {
    const canvas = Size(900, 430);
    final templates = [
      alifFathaVideoTemplate,
      dalFathaTemplate,
      dhalFathaTemplate,
      raaFathaTemplate,
      zayFathaTemplate,
      seenFathaTemplate,
    ];
    for (var index = 0; index < templates.length; index++) {
      final template = templates[index];
      final placement = index.isEven
          ? const Rect.fromLTWH(35, 24, 255, 235)
          : const Rect.fromLTWH(590, 155, 250, 225);
      final valid = validateCheckpointLetterWriting(
        placedTemplateSample(template, canvas, placement),
        template,
      );
      expect(valid.isValid, true,
          reason: '${template.id}: ${valid.missingParts} ${valid.score}');
      expect(valid.score, greaterThanOrEqualTo(.50), reason: template.id);

      final missingFatha = validateCheckpointLetterWriting(
        placedTemplateSample(template, canvas, placement, includeFatha: false),
        template,
      );
      expect(missingFatha.isValid, false,
          reason: '${template.id}: missing fatha');
      expect(missingFatha.missingParts, contains('fatha'));
    }

    for (final template in [dhalFathaTemplate, zayFathaTemplate]) {
      final extraDot = validateCheckpointLetterWriting(
        placedTemplateSample(
          template,
          canvas,
          const Rect.fromLTWH(310, 75, 270, 240),
          duplicateDot: true,
        ),
        template,
      );
      expect(extraDot.isValid, false, reason: '${template.id}: extra dot');
      expect(extraDot.missingParts, contains('extraDots'));
    }

    final tiny = validateCheckpointLetterWriting(
      WritingSample(
        strokes: const [
          [Offset(10, 10), Offset(12, 11)]
        ],
        canvasSize: const Size(900, 430),
      ),
      seenFathaTemplate,
    );
    expect(tiny.isValid, false);
    expect(tiny.reason, anyOf('tooSmall', 'missingParts'));
  });

  testWidgets('track icons have one size, one baseline, and no clipping',
      (tester) async {
    support.viewport(tester, const Size(844, 390));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(support.app(const WorldScreen()));
    await support.frames(tester, 14);
    await tester.tap(find.text('تأسيس اللغة العربية'));
    await support.frames(tester, 8);

    final rects = [
      tester.getRect(find.byKey(const ValueKey('track-icon-read-write'))),
      tester.getRect(find.byKey(const ValueKey('track-icon-reading'))),
      tester.getRect(find.byKey(const ValueKey('track-icon-writing'))),
    ];
    for (final rect in rects) {
      expect(rect.size, const Size.square(48));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(390));
    }
    expect(rects.map((rect) => rect.center.dy).toSet(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
