import '../models/curriculum.dart';
import '../models/lesson.dart';

/// مصدر المحتوى التعليمي.
///
/// الواجهة الوحيدة التي يراها المحرك — التنفيذ الحالي Mock من ملفات محلية،
/// وغدًا Firebase أو CMS كامل دون أن يتغير أي شيء فوق هذه الطبقة.
abstract interface class ContentRepository {
  Future<List<Program>> loadPrograms();

  Future<Lesson> loadLesson(String lessonId);
}
