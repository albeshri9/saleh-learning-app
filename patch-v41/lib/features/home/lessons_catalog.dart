import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/models/progress.dart';
import '../../core/design/widgets/letter_glyph.dart';
import '../../core/design/widgets/touch_feedback.dart';

final allLessonProgressProvider = FutureProvider.autoDispose((ref) async {
  final repository = ref.watch(progressRepositoryProvider);
  final programs = await ref.watch(programsProvider.future);
  final ids = programs
      .expand((p) => p.stages)
      .expand((s) => s.levels)
      .expand((l) => l.lessons)
      .map((l) => l.lessonId)
      .toSet();
  final records = await Future.wait(ids.map(
      (id) async => MapEntry(id, await repository.loadLessonProgress(id))));
  return Map<String, LessonProgress?>.fromEntries(records);
});

/// Content-driven RTL curriculum; an empty stage is visible but never launches
/// a fabricated lesson. Adding a stage/lesson requires no new navigation code.
class LessonsCatalog extends ConsumerStatefulWidget {
  const LessonsCatalog({super.key, required this.onLesson});
  final void Function(String) onLesson;
  @override
  ConsumerState<LessonsCatalog> createState() => _LessonsCatalogState();
}

class _LessonsCatalogState extends ConsumerState<LessonsCatalog> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final programs = ref.watch(programsProvider);
    return programs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: TextButton(
              onPressed: () => ref.invalidate(programsProvider),
              child: const Text('إعادة تحميل الدروس'))),
      data: (items) {
        final stages = items.expand((p) => p.stages).toList();
        final selected = stages.where((s) => s.id == _selected).firstOrNull;
        final progress = ref.watch(allLessonProgressProvider);
        return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            selected?.title ?? 'رحلة القراءة… خطوة بعد خطوة',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF594574)))),
                    if (selected != null)
                      TextButton.icon(
                          onPressed: () => setState(() => _selected = null),
                          icon: const Icon(Icons.east_rounded),
                          label: const Text('كل المراحل')),
                  ])),
              Expanded(
                  child: selected == null
                      ? LayoutBuilder(
                          builder: (context, size) => ListView.separated(
                                key: const ValueKey('curriculum-stages'),
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.fromLTRB(24, 12, 24, 22),
                                itemCount: stages.length,
                                separatorBuilder: (_, __) => const SizedBox(
                                    width: 28,
                                    child: Icon(Icons.west_rounded,
                                        color: Color(0xFF9684B0), size: 22)),
                                itemBuilder: (_, i) => SizedBox(
                                    width: size.maxWidth < 700 ? 170 : 198,
                                    child: _StageCard(
                                        stage: stages[i],
                                        index: i,
                                        onTap: stages[i]
                                                .levels
                                                .expand((l) => l.lessons)
                                                .isEmpty
                                            ? null
                                            : () => setState(() =>
                                                _selected = stages[i].id))),
                              ))
                      : progress.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, __) => Center(
                              child: TextButton(
                                  onPressed: () =>
                                      ref.invalidate(allLessonProgressProvider),
                                  child: const Text('إعادة تحميل التقدم'))),
                          data: (records) => _LettersRow(
                              stage: selected,
                              progress: records,
                              onLesson: widget.onLesson))),
            ]));
      },
    );
  }
}

const _colors = [
  Color(0xFF7B62A3),
  Color(0xFF448B9C),
  Color(0xFF508774),
  Color(0xFF7A78AD)
];
const _marks = ['بَ', 'بِ', 'بُ', 'بْ', 'بَا', 'بّ', 'بً'];

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.index, this.onTap});
  final Stage stage;
  final int index;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return Semantics(
        button: true,
        enabled: onTap != null,
        label: stage.title,
        child: FeedbackTap(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFFCFAFF),
                  borderRadius: BorderRadius.circular(28),
                  border:
                      Border.all(color: color.withValues(alpha: .35), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: .12),
                        offset: const Offset(0, 5),
                        blurRadius: 10)
                  ]),
              child: LayoutBuilder(
                  builder: (context, size) => Column(children: [
                        Row(children: [
                          Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                              child: Text('${index + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))),
                          const Spacer(),
                          Icon(
                              onTap == null
                                  ? Icons.lock_outline_rounded
                                  : Icons.auto_stories_rounded,
                              color: color,
                              size: 20)
                        ]),
                        const SizedBox(height: 6),
                        Expanded(
                            child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(20)),
                                child: LetterGlyph(
                                    index < _marks.length
                                        ? _marks[index]
                                        : 'أَ',
                                    color: color))),
                        const SizedBox(height: 8),
                        Text(stage.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                                fontSize: size.maxHeight < 230 ? 16 : 19,
                                height: 1.35,
                                color: const Color(0xFF594574),
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(
                            onTap == null
                                ? 'قريبًا'
                                : '${stage.levels.expand((l) => l.lessons).length} حروف جاهزة',
                            style: TextStyle(color: color, fontSize: 13)),
                      ])),
            )));
  }
}

class _LettersRow extends StatelessWidget {
  const _LettersRow(
      {required this.stage, required this.progress, required this.onLesson});
  final Stage stage;
  final Map<String, LessonProgress?> progress;
  final void Function(String) onLesson;
  @override
  Widget build(BuildContext context) {
    final lessons = stage.levels.expand((l) => l.lessons).toList();
    return LayoutBuilder(
        builder: (context, size) => ListView.separated(
              key: const ValueKey('fatha-lessons'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (_, i) {
                final lesson = lessons[i];
                final saved = progress[lesson.lessonId];
                final done = saved?.completed == true;
                return SizedBox(
                    width: ((size.maxWidth - 84) / 3).clamp(150.0, 230.0),
                    child: FeedbackTap(
                        key: ValueKey('lesson-card-${lesson.lessonId}'),
                        onTap: () => onLesson(lesson.lessonId),
                        child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFCFAFF),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                    color: const Color(0xFFDAD0EA), width: 2)),
                            child: Column(children: [
                              Expanded(
                                  child: Stack(children: [
                                Positioned.fill(
                                    child: Container(
                                        decoration: BoxDecoration(
                                            color: _colors[i % _colors.length]
                                                .withValues(alpha: .09),
                                            borderRadius:
                                                BorderRadius.circular(24)),
                                        child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: LetterGlyph(
                                                lesson.letter ?? 'أَ')))),
                                if (done)
                                  PositionedDirectional(
                                      top: 5,
                                      end: 5,
                                      child: CompletionBadge(
                                          key: ValueKey(
                                              'lesson-complete-${lesson.lessonId}'))),
                              ])),
                              const SizedBox(height: 8),
                              Text(lesson.title,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF594574))),
                              Text(
                                  done
                                      ? 'أكملته • ألعبه من جديد'
                                      : saved == null
                                          ? 'هيا نتعلم'
                                          : 'أكمل من حيث توقفت',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF594574))),
                            ]))));
              },
            ));
  }
}

class CompletionBadge extends StatelessWidget {
  const CompletionBadge({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'درس مكتمل',
      child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
              color: const Color(0xFF3D9673),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
          child:
              const Icon(Icons.check_rounded, color: Colors.white, size: 13)));
}
