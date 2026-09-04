import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('كل ملفات تعليق درس الألف المشار إليها موجودة وغير فارغة', () async {
    final raw = await rootBundle.loadString('assets/content/lesson_alif.json');
    final lesson = jsonDecode(raw) as Map<String, dynamic>;
    final paths = <String>{};

    void collect(Object? value) {
      if (value is Map) {
        for (final entry in value.entries) {
          if (entry.value is String &&
              (entry.key == 'audio' ||
                  entry.key.toString().endsWith('Audio'))) {
            paths.add(entry.value as String);
          } else {
            collect(entry.value);
          }
        }
      } else if (value is List) {
        for (final item in value) {
          collect(item);
        }
      }
    }

    collect(lesson);
    expect(paths, isNotEmpty);
    for (final path in paths) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: path);
    }
  });
}
