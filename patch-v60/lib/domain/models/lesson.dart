import 'saleh_script.dart';

/// أنواع المشاهد التي يعرفها المحرك حاليًا.
/// إضافة نوع جديد = إضافة قيمة هنا + تسجيل Widget له في SceneRegistry،
/// دون أي تعديل على بقية المحرك.
enum SceneType {
  review,
  welcome,
  nasheed,
  explanation,
  pronunciation,
  reading,
  guidedWriting,
  freeWriting,
  imageWordActivity,
  multipleChoice,
  assessment,
  checkpoint,
  success,
  unknown;

  static SceneType parse(String raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return unknown;
  }
}

/// مشهد واحد داخل الدرس.
///
/// [data] حقيبة بيانات مرنة خاصة بنوع المشهد (حرف، كلمة، صورة، خيارات،
/// إعدادات كتابة...). هذا ما يجعل المحرك يعرض أي درس دون برمجة صفحات جديدة.
class Scene {
  const Scene({
    required this.id,
    required this.type,
    this.title,
    this.canSkip = true,
    this.lines = const [],
    this.data = const {},
  });

  final String id;
  final SceneType type;
  final String? title;
  final bool canSkip;

  /// سكربت صالح في هذا المشهد، بالترتيب.
  final List<SalehLine> lines;

  final Map<String, dynamic> data;

  factory Scene.fromJson(Map<String, dynamic> json) => Scene(
        id: json['id'] as String,
        type: SceneType.parse(json['type'] as String? ?? ''),
        title: json['title'] as String?,
        canSkip: json['canSkip'] as bool? ?? true,
        lines: ((json['lines'] as List?) ?? const [])
            .map((e) => SalehLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        data: (json['data'] as Map<String, dynamic>?) ?? const {},
      );
}

/// إعدادات الكتابة — تأتي من المحتوى ولا تُكتب في الكود أبدًا.
class WritingConfig {
  const WritingConfig({
    this.guidedAttempts = 1,
    this.freeAttempts = 1,
    this.required = true,
  });

  final int guidedAttempts;
  final int freeAttempts;
  final bool required;

  factory WritingConfig.fromJson(Map<String, dynamic> json) => WritingConfig(
        guidedAttempts: json['guidedAttempts'] as int? ?? 1,
        freeAttempts: json['freeAttempts'] as int? ?? 1,
        required: json['required'] as bool? ?? true,
      );
}

/// قواعد الإتقان لدرسٍ ما — من المحتوى.
class MasteryRules {
  const MasteryRules({this.minScore = 0.6, this.requiredSceneIds = const []});

  /// نسبة النجاح الدنيا في مشاهد التقويم (0..1).
  final double minScore;

  /// مشاهد لا يُعد الدرس متقنًا دون إكمالها.
  final List<String> requiredSceneIds;

  factory MasteryRules.fromJson(Map<String, dynamic> json) => MasteryRules(
        minScore: ((json['minScore'] as num?) ?? 0.6).toDouble(),
        requiredSceneIds:
            ((json['requiredSceneIds'] as List?) ?? const []).cast<String>(),
      );
}

/// الدرس: تسلسل مشاهد + قواعد إتقان. المحرك لا يعرف «حرف الثاء»،
/// يعرف فقط كيف يشغّل هذا الهيكل.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.scenes,
    this.mastery = const MasteryRules(),
  });

  final String id;
  final String title;
  final List<Scene> scenes;
  final MasteryRules mastery;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        scenes: ((json['scenes'] as List?) ?? const [])
            .map((e) => Scene.fromJson(e as Map<String, dynamic>))
            .toList(),
        mastery: json['mastery'] == null
            ? const MasteryRules()
            : MasteryRules.fromJson(json['mastery'] as Map<String, dynamic>),
      );
}
