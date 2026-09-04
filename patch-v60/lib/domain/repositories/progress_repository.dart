import '../models/child_profile.dart';
import '../models/progress.dart';

/// حفظ واسترجاع تقدم الطفل وملفه.
/// التنفيذ الحالي محلي (SharedPreferences)، ولاحقًا Firestore خلف نفس الواجهة.
abstract interface class ProgressRepository {
  Future<ChildProfile?> loadProfile();

  Future<void> saveProfile(ChildProfile profile);

  Future<LessonProgress?> loadLessonProgress(String lessonId);

  Future<void> saveLessonProgress(LessonProgress progress);
}
