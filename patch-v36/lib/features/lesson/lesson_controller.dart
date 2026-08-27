import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/lesson.dart';
import '../../domain/models/progress.dart';
import '../../domain/repositories/progress_repository.dart';

/// حالة تشغيل درس واحد داخل المحرك.
class LessonRunState {
  const LessonRunState({
    required this.lesson,
    required this.sceneIndex,
    this.correctAnswers = 0,
    this.totalQuestions = 0,
    this.attempts = const {},
    this.finished = false,
  });

  final Lesson lesson;
  final int sceneIndex;
  final int correctAnswers;
  final int totalQuestions;
  final Map<String, int> attempts;
  final bool finished;

  Scene get currentScene => lesson.scenes[sceneIndex];

  double get score => totalQuestions == 0 ? 1 : correctAnswers / totalQuestions;

  LessonRunState copyWith({
    int? sceneIndex,
    int? correctAnswers,
    int? totalQuestions,
    Map<String, int>? attempts,
    bool? finished,
  }) =>
      LessonRunState(
        lesson: lesson,
        sceneIndex: sceneIndex ?? this.sceneIndex,
        correctAnswers: correctAnswers ?? this.correctAnswers,
        totalQuestions: totalQuestions ?? this.totalQuestions,
        attempts: attempts ?? this.attempts,
        finished: finished ?? this.finished,
      );
}

/// متحكم الدرس: يحمّل المحتوى، يتنقل بين المشاهد، يسجل المحاولات
/// والإجابات، ويحفظ التقدم. لا يعرف شيئًا عن نوع المحتوى المعروض.
class LessonController
    extends AutoDisposeFamilyAsyncNotifier<LessonRunState, String> {
  bool _transitioning = false;
  late ProgressRepository _repository;
  LessonProgress? _saved;
  final Set<String> _completedScenes = {};
  @override
  Future<LessonRunState> build(String arg) async {
    _repository = ref.watch(progressRepositoryProvider);
    final lesson = await ref.read(contentRepositoryProvider).loadLesson(arg);
    final saved = await _repository.loadLessonProgress(arg);
    _saved = saved;
    _completedScenes
      ..clear()
      ..addAll(saved?.completedScenes ?? []);
    final startIndex = (saved != null &&
            !saved.completed &&
            saved.lastSceneIndex < lesson.scenes.length)
        ? saved.lastSceneIndex
        : 0;
    return LessonRunState(
        lesson: lesson,
        sceneIndex: startIndex,
        attempts: saved?.attempts ?? {});
  }

  LessonRunState? get _s => state.valueOrNull;

  /// إكمال المشهد الحالي (نجاحًا أو تخطيًا) والانتقال للتالي.
  Future<void> completeScene({bool skipped = false}) async {
    // ضغطة واحدة تنفذ انتقالًا واحدًا فقط. يمنع النقر السريع من تخطي
    // أكثر من مشهد بينما يجري حفظ التقدم في الخلفية.
    if (_transitioning) return;
    final s = _s;
    if (s == null || s.finished) return;
    _transitioning = true;
    if (!skipped) _completedScenes.add(s.currentScene.id);
    final nextIndex = s.sceneIndex + 1;
    try {
      if (nextIndex >= s.lesson.scenes.length) {
        await _finish(s);
      } else {
        final next = s.copyWith(sceneIndex: nextIndex);
        // يتغير المشهد فورًا من أول ضغطة، والحفظ لا يؤخر الواجهة.
        state = AsyncData(next);
        await _persist(next);
      }
    } finally {
      _transitioning = false;
    }
  }

  /// قفزة مباشرة لمشهد محدد — للمعاينة (رابط ?scene=N) ولأدوات المحتوى.
  void jumpToScene(int index) {
    final s = _s;
    if (s == null || index < 0 || index >= s.lesson.scenes.length) return;
    state = AsyncData(s.copyWith(sceneIndex: index));
  }

  /// تسجيل محاولة في المشهد الحالي (كتابة، نطق...).
  void recordAttempt() {
    final s = _s;
    if (s == null) return;
    final id = s.currentScene.id;
    state = AsyncData(
      s.copyWith(attempts: {...s.attempts, id: (s.attempts[id] ?? 0) + 1}),
    );
  }

  /// تسجيل إجابة سؤال تقويمي.
  void recordAnswer({required bool correct}) {
    final s = _s;
    if (s == null) return;
    state = AsyncData(s.copyWith(
      totalQuestions: s.totalQuestions + 1,
      correctAnswers: s.correctAnswers + (correct ? 1 : 0),
    ));
  }

  Future<void> _finish(LessonRunState s) async {
    final mastered = s.score >= s.lesson.mastery.minScore;
    final done = s.copyWith(finished: true);
    state = AsyncData(done);
    await _repository.saveLessonProgress(
      LessonProgress(
        lessonId: s.lesson.id,
        lastSceneIndex: 0,
        completed: true,
        mastered: mastered,
        score: s.score,
        attempts: s.attempts,
        completedScenes: _completedScenes.toList(),
      ),
    );
  }

  Future<void> _persist(LessonRunState s) async {
    await _repository.saveLessonProgress(
      LessonProgress(
        lessonId: s.lesson.id,
        lastSceneIndex: s.sceneIndex,
        completed: _saved?.completed ?? false,
        mastered: _saved?.mastered ?? false,
        score: s.score,
        attempts: s.attempts,
        completedScenes: _completedScenes.toList(),
      ),
    );
  }
}

final lessonControllerProvider = AsyncNotifierProvider.autoDispose
    .family<LessonController, LessonRunState, String>(LessonController.new);
