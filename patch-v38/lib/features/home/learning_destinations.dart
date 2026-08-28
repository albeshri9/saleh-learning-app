import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/design/widgets/toy_icon.dart';
import '../../core/design/widgets/touch_feedback.dart';
import '../../domain/models/progress.dart';
import 'learning_journal.dart';
import 'profile_editor.dart';

class LetterJourney extends StatelessWidget {
  const LetterJourney({super.key, required this.onAlif, this.progress});
  final VoidCallback onAlif;
  final LessonProgress? progress;
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('تأسيس اللغة العربية • الحروف مع الفتحة',
            style: TextStyle(
                fontSize: 17, color: profileInk, fontWeight: FontWeight.bold)),
        Expanded(child: LayoutBuilder(builder: (context, b) {
          final nodeWidth = (b.maxWidth / 5).clamp(88.0, 150.0);
          final nodeHeight = b.maxHeight < 250 ? 126.0 : 156.0;
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _JourneyPath())),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: b.maxWidth * (.86 - .24 * i) - nodeWidth / 2,
                top: b.maxHeight * (i.isEven ? .57 : .41) - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight,
                child: Semantics(
                    button: i == 0,
                    label: i == 0 ? 'درس الألف' : 'درس قادم',
                    child: FeedbackTap(
                        key: ValueKey('letter-node-$i'),
                        onTap: i == 0 ? onAlif : null,
                        child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: i == 0
                                    ? const Color(0xFFF6F3FB)
                                    : const Color(0xEBF5F4F7),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                    color: i == 0
                                        ? const Color(0xFF8D72B7)
                                        : Colors.white,
                                    width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x227960AD),
                                      offset: Offset(0, 6),
                                      blurRadius: 10)
                                ]),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ToyIcon(
                                      i == 0 && progress?.completed == true
                                          ? Toy.trophy
                                          : Toy.flower,
                                      size: nodeHeight < 140 ? 38 : 52),
                                  Text(['أَ', 'بَ', 'تَ', 'ثَ'][i],
                                      style: const TextStyle(
                                          fontSize: 32,
                                          height: 1.2,
                                          color: profileInk,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      i == 0
                                          ? progress?.completed == true
                                              ? 'أعد الرحلة'
                                              : progress == null
                                                  ? 'ابدأ هنا'
                                                  : 'نكمل معًا'
                                          : 'قريبًا',
                                      style: const TextStyle(
                                          fontSize: 14, color: profileInk)),
                                ])))),
              ),
          ]);
        })),
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('رحلتنا تبدأ بالألف… وتكبر مع الحروف القادمة',
                style: TextStyle(fontSize: 16, color: profileInk))),
      ]);
}

class _JourneyPath extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = List.generate(
        4,
        (i) => Offset(size.width * (.86 - .24 * i),
            size.height * (i.isEven ? .57 : .41)));
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
          ..strokeWidth = 36
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFAFA0C6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_JourneyPath old) => false;
}

class AchievementsView extends ConsumerWidget {
  const AchievementsView(
      {super.key, required this.progress, required this.onPortfolio});
  final LessonProgress? progress;
  final VoidCallback onPortfolio;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(journalDataProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(journalDataProvider),
                  child: const Text('إعادة تحميل الإنجازات'))),
          data: (journal) {
            final badges = [
              (
                'مستكشف الألف',
                Toy.book,
                progress?.completedScenes.contains('explain_1') == true
              ),
              (
                'قلمي الجميل',
                Toy.pencil,
                progress?.completedScenes.contains('write_guided_1') == true
              ),
              (
                'بطل الألعاب',
                Toy.puzzle,
                journal.awards.keys.any((k) => k.startsWith('game:'))
              ),
              ('أكملت الدرس', Toy.trophy, progress?.completed == true),
            ];
            return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: _stat(
                            Toy.coins, '${journal.points}', 'رصيد النقاط')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _stat(
                            Toy.trophy,
                            '${badges.where((b) => b.$3).length} من 4',
                            'الإنجازات')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _stat(Toy.album, '${journal.drawings.length}',
                            'محاولات الكتابة')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (final badge in badges)
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: badge.$3
                                          ? const Color(0xFFE0F1EB)
                                          : const Color(0xF5F8F6FD),
                                      borderRadius: BorderRadius.circular(22)),
                                  child: Column(children: [
                                    ToyIcon(badge.$2, size: 52),
                                    const SizedBox(height: 4),
                                    Text(badge.$1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            color: profileInk,
                                            fontWeight: FontWeight.bold)),
                                    Text(badge.$3 ? 'أنجزتها ✓' : 'بانتظارك',
                                        style: const TextStyle(
                                            fontSize: 14, color: profileInk))
                                  ]))))
                  ]),
                  const SizedBox(height: 14),
                  JourneyButton(label: 'دفتر أعمالي', onTap: onPortfolio),
                  const SizedBox(height: 6),
                  const Text(
                      '10 نقاط للنشاط • 15 للعبة • 20 لإكمال الدرس، مرة واحدة لكل إنجاز',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: profileInk)),
                ]));
          });
  Widget _stat(Toy toy, String value, String label) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFAF8F6FD),
          borderRadius: BorderRadius.circular(22)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ToyIcon(toy, size: 46),
        const SizedBox(width: 8),
        Flexible(
            child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: profileInk)),
          Text(label, style: const TextStyle(fontSize: 14, color: profileInk))
        ]))
      ]));
}

class PortfolioView extends ConsumerWidget {
  const PortfolioView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(journalDataProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(journalDataProvider),
                  child: const Text('إعادة تحميل الدفتر'))),
          data: (journal) => journal.drawings.isEmpty
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ToyIcon(Toy.album, size: 100),
                  Text('دفترك ينتظر أول كتابة!',
                      style: TextStyle(fontSize: 24, color: profileInk)),
                  Text('تُحفظ محاولاتك عند الضغط على «انتهيت»',
                      style: TextStyle(color: profileInk))
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 350,
                      mainAxisExtent: 240,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12),
                  itemCount: journal.drawings.length,
                  itemBuilder: (context, index) {
                    final entry = journal.drawings.reversed.toList()[index];
                    final date = DateTime.parse(entry['at'] as String);
                    return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22)),
                        child: Column(children: [
                          Text(
                              '${date.year}/${date.month}/${date.day} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: profileInk)),
                          Expanded(child: Center(child: SavedDrawing(entry))),
                          Text(
                              entry['passed'] == true
                                  ? 'كتابة مكتملة'
                                  : 'محاولة أتعلّم منها',
                              style: const TextStyle(color: profileInk))
                        ]));
                  }));
}
