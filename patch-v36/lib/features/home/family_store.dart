import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/progress.dart';

class FamilyStore {
  Future<List<ChildProfile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('family_v36');
    if (raw != null) {
      return (jsonDecode(raw) as List)
          .map(
              (e) => ChildProfile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    // Keep the old profile id so existing lesson keys remain untouched.
    final legacy = prefs.getString('child_profile');
    if (legacy == null) return [];
    final children = [
      ChildProfile.fromJson(jsonDecode(legacy) as Map<String, dynamic>)
    ];
    await save(children);
    return children;
  }

  Future<void> save(List<ChildProfile> children) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'family_v36', jsonEncode(children.map((e) => e.toJson()).toList()));
  }

  Future<String?> activeId() async =>
      (await SharedPreferences.getInstance()).getString('active_child_v36');

  Future<void> activate(ChildProfile child) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_profile', jsonEncode(child.toJson()));
    await prefs.setString('active_child_v36', child.id);
  }
}

final familyStoreProvider = Provider((ref) => FamilyStore());

final worldProgressProvider = FutureProvider.autoDispose<LessonProgress?>(
    (ref) => ref.watch(progressRepositoryProvider).loadLessonProgress('alif'));

String activityLabel(int index) => const [
      'الترحيب',
      'أنشودة الألف',
      'شرح حرف الألف',
      'تدريب النطق',
      'الكتابة بالدليل',
      'الكتابة الحرة',
      'لعبة حرف الألف',
      'ختام الدرس',
    ][index.clamp(0, 7)];

/// Review only material the child has actually reached, never future lessons.
int reviewScene(LessonProgress? progress, ChildProfile child) {
  if (progress == null) return child.level == 'beginner' ? 0 : 2;
  if (progress.completed || progress.lastSceneIndex >= 6) return 6;
  if (progress.lastSceneIndex >= 4) return 4;
  return progress.lastSceneIndex >= 2 ? 2 : 0;
}
