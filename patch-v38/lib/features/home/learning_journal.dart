import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/providers.dart';
import '../lesson/writing/handwriting_validator.dart';

class JournalData {
  const JournalData({this.awards = const {}, this.drawings = const []});
  final Map<String, int> awards;
  final List<Map<String, dynamic>> drawings;
  int get points => awards.values.fold(0, (a, b) => a + b);
  factory JournalData.fromJson(Map<String, dynamic> json) => JournalData(
        awards: (json['awards'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
        drawings: (json['drawings'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
  Map<String, dynamic> toJson() => {'awards': awards, 'drawings': drawings};
}

/// Serialized writes per profile avoid losing an award when a drawing is saved.
class LearningJournal {
  LearningJournal(this.childId);
  final String childId;
  String get key => 'journal_v38_$childId';
  static final Map<String, Future<void>> _writes = {};
  Future<JournalData> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null
        ? const JournalData()
        : JournalData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _update(JournalData Function(JournalData) change) {
    final job = (_writes[key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final next = change(await load());
      if (!await prefs.setString(key, jsonEncode(next.toJson()))) {
        throw StateError('Journal save failed');
      }
    });
    _writes[key] = job;
    return job.whenComplete(() {
      if (identical(_writes[key], job)) _writes.remove(key);
    });
  }

  Future<void> award(String id, int points) => _update((old) => JournalData(
      awards: {...old.awards, id: old.awards[id] ?? points},
      drawings: old.drawings));
  Future<void> saveDrawing(String lessonId, WritingSample sample,
      {required bool passed}) {
    if (sample.canvasSize.isEmpty || sample.strokes.isEmpty) {
      return Future.value();
    }
    // Snapshot now; the live canvas is mutable and can be cleared before IO ends.
    final entry = <String, dynamic>{
      'lessonId': lessonId,
      'at': DateTime.now().toIso8601String(),
      'passed': passed,
      'aspect': sample.canvasSize.width / sample.canvasSize.height,
      'strokes': sample.strokes
          .map((line) => line
              .map((p) => [
                    p.dx / sample.canvasSize.width,
                    p.dy / sample.canvasSize.height
                  ])
              .toList())
          .toList()
    };
    return _update((old) =>
        JournalData(awards: old.awards, drawings: [...old.drawings, entry]));
  }
}

final journalProvider =
    Provider((ref) => LearningJournal(ref.watch(activeChildIdProvider)));
final journalDataProvider = FutureProvider.autoDispose((ref) async {
  final journal = ref.watch(journalProvider);
  final repository = ref.watch(progressRepositoryProvider);
  final saved = await repository.loadLessonProgress('alif');
  final current = await journal.load();
  // Credit activities completed before v38 without rewarding repeated attempts.
  final earned = <String, int>{
    for (final id in saved?.completedScenes ?? <String>[])
      if (!id.startsWith('welcome') &&
          !id.startsWith('nasheed') &&
          !id.startsWith('success'))
        'lesson:alif:$id': 10,
    if (saved?.completed == true) 'lesson:alif:complete': 20,
  };
  for (final award in earned.entries) {
    if (!current.awards.containsKey(award.key)) {
      await journal.award(award.key, award.value);
    }
  }
  return journal.load();
});

class SavedDrawing extends StatelessWidget {
  const SavedDrawing(this.entry, {super.key});
  final Map<String, dynamic> entry;
  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: (entry['aspect'] as num).toDouble(),
      child: CustomPaint(
          painter: _SavedInk(entry), child: const SizedBox.expand()));
}

class _SavedInk extends CustomPainter {
  _SavedInk(this.entry);
  final Map<String, dynamic> entry;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7960AD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final raw in entry['strokes'] as List) {
      final points = raw as List;
      if (points.isEmpty) continue;
      Offset point(dynamic p) =>
          Offset((p[0] as num) * size.width, (p[1] as num) * size.height);
      final first = point(points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final p in points.skip(1)) {
        final xy = point(p);
        path.lineTo(xy.dx, xy.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SavedInk old) => old.entry != entry;
}
