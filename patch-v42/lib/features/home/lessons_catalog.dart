import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../domain/models/curriculum.dart';
import '../../domain/models/progress.dart';
import '../../core/design/widgets/letter_glyph.dart';
import '../../core/design/widgets/toy_icon.dart';
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
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xF5FCFAFF),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                selected?.title ??
                                    'رحلة القراءة… خطوة بعد خطوة',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF594574)))),
                        if (selected != null)
                          TextButton.icon(
                              onPressed: () => setState(() => _selected = null),
                              icon: const Icon(Icons.east_rounded),
                              label: const Text('كل المراحل')),
                      ]))),
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
                                    width: size.maxWidth < 700 ? 146 : 158,
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
const _stageToys = [
  Toy.book,
  Toy.cards,
  Toy.album,
  Toy.headphones,
  Toy.pencil,
  Toy.puzzle,
  Toy.trophy,
];

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.index, this.onTap});
  final Stage stage;
  final int index;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 184),
            child: Semantics(
                button: true,
                enabled: onTap != null,
                label: stage.title,
                child: FeedbackTap(
                    key: ValueKey('stage-card-${stage.id}'),
                    onTap: onTap,
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFCFAFF),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                                color: color.withValues(alpha: .30), width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: color.withValues(alpha: .12),
                                  offset: const Offset(0, 5),
                                  blurRadius: 10)
                            ]),
                        child: Column(children: [
                          Row(children: [
                            Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: .12),
                                    shape: BoxShape.circle),
                                child: Text(
                                    '${index + 1}'
                                        .split('')
                                        .map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)])
                                        .join(),
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold))),
                            const Spacer(),
                            if (onTap == null)
                              Icon(Icons.lock_outline_rounded,
                                  color: color, size: 15),
                          ]),
                          Expanded(
                              child: Center(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: ToyIcon(
                                          _stageToys[index % _stageToys.length],
                                          key:
                                              ValueKey('stage-art-${stage.id}'),
                                          size: 62)))),
                          Text(stage.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.3,
                                  color: Color(0xFF594574),
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Text(onTap == null ? 'قريبًا' : 'نبدأ رحلتنا',
                              style: TextStyle(color: color, fontSize: 12)),
                        ]))))));
  }
}

/// The compact flower nodes and gentle path restore the pre-v41 letter garden.
/// Letter artwork stays bounded independently of the available screen height.
class _LettersRow extends StatelessWidget {
  const _LettersRow(
      {required this.stage, required this.progress, required this.onLesson});
  final Stage stage;
  final Map<String, LessonProgress?> progress;
  final void Function(String) onLesson;
  @override
  Widget build(BuildContext context) {
    final lessons = stage.levels.expand((l) => l.lessons).toList();
    return LayoutBuilder(builder: (context, size) {
      final nodeWidth = (size.maxWidth / 4.4).clamp(100.0, 136.0);
      final canvasWidth = lessons.length * (nodeWidth + 24) + 16;
      final canvasHeight = math.min(size.maxHeight, 190.0);
      final nodeHeight = math.min(154.0, canvasHeight - 24);
      return Center(
          child: SizedBox(
              width: math.min(size.maxWidth, canvasWidth),
              height: canvasHeight,
              child: SingleChildScrollView(
                  key: const ValueKey('fatha-lessons'),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Stack(children: [
                        Positioned.fill(
                            child: CustomPaint(
                                painter: _LetterPathPainter(lessons.length))),
                        for (var i = 0; i < lessons.length; i++)
                          Positioned(
                              left: canvasWidth -
                                  (i + .5) * canvasWidth / lessons.length -
                                  nodeWidth / 2,
                              top: canvasHeight / 2 -
                                  nodeHeight / 2 +
                                  (i.isEven ? 5 : -5),
                              width: nodeWidth,
                              height: nodeHeight,
                              child: _LetterNode(
                                  lesson: lessons[i],
                                  saved: progress[lessons[i].lessonId],
                                  onTap: () => onLesson(lessons[i].lessonId))),
                      ])))));
    });
  }
}

class _LetterNode extends StatelessWidget {
  const _LetterNode(
      {required this.lesson, required this.saved, required this.onTap});
  final LessonRef lesson;
  final LessonProgress? saved;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final done = saved?.completed == true;
    return Semantics(
        button: true,
        label: lesson.title,
        child: FeedbackTap(
            key: ValueKey('lesson-card-${lesson.lessonId}'),
            onTap: onTap,
            child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF6F3FB),
                    borderRadius: BorderRadius.circular(26),
                    border:
                        Border.all(color: const Color(0xFFB49DCF), width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x227960AD),
                          offset: Offset(0, 5),
                          blurRadius: 9)
                    ]),
                child: Stack(children: [
                  Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ToyIcon(Toy.flower, size: 32),
                        Expanded(
                            child: Center(
                                child: SizedBox(
                                    width: 62,
                                    height: 45,
                                    child: LetterGlyph(lesson.letter ?? 'أَ',
                                        color: const Color(0xFF594574))))),
                        Text(lesson.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF594574))),
                        Text(
                            done
                                ? 'مكتمل • أعده'
                                : saved == null
                                    ? 'هيا نتعلم'
                                    : 'نكمل معًا',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF594574))),
                      ]),
                  if (done)
                    PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: CompletionBadge(
                            key: ValueKey(
                                'lesson-complete-${lesson.lessonId}'))),
                ]))));
  }
}

class _LetterPathPainter extends CustomPainter {
  const _LetterPathPainter(this.count);
  final int count;
  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;
    final points = List.generate(
        count,
        (i) => Offset(size.width - (i + .5) * size.width / count,
            size.height / 2 + (i.isEven ? 5 : -5)));
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i], mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xDDFFFCF5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFB6A4CF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_LetterPathPainter old) => old.count != count;
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
