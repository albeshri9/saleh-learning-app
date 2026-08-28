import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';
import 'package:saleh_app/features/lesson/writing/writing_canvases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('partial reveal fills passed cross-sections and stays inside silhouette',
      () async {
    const size = Size(300, 260);
    for (final template in [
      alifFathaVideoTemplate,
      jeemFathaTemplate,
      haaFathaTemplate
    ]) {
      final rect = template.drawingRect(size);
      for (final part in template.guideParts.where((p) => !p.isDot)) {
        final outline = part.outlinePath(rect);
        final samples = part.samples(rect, count: 160);
        for (final progress in [.3, .6, .9]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          paintTracePartReveal(canvas, rect, part, progress, Colors.green);
          final picture = recorder.endRecording();
          final bitmap = await picture.toImage(300, 260);
          final pixels =
              (await bitmap.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          for (var y = 2; y < 258; y += 3) {
            for (var x = 2; x < 298; x += 3) {
              final point = Offset(x + .5, y + .5);
              final inside = outline.contains(point);
              final alpha = pixels.getUint8((y * 300 + x) * 4 + 3);
              if (!inside) {
                // Ignore anti-aliased pixels touching an edge.
                if (![
                  const Offset(1, 0),
                  const Offset(-1, 0),
                  const Offset(0, 1),
                  const Offset(0, -1)
                ].any((d) => outline.contains(point + d))) {
                  expect(alpha, 0);
                }
              } else if ([
                const Offset(1, 0),
                const Offset(-1, 0),
                const Offset(0, 1),
                const Offset(0, -1)
              ].every((d) => outline.contains(point + d))) {
                var nearest = 0;
                var distance = double.infinity;
                for (var i = 0; i < samples.length; i++) {
                  final d = (samples[i] - point).distanceSquared;
                  if (d < distance) {
                    distance = d;
                    nearest = i;
                  }
                }
                if (nearest / (samples.length - 1) < progress - .035) {
                  expect(alpha, greaterThan(245),
                      reason: '${template.id}/${part.id} $progress at $point');
                }
              }
            }
          }
          bitmap.dispose();
          picture.dispose();
        }
      }
    }
  });
  testWidgets('curved reveal visual comparison', (tester) async {
    tester.view.physicalSize = const Size(900, 450);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(
                key: const ValueKey('reveal-preview'),
                child: Row(children: [
                  for (final template in [
                    alifFathaVideoTemplate,
                    jeemFathaTemplate,
                    haaFathaTemplate
                  ])
                    Expanded(
                        child: Column(children: [
                      for (final progress in [.3, .6, .9])
                        Expanded(
                            child: CustomPaint(
                                painter: RevealPreview(template, progress),
                                child: const SizedBox.expand()))
                    ]))
                ])))));
    await expectLater(find.byKey(const ValueKey('reveal-preview')),
        matchesGoldenFile('goldens/v45-reveal.png'));
  }, tags: ['visual']);
}

class RevealPreview extends CustomPainter {
  RevealPreview(this.template, this.progress);
  final LetterTraceTemplate template;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = template.drawingRect(size);
    final part = template.guideParts.first;
    canvas.drawPath(
        part.outlinePath(rect), Paint()..color = const Color(0xFFECE6F2));
    paintTracePartReveal(canvas, rect, part, progress, Colors.green);
  }

  @override
  bool shouldRepaint(RevealPreview old) => false;
}
