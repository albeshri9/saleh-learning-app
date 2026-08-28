/// تقدم الطفل في درس واحد. يُحفظ محليًا الآن، وسحابيًا لاحقًا خلف نفس الواجهة.
class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    this.lastSceneIndex = 0,
    this.completed = false,
    this.mastered = false,
    this.score = 0,
    this.attempts = const {},
    this.completedScenes = const [],
  });

  final String lessonId;
  final int lastSceneIndex;
  final bool completed;
  final bool mastered;

  /// نتيجة التقويم (0..1).
  final double score;

  /// عدد المحاولات لكل مشهد: sceneId → count.
  final Map<String, int> attempts;
  final List<String> completedScenes;

  LessonProgress copyWith({
    int? lastSceneIndex,
    bool? completed,
    bool? mastered,
    double? score,
    Map<String, int>? attempts,
    List<String>? completedScenes,
  }) =>
      LessonProgress(
        lessonId: lessonId,
        lastSceneIndex: lastSceneIndex ?? this.lastSceneIndex,
        completed: completed ?? this.completed,
        mastered: mastered ?? this.mastered,
        score: score ?? this.score,
        attempts: attempts ?? this.attempts,
        completedScenes: completedScenes ?? this.completedScenes,
      );

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'lastSceneIndex': lastSceneIndex,
        'completed': completed,
        'mastered': mastered,
        'score': score,
        'attempts': attempts,
        'completedScenes': completedScenes,
      };

  factory LessonProgress.fromJson(Map<String, dynamic> json) => LessonProgress(
        lessonId: json['lessonId'] as String,
        lastSceneIndex: json['lastSceneIndex'] as int? ?? 0,
        completed: json['completed'] as bool? ?? false,
        mastered: json['mastered'] as bool? ?? false,
        score: ((json['score'] as num?) ?? 0).toDouble(),
        completedScenes:
            (json['completedScenes'] as List? ?? []).cast<String>(),
        attempts: ((json['attempts'] as Map<String, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}
