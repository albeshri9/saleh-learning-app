import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/lesson/writing/letter_trace_template.dart';

void main() {
  test('group two active guide samples stay inside their approved glyphs', () {
    const size = Size(760, 360);
    final failures = <String>[];
    for (final template in [
      dalFathaTemplate,
      dhalFathaTemplate,
      raaFathaTemplate,
      zayFathaTemplate,
      seenFathaTemplate,
    ]) {
      final rect = template.drawingRect(size);
      for (final part in template.guideParts) {
        if (part.isDot) continue;
        final outline = part.outlinePath(rect);
        final samples = part.samples(rect, count: 300);
        final outsidePoints =
            samples.where((point) => !outline.contains(point)).toList();
        final outside = outsidePoints.length;
        if (outside > 0) {
          failures.add(
              '${template.id}/${part.id}: $outside/${samples.length} ${outsidePoints.take(2).toList()}');
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
