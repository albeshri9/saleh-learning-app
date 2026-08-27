/// حدث بصري داخل خط زمن المشهد.
///
/// يُنفَّذ بعد [at] من بداية الجملة المرتبط بها، على العنصر [target]
/// المعرّف داخل بيانات المشهد (مثل: letter، exampleCard، salehPoint).
class TimelineEvent {
  const TimelineEvent({
    required this.action,
    this.target,
    this.at = Duration.zero,
    this.params = const {},
  });

  final TimelineAction action;
  final String? target;
  final Duration at;
  final Map<String, dynamic> params;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
        action: TimelineAction.parse(json['action'] as String? ?? ''),
        target: json['target'] as String?,
        at: Duration(
          milliseconds:
              (((json['atSec'] as num?) ?? 0).toDouble() * 1000).round(),
        ),
        params: (json['params'] as Map<String, dynamic>?) ?? const {},
      );
}

enum TimelineAction {
  show,
  hide,
  highlight,
  pulse,
  scale,
  move,
  drawPath,
  playAnimation,
  playSound,
  waitForInput,
  salehPointAt,
  salehCelebrate,
  unknown;

  static TimelineAction parse(String raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return unknown; // محتوى أحدث من التطبيق؟ نتجاهل الحدث بدل الانهيار.
  }
}
