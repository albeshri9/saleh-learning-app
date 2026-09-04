import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/writing/handwriting_validator.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedDots = <String, int>{
    'sheen': 3,
    'saad': 0,
    'daad': 1,
    'tah': 0,
    'zah': 1,
    'ayn': 0,
    'ghayn': 1,
    'faa': 1,
    'qaaf': 2,
    'kaaf': 0,
    'laam': 0,
    'meem': 0,
    'noon': 1,
    'heh': 0,
    'waw': 0,
    'yaa': 2,
  };
  const expectedCounters = <String, int>{
    'saad': 1,
    'daad': 1,
    'tah': 1,
    'zah': 1,
    'faa': 1,
    'qaaf': 1,
    'heh': 2,
    'waw': 1,
  };

  test('all sixteen remaining reference templates are registered distinctly',
      () {
    expect(remainingFathaTemplates, hasLength(16));
    expect(remainingFathaTemplates.map((t) => t.id).toSet(), hasLength(16));
    for (final entry in expectedDots.entries) {
      final template = LetterTraceTemplate.fromId('${entry.key}_fatha_pdf_v1');
      expect(template, isNotNull, reason: entry.key);
      expect(template!.guideParts.first.id, 'body');
      expect(template.guideParts.last.id, 'fatha');
      expect(template.parts.where((p) => p.isDot), hasLength(entry.value));
      expect(template.parts.expand((p) => p.holes),
          hasLength(expectedCounters[entry.key] ?? 0));
      expect(template.parts.where((p) => p.id == 'hamza'),
          hasLength(entry.key == 'kaaf' ? 1 : 0));
    }
  });

  test('every guide point and segment remains inside its exact reference part',
      () {
    final failures = <String>[];
    for (final size in [
      const Size(568, 320),
      const Size(667, 375),
      const Size(844, 390),
      const Size(760, 360),
    ]) {
      for (final template in remainingFathaTemplates) {
        final rect = template.drawingRect(size);
        expect((Offset.zero & size).contains(rect.topLeft), isTrue);
        expect((Offset.zero & size).contains(rect.bottomRight), isTrue);
        for (final part in template.guideParts) {
          final outline = part.outlinePath(rect);
          final samples = part.samples(rect, count: 900);
          expect(samples, isNotEmpty);
          final outside = samples.where((point) => !outline.contains(point));
          if (outside.isNotEmpty) {
            failures.add('${template.id}/${part.id} at $size: '
                '${outside.length} outside, first ${outside.first}');
          }
          for (final point in part.outline.expand((p) => [p])) {
            expect(point.dx, inInclusiveRange(0, 1));
            expect(point.dy, inInclusiveRange(0, 1));
          }
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('counters remain empty and reference dots remain slanted quadrilaterals',
      () {
    const rect = Rect.fromLTWH(0, 0, 1000, 1000);
    for (final template in remainingFathaTemplates) {
      for (final part in template.parts) {
        for (final hole in part.holes) {
          final sample = hole.reduce((a, b) => a + b) / hole.length.toDouble();
          expect(part.outlinePath(rect).contains(sample * 1000), isFalse,
              reason: '${template.id}/${part.id} counter was filled');
        }
        if (part.isDot) {
          expect(part.outline.length, inInclusiveRange(4, 5));
          expect(part.centerline, hasLength(1));
          expect(part.outlinePath(rect).contains(part.centerline.first * 1000),
              isTrue);
        }
      }
      final fatha = template.guideParts.last;
      expect(fatha.centerline.first.dx, greaterThan(fatha.centerline.last.dx));
      expect(fatha.centerline.first.dy, lessThan(fatha.centerline.last.dy));
    }
  });

  test('new reference samples validate, while missing fatha or extra dots fail',
      () {
    const size = Size(760, 360);
    for (final template in remainingFathaTemplates) {
      final strokes = [
        for (var i = 0; i < template.guideParts.length; i++)
          template.samples(size, i, count: 180),
      ];
      final correct = WritingSample(strokes: strokes, canvasSize: size);
      final guided = validateDottedLetterWriting(correct, template);
      final free = validateCheckpointLetterWriting(correct, template);
      expect(guided.isValid, isTrue,
          reason: '${template.id} guide: ${guided.missingParts}');
      expect(free.isValid, isTrue,
          reason: '${template.id} free: ${free.missingParts}');
      final withoutFatha = WritingSample(
          strokes: strokes.take(strokes.length - 1).toList(), canvasSize: size);
      expect(
          validateDottedLetterWriting(withoutFatha, template).isValid, isFalse,
          reason: '${template.id} must retain fatha');
      expect(validateCheckpointLetterWriting(withoutFatha, template).isValid,
          isFalse,
          reason: '${template.id} free writing must retain fatha');
      final dotIndex = template.guideParts.indexWhere((part) => part.isDot);
      if (dotIndex >= 0) {
        final duplicateDot = WritingSample(strokes: [
          ...strokes,
          [...strokes[dotIndex]]
        ], canvasSize: size);
        expect(validateDottedLetterWriting(duplicateDot, template).isValid,
            isFalse,
            reason: '${template.id} must reject extra dots');
        expect(validateCheckpointLetterWriting(duplicateDot, template).isValid,
            isFalse,
            reason: '${template.id} free writing extra dot');
      }
    }
  });

  test('render actual Flutter guide paths for independent visual inspection',
      () async {
    const tile = Size(330, 410);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xffffffff), BlendMode.src);
    for (var i = 0; i < remainingFathaTemplates.length; i++) {
      final template = remainingFathaTemplates[i];
      final origin = Offset((i % 4) * tile.width, (i ~/ 4) * tile.height);
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      final rect = template.drawingRect(tile);
      for (final part in template.guideParts) {
        canvas.drawPath(
            part.outlinePath(rect), Paint()..color = const Color(0xffc5e0c5));
        canvas.drawPath(
            part.outlinePath(rect),
            Paint()
              ..color = const Color(0xff496b49)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .8);
        canvas.drawPath(
            part.centerlinePath(rect),
            Paint()
              ..color = const Color(0xffca2462)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
        final samples = part.samples(rect, count: 120);
        canvas.drawCircle(
            samples.first, 3, Paint()..color = const Color(0xff2455d9));
        canvas.drawCircle(
            samples.last, 2, Paint()..color = const Color(0xffdfa922));
      }
      canvas.drawRect(
          Offset.zero & tile,
          Paint()
            ..color = const Color(0xffdddddd)
            ..style = PaintingStyle.stroke);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1320, 1640);
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    expect(bytes, isNotNull);
    final output = File('references/letterforms/v60/flutter-guide-audit.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
