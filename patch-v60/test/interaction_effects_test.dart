import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/core/design/widgets/touch_feedback.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';

void main() {
  testWidgets('معاينة اتجاه الهمزة في ثلاث مراحل', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RepaintBoundary(
      key: const ValueKey('hamza-preview'),
      child: SizedBox(
          width: 780,
          height: 260,
          child: Row(children: [
            for (final progress in [.35, .7, 1.0])
              Expanded(
                  child: CustomPaint(
                      painter: _HamzaPreview(progress),
                      child: const SizedBox.expand())),
          ])),
    ))));
    await expectLater(find.byKey(const ValueKey('hamza-preview')),
        matchesGoldenFile('goldens/hamza-direction.png'));
  }, tags: ['visual']);
  test('الهمزة تنحني يسارًا ثم يمينًا وتنتهي بخط يسارًا', () {
    const template = alifFathaVideoTemplate;
    final points = template.guideParts[1].centerline;
    final leftTurn = points.indexWhere((p) => p.dx == .2083);
    final rightTurn = points.indexWhere((p) => p.dx == .7500);
    expect(leftTurn, greaterThan(0));
    expect(rightTurn, greaterThan(leftTurn));
    expect(points[leftTurn].dy, greaterThan(points.first.dy));
    expect(points.last.dx, lessThan(points[rightTurn].dx));
    final samples = template.samples(const Size(600, 300), 1, count: 240);
    final stroke =
        template.strokes[1].samples(const Size(600, 300), count: 240);
    for (var i = 0; i < samples.length; i++) {
      expect((samples[i] - stroke[i]).distance, lessThan(.001));
    }
    expect(template.guideParts[0].centerline.last, const Offset(.4250, .9548));
  });
  testWidgets('نبضة واحدة وعدم تكرار الإجراء أثناء الانتظار وإيقاف المؤثرات',
      (tester) async {
    var pulses = 0;
    var calls = 0;
    final pending = Completer<void>();
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') pulses++;
      return null;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(MaterialApp(
        home: Material(
            child: Center(
                child: FeedbackTap(
                    immediate: true,
                    onTap: () {
                      calls++;
                      return pending.future;
                    },
                    child: const SizedBox(
                        width: 150, height: 80, child: Text('اختبار')))))));
    await tester.tap(find.text('اختبار'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .93);
    await tester.tap(find.text('اختبار'));
    expect(calls, 1);
    expect(pulses, 1);
    pending.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختبار'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(pulses, 2);
  });
}

class _HamzaPreview extends CustomPainter {
  _HamzaPreview(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(Colors.white, BlendMode.src);
    final part = alifFathaVideoTemplate.guideParts[1];
    final rect = Rect.fromLTWH(20, -120, size.width - 40, 1000);
    canvas.drawPath(
        part.outlinePath(rect), Paint()..color = const Color(0xFFE3DAF5));
    final metric = part.centerlinePath(rect).computeMetrics().first;
    canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = Colors.deepPurple
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.drawCircle(
        metric.getTangentForOffset(metric.length * progress)!.position,
        5,
        Paint()..color = Colors.green);
  }

  @override
  bool shouldRepaint(_HamzaPreview old) => old.progress != progress;
}
