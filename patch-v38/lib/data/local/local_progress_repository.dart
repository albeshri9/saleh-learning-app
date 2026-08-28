import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/child_profile.dart';
import '../../domain/models/progress.dart';
import '../../domain/repositories/progress_repository.dart';

/// حفظ محلي مؤقت عبر SharedPreferences — كافٍ للنموذج الأولي.
class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository({this.profileId = 'legacy'});
  final String profileId;
  String _key(String lesson) => profileId == 'legacy'
      ? '$_progressPrefix$lesson'
      : 'child_${profileId}_lesson_$lesson';
  static const _profileKey = 'child_profile';
  static const _progressPrefix = 'lesson_progress_';

  @override
  Future<ChildProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return null;
    return ChildProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveProfile(ChildProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<LessonProgress?> loadLessonProgress(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(lessonId));
    if (raw == null) return null;
    return LessonProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveLessonProgress(LessonProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(progress.lessonId),
      jsonEncode(progress.toJson()),
    );
  }
}
