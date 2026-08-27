import 'child_profile.dart';
import 'timeline_event.dart';

/// جملة واحدة من كلام صالح.
///
/// النص يُكتب بصيغتين (مذكر/مؤنث) مع متغير {name}، ويُحلّ وقت العرض
/// حسب [ChildProfile]. الصوت اختياري (يُرفع من لوحة المحتوى لاحقًا).
/// [events] أحداث بصرية مرتبطة زمنيًا ببداية نطق الجملة.
class SalehLine {
  const SalehLine({
    required this.male,
    required this.female,
    this.audio,
    this.duration = const Duration(seconds: 3),
    this.events = const [],
  });

  /// نص المخاطبة للذكر، مثال: «أهلًا يا {name}، انظرْ إلى الحرف.»
  final String male;

  /// نص المخاطبة للأنثى، مثال: «أهلًا يا {name}، انظري إلى الحرف.»
  final String female;

  /// مسار ملف الصوت في المحتوى (اختياري في النموذج الأولي).
  final String? audio;

  /// مدة الجملة — تحدد إيقاع المشهد عند غياب ملف صوت حقيقي.
  final Duration duration;

  final List<TimelineEvent> events;

  String resolve(ChildProfile child) {
    final template = child.isMale ? male : female;
    return template.replaceAll('{name}', child.name);
  }

  factory SalehLine.fromJson(Map<String, dynamic> json) => SalehLine(
        male: json['male'] as String? ?? json['text'] as String? ?? '',
        female: json['female'] as String? ??
            json['male'] as String? ??
            json['text'] as String? ??
            '',
        audio: json['audio'] as String?,
        duration: Duration(
          milliseconds:
              (((json['durationSec'] as num?) ?? 3).toDouble() * 1000).round(),
        ),
        events: ((json['events'] as List?) ?? const [])
            .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
