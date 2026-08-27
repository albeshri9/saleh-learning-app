import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/curriculum.dart';
import '../../domain/models/lesson.dart';
import '../../domain/repositories/content_repository.dart';

/// مصدر محتوى تجريبي يقرأ JSON من أصول التطبيق.
///
/// شكل الملفات مطابق تمامًا لما ستنتجه لوحة المحتوى مستقبلًا،
/// فيكون استبدال هذا الصف بمصدر سحابي تبديل تنفيذ لا إعادة بناء.
class MockContentRepository implements ContentRepository {
  static const _base = 'assets/content';

  @override
  Future<List<Program>> loadPrograms() async {
    final raw = await rootBundle.loadString('$_base/programs.json');
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Program.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Lesson> loadLesson(String lessonId) async {
    final raw = await rootBundle.loadString('$_base/lesson_$lessonId.json');
    return Lesson.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
