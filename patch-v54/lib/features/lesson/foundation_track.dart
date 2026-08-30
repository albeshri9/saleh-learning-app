import '../../domain/models/lesson.dart';

/// المسار الذي اختاره ولي الأمر/الطفل لتأسيس اللغة العربية.
/// المحتوى واحد، وهذه السياسة تحدد فقط الأنشطة الظاهرة والملزمة.
enum FoundationTrack {
  readWrite,
  reading,
  writing;

  String get queryValue => switch (this) {
        FoundationTrack.readWrite => 'read-write',
        FoundationTrack.reading => 'reading',
        FoundationTrack.writing => 'writing',
      };

  static FoundationTrack parse(String? value) => switch (value) {
        'reading' => FoundationTrack.reading,
        'writing' => FoundationTrack.writing,
        _ => FoundationTrack.readWrite,
      };

  bool get writingIsRequired => this != FoundationTrack.reading;

  bool allowsLessonScene(SceneType type) => switch (this) {
        FoundationTrack.readWrite => true,
        FoundationTrack.reading =>
          type != SceneType.guidedWriting && type != SceneType.freeWriting,
        FoundationTrack.writing => type == SceneType.guidedWriting ||
            type == SceneType.freeWriting ||
            type == SceneType.checkpoint ||
            type == SceneType.success,
      };

  bool allowsCheckpointTask(String type) => switch (this) {
        FoundationTrack.readWrite => true,
        FoundationTrack.reading => type != 'guided' && type != 'free',
        FoundationTrack.writing => type == 'guided' || type == 'free',
      };
}

List<int> lessonSceneIndicesForTrack(
  Lesson lesson,
  FoundationTrack track,
) =>
    [
      for (var i = 0; i < lesson.scenes.length; i++)
        if (track.allowsLessonScene(lesson.scenes[i].type)) i,
    ];
