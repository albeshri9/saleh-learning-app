/// الهيكل الهرمي للمنهج: برنامج ← مرحلة ← مستوى ← درس.
/// هذه النماذج مرآة لما ستنتجه لوحة إدارة المحتوى مستقبلًا.
class Program {
  const Program({required this.id, required this.title, required this.stages});

  final String id;
  final String title;
  final List<Stage> stages;

  factory Program.fromJson(Map<String, dynamic> json) => Program(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        stages: ((json['stages'] as List?) ?? const [])
            .map((e) => Stage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Stage {
  const Stage({required this.id, required this.title, required this.levels});

  final String id;
  final String title;
  final List<Level> levels;

  factory Stage.fromJson(Map<String, dynamic> json) => Stage(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        levels: ((json['levels'] as List?) ?? const [])
            .map((e) => Level.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// المستوى = مجموعة دروس مرتبة (مثال: المجموعة الأولى — ستة أحرف).
class Level {
  const Level({required this.id, required this.title, required this.lessons});

  final String id;
  final String title;
  final List<LessonRef> lessons;

  factory Level.fromJson(Map<String, dynamic> json) => Level(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        lessons: ((json['lessons'] as List?) ?? const [])
            .map((e) => LessonRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// مؤشر خفيف إلى درس (يُحمَّل الدرس الكامل عند فتحه فقط).
class LessonRef {
  const LessonRef({
    required this.lessonId,
    required this.title,
    this.subtitle,
    this.emoji,
    this.letter,
  });

  final String lessonId;
  final String title;
  final String? subtitle;
  final String? emoji;
  final String? letter;

  factory LessonRef.fromJson(Map<String, dynamic> json) => LessonRef(
        lessonId: json['lessonId'] as String,
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        emoji: json['emoji'] as String?,
        letter: json['letter'] as String?,
      );
}
